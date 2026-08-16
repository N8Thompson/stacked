//
//  OrgSharingService.swift
//  Stacked
//

import CloudKit
import CoreData
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum OrgRole: String {
    case owner
    case participant
    case localOnly
}

struct OrgMember: Identifiable, Hashable {
    let id: String
    let userRecordName: String?
    let displayName: String
    let subtitle: String
    let isOwner: Bool
    let isCurrentUser: Bool
    let isPending: Bool
    let joinedViaLink: Bool
}

@MainActor
@Observable
final class OrgSharingService {
    static let shared = OrgSharingService()

    private let persistence = PersistenceController.shared
    private var container: CKContainer {
        CKContainer(identifier: PersistenceController.cloudKitContainerID)
    }

    var pendingMergeAfterJoin = false
    var currentRole: OrgRole = .localOnly
    var lastSharingError: String?
    private var cloudSharingSession: OrgCloudSharingSession?

    func refreshRole(for org: Org?) async {
        let resolved: OrgRole
        guard persistence.usesCloudKit, let org else {
            resolved = persistence.usesCloudKit ? .owner : .localOnly
            assignRole(resolved)
            return
        }
        if OrgManager.shared.isSharedOrg(org, in: persistence.viewContext) {
            resolved = (await isOwner(of: org)) ? .owner : .participant
        } else {
            resolved = .owner
        }
        assignRole(resolved)
    }

    private func assignRole(_ role: OrgRole) {
        if currentRole != role {
            currentRole = role
        }
    }

    func fetchOrCreateShare(for org: Org) async throws -> CKShare {
        if let existing = await fetchShare(for: org) {
            return existing
        }
        return try await createShare(for: org)
    }

    func createShare(for org: Org) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            persistence.container.share([org], to: nil) { _, share, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let share else {
                    continuation.resume(throwing: BookSearchError.transport("Could not create share."))
                    return
                }
                share.publicPermission = .none
                continuation.resume(returning: share)
            }
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async {
        lastSharingError = nil
        guard let sharedStore = persistence.sharedStore else { return }
        do {
            try await persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore)
            OrgManager.shared.refresh(in: persistence.viewContext)
            pendingMergeAfterJoin = OrgManager.shared.privateBookCount(in: persistence.viewContext) > 0
            await refreshRole(for: OrgManager.shared.activeOrg)
        } catch {
            lastSharingError = error.localizedDescription
        }
    }

    func isOwner(of org: Org) async -> Bool {
        guard let share = await fetchShare(for: org) else { return true }
        let ownerID = share.owner.userIdentity.userRecordID?.recordName
        let current = CloudKitIdentityService.shared.recordName
        return ownerID == current || ownerID == nil
    }

    func presentUserManagement(for org: Org, isPlus: Bool) async throws -> Bool {
        let existingShare = await fetchShare(for: org)
        guard OrgSharePolicy.canCreateShare(
            isPlus: isPlus,
            hasExistingShare: existingShare != nil
        ) else {
            return false
        }

        let share: CKShare
        if let existingShare {
            share = existingShare
        } else {
            share = try await createShare(for: org)
        }
        let session = OrgCloudSharingSession { [weak self] in
            self?.cloudSharingSession = nil
        }
        cloudSharingSession = session
        session.present(
            share: share,
            container: CKContainer(identifier: PersistenceController.cloudKitContainerID)
        )
        return true
    }

    func leaveSharedOrg(_ org: Org) async throws {
        lastSharingError = nil
        guard let sharedStore = persistence.sharedStore else { return }
        guard OrgManager.shared.isSharedOrg(org, in: persistence.viewContext) else { return }
        guard let share = await fetchShare(for: org) else { return }
        do {
            try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore)
            OrgManager.shared.refresh(in: persistence.viewContext)
            await refreshRole(for: OrgManager.shared.activeOrg)
        } catch {
            lastSharingError = error.localizedDescription
            throw error
        }
    }

    func fetchShare(for org: Org) async -> CKShare? {
        let shares = try? persistence.container.fetchShares(matching: [org.objectID])
        return shares?[org.objectID]
    }

    func members(from share: CKShare) -> [OrgMember] {
        let current = CloudKitIdentityService.shared.recordName
        let currentParticipantID = share.currentUserParticipant.map(participantID)
        return share.participants
            .map { participant in
                member(
                    from: participant,
                    currentRecordName: current,
                    currentParticipantID: currentParticipantID
                )
            }
            .sorted { lhs, rhs in
                if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    func setLinkSharing(enabled: Bool, share: CKShare, org: Org) async throws -> CKShare {
        let updated = share
        if enabled {
            updated.publicPermission = .readWrite
        } else {
            let linkMembers = updated.participants.filter { $0.role == .publicUser }
            for participant in linkMembers {
                updated.removeParticipant(participant)
            }
            updated.publicPermission = .none
        }
        return try await persist(updated, org: org)
    }

    func removeMember(_ member: OrgMember, from share: CKShare, org: Org) async throws -> CKShare {
        guard let participant = share.participants.first(where: {
            participantID($0) == member.id
        }) else { return share }
        guard participant.role != .owner else { return share }
        share.removeParticipant(participant)
        return try await persist(share, org: org)
    }

    private func persist(_ share: CKShare, org: Org) async throws -> CKShare {
        let store = OrgManager.shared.store(for: org, in: persistence.viewContext)
            ?? persistence.privateStore
        guard let store else {
            throw BookSearchError.transport("Couldn't update collection access.")
        }
        return try await persistence.container.persistUpdatedShare(share, in: store)
    }

    private func member(
        from participant: CKShare.Participant,
        currentRecordName: String?,
        currentParticipantID: String?
    ) -> OrgMember {
        let recordName = participant.userIdentity.userRecordID?.recordName
        let joinedViaLink = participant.role == .publicUser
        let isOwner = participant.role == .owner
        let isPending = participant.acceptanceStatus == .pending
        let id = participantID(participant)
        let isCurrentUser = id == currentParticipantID
            || (recordName != nil && recordName == currentRecordName)
            || (isOwner && currentRole == .owner)
        let identityName = CloudKitIdentityService.shared.displayName
        let resolvedName = formattedName(from: participant)
        let name = isCurrentUser && identityName != "You" ? identityName : resolvedName
        let subtitle: String
        if isOwner {
            subtitle = "Owner"
        } else if isPending {
            subtitle = joinedViaLink ? "Link invite · Pending" : "Invited · Pending"
        } else {
            subtitle = joinedViaLink ? "Joined via share link" : "Invited directly"
        }
        return OrgMember(
            id: id,
            userRecordName: recordName,
            displayName: name == "Owner" && isCurrentUser ? "You" : name,
            subtitle: subtitle,
            isOwner: isOwner,
            isCurrentUser: isCurrentUser,
            isPending: isPending,
            joinedViaLink: joinedViaLink
        )
    }

    private func formattedName(from participant: CKShare.Participant) -> String {
        if let components = participant.userIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !formatted.isEmpty { return formatted }
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        if let phone = participant.userIdentity.lookupInfo?.phoneNumber, !phone.isEmpty {
            return phone
        }
        return participant.role == .owner ? "Owner" : "Participant"
    }

    private func participantID(_ participant: CKShare.Participant) -> String {
        participant.userIdentity.userRecordID?.recordName
            ?? participant.userIdentity.lookupInfo?.emailAddress
            ?? participant.userIdentity.lookupInfo?.phoneNumber
            ?? UUID().uuidString
    }
}

#if os(iOS)
@MainActor
final class OrgCloudSharingSession: NSObject, UICloudSharingControllerDelegate {
    private let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func present(share: CKShare, container: CKContainer) {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = self
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.view.tintColor = UIColor(StackedTheme.Brand.sage)
        topViewController()?.present(controller, animated: true)
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        OrgSharingService.shared.lastSharingError = error.localizedDescription
        onFinished()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        onFinished()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        onFinished()
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Stacked collection"
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }

        if let navigation = controller as? UINavigationController {
            return navigation.visibleViewController ?? navigation
        }
        if let tabs = controller as? UITabBarController {
            return tabs.selectedViewController ?? tabs
        }
        return controller
    }
}
#elseif os(macOS)
@MainActor
final class OrgCloudSharingSession: NSObject {
    private let onFinished: () -> Void
    private var picker: NSSharingServicePicker?

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func present(share: CKShare, container: CKContainer) {
        let itemProvider = NSItemProvider()
        itemProvider.registerCKShare(
            share,
            container: container,
            allowedSharingOptions: .standard
        )

        guard let view = NSApp.keyWindow?.contentView else {
            onFinished()
            return
        }
        let picker = NSSharingServicePicker(items: [itemProvider])
        self.picker = picker
        let rect = NSRect(
            x: view.bounds.midX - 1,
            y: view.bounds.midY - 1,
            width: 2,
            height: 2
        )
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}
#endif
