//
//  HouseholdSharingService.swift
//  Stacked
//

import CloudKit
import CoreData
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum HouseholdRole: String {
    case owner
    case participant
    case localOnly
}

struct HouseholdMember: Identifiable, Hashable {
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
final class HouseholdSharingService {
    static let shared = HouseholdSharingService()

    private let persistence = PersistenceController.shared
    private var container: CKContainer {
        CKContainer(identifier: PersistenceController.cloudKitContainerID)
    }

    var pendingMergeAfterJoin = false
    var currentRole: HouseholdRole = .localOnly
    var lastSharingError: String?
    #if os(iOS)
    private var cloudSharingSession: HouseholdCloudSharingSession?
    #endif

    func refreshRole(for household: Household?) async {
        #if os(iOS)
        let resolved: HouseholdRole
        guard persistence.usesCloudKit, let household else {
            resolved = persistence.usesCloudKit ? .owner : .localOnly
            assignRole(resolved)
            return
        }
        if HouseholdManager.shared.isSharedHousehold(household, in: persistence.viewContext) {
            resolved = (await isOwner(of: household)) ? .owner : .participant
        } else {
            resolved = .owner
        }
        assignRole(resolved)
        #else
        assignRole(.localOnly)
        #endif
    }

    private func assignRole(_ role: HouseholdRole) {
        if currentRole != role {
            currentRole = role
        }
    }

    func fetchOrCreateShare(for household: Household) async throws -> CKShare {
        if let existing = await fetchShare(for: household) {
            return existing
        }
        return try await createShare(for: household)
    }

    func createShare(for household: Household) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            persistence.container.share([household], to: nil) { _, share, _, error in
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
            HouseholdManager.shared.refresh(in: persistence.viewContext)
            pendingMergeAfterJoin = HouseholdManager.shared.privateBookCount(in: persistence.viewContext) > 0
            await refreshRole(for: HouseholdManager.shared.activeHousehold)
        } catch {
            lastSharingError = error.localizedDescription
        }
    }

    func isOwner(of household: Household) async -> Bool {
        guard let share = await fetchShare(for: household) else { return true }
        let ownerID = share.owner.userIdentity.userRecordID?.recordName
        let current = CloudKitIdentityService.shared.recordName
        return ownerID == current || ownerID == nil
    }

    #if os(iOS)
    func presentUserManagement(for household: Household, isPlus: Bool) async throws -> Bool {
        let existingShare = await fetchShare(for: household)
        guard HouseholdSharePolicy.canCreateShare(
            isPlus: isPlus,
            hasExistingShare: existingShare != nil
        ) else {
            return false
        }

        let share: CKShare
        if let existingShare {
            share = existingShare
        } else {
            share = try await createShare(for: household)
        }
        let session = HouseholdCloudSharingSession { [weak self] in
            self?.cloudSharingSession = nil
        }
        cloudSharingSession = session
        session.present(
            share: share,
            container: CKContainer(identifier: PersistenceController.cloudKitContainerID)
        )
        return true
    }

    func leaveSharedHousehold(_ household: Household) async throws {
        lastSharingError = nil
        guard let sharedStore = persistence.sharedStore else { return }
        guard HouseholdManager.shared.isSharedHousehold(household, in: persistence.viewContext) else { return }
        guard let share = await fetchShare(for: household) else { return }
        do {
            try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore)
            HouseholdManager.shared.refresh(in: persistence.viewContext)
            await refreshRole(for: HouseholdManager.shared.activeHousehold)
        } catch {
            lastSharingError = error.localizedDescription
            throw error
        }
    }
    #endif

    func fetchShare(for household: Household) async -> CKShare? {
        let shares = try? persistence.container.fetchShares(matching: [household.objectID])
        return shares?[household.objectID]
    }

    func members(from share: CKShare) -> [HouseholdMember] {
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

    #if os(iOS)
    func setLinkSharing(enabled: Bool, share: CKShare, household: Household) async throws -> CKShare {
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
        return try await persist(updated, household: household)
    }

    func removeMember(_ member: HouseholdMember, from share: CKShare, household: Household) async throws -> CKShare {
        guard let participant = share.participants.first(where: {
            participantID($0) == member.id
        }) else { return share }
        guard participant.role != .owner else { return share }
        share.removeParticipant(participant)
        return try await persist(share, household: household)
    }

    private func persist(_ share: CKShare, household: Household) async throws -> CKShare {
        let store = HouseholdManager.shared.store(for: household, in: persistence.viewContext)
            ?? persistence.privateStore
        guard let store else {
            throw BookSearchError.transport("Couldn't update collection access.")
        }
        return try await persistence.container.persistUpdatedShare(share, in: store)
    }
    #endif

    private func member(
        from participant: CKShare.Participant,
        currentRecordName: String?,
        currentParticipantID: String?
    ) -> HouseholdMember {
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
        return HouseholdMember(
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
final class HouseholdCloudSharingSession: NSObject, UICloudSharingControllerDelegate {
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
        HouseholdSharingService.shared.lastSharingError = error.localizedDescription
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
#endif
