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
        await publishOwnerEntitlementIfNeeded(for: org)
    }

    private func assignRole(_ role: OrgRole) {
        if currentRole != role {
            currentRole = role
        }
    }

    func createShare(for org: Org) async throws -> CKShare {
        await publishOwnerEntitlementIfNeeded(for: org)
        return try await withCheckedThrowingContinuation { continuation in
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
        guard let sharedStore = persistence.sharedStore else {
            lastSharingError = "Connect this device to iCloud before accepting a shared collection."
            return
        }
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
        guard persistence.usesCloudKit else {
            throw BookSearchError.transport("Reconnect this library to iCloud before managing users.")
        }
        guard CloudKitIdentityService.shared.isSignedIn else {
            throw BookSearchError.transport("Sign in to iCloud before managing users.")
        }
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
        guard let sharedStore = persistence.sharedStore else {
            throw BookSearchError.transport("The shared iCloud store is not available.")
        }
        guard OrgManager.shared.isSharedOrg(org, in: persistence.viewContext) else {
            throw BookSearchError.transport("This collection is not a shared collection.")
        }
        guard let share = await fetchShare(for: org) else {
            throw BookSearchError.transport("Couldn't find this collection's sharing record.")
        }
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

    func publishOwnerEntitlementIfNeeded() async {
        await publishOwnerEntitlementIfNeeded(for: OrgManager.shared.activeOrg)
    }

    func publishOwnerEntitlementIfNeeded(for org: Org?) async {
        guard currentRole == .owner, let org else { return }
        let subscriptions = SubscriptionService.shared
        let permanent = subscriptions.hasComplimentaryPlus
        let expiration = subscriptions.hasStoreSubscription ? subscriptions.storeExpirationDate : nil
        guard org.ownerHasPermanentPlus != permanent
                || org.ownerPlusExpirationDate != expiration else { return }
        org.ownerHasPermanentPlus = permanent
        org.ownerPlusExpirationDate = expiration
        persistence.save()

        guard let share = await fetchShare(for: org) else { return }
        let ownerAccessActive = permanent || (expiration.map { $0 > Date() } ?? false)
        let permission: CKShare.ParticipantPermission = ownerAccessActive ? .readWrite : .readOnly
        var changed = false
        for participant in share.participants where participant.role != .owner {
            if participant.permission != permission {
                participant.permission = permission
                changed = true
            }
        }
        guard changed else { return }
        let store = OrgManager.shared.store(for: org, in: persistence.viewContext)
            ?? persistence.privateStore
        guard let store else { return }
        do {
            _ = try await persistence.container.persistUpdatedShare(share, in: store)
        } catch {
            lastSharingError = error.localizedDescription
        }
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
final class OrgCloudSharingSession: NSObject, @preconcurrency NSCloudSharingServiceDelegate {
    private let onFinished: () -> Void
    private var service: NSSharingService?
    private var itemProvider: NSItemProvider?

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
        guard let service = NSSharingService(named: .cloudSharing) else {
            OrgSharingService.shared.lastSharingError = "Cloud sharing is not available on this Mac."
            onFinished()
            return
        }
        service.delegate = self
        self.itemProvider = itemProvider
        self.service = service
        service.perform(withItems: [itemProvider])
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didCompleteForItems items: [Any],
        error: (any Error)?
    ) {
        if let error {
            OrgSharingService.shared.lastSharingError = error.localizedDescription
        }
        service = nil
        itemProvider = nil
        onFinished()
    }

    func options(
        for sharingService: NSSharingService,
        share provider: NSItemProvider
    ) -> NSSharingService.CloudKitOptions {
        [.allowPrivate, .allowReadWrite]
    }
}
#endif
