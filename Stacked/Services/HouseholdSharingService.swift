//
//  HouseholdSharingService.swift
//  Stacked
//

import CloudKit
import CoreData
import SwiftUI

@MainActor
@Observable
final class HouseholdSharingService {
    static let shared = HouseholdSharingService()

    private let persistence = PersistenceController.shared
    private var container: CKContainer {
        CKContainer(identifier: PersistenceController.cloudKitContainerID)
    }

    var pendingMergeAfterJoin = false

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
        guard let sharedStore = persistence.sharedStore else { return }
        do {
            try await persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore)
            HouseholdManager.shared.refresh(in: persistence.viewContext)
            pendingMergeAfterJoin = HouseholdManager.shared.privateBookCount(in: persistence.viewContext) > 0
        } catch {
            // Surface in Settings via account status for now.
        }
    }

    func isOwner(of household: Household) async -> Bool {
        guard let share = await fetchShare(for: household) else { return true }
        let ownerID = share.owner.userIdentity.userRecordID?.recordName
        let current = CloudKitIdentityService.shared.recordName
        return ownerID == current || ownerID == nil
    }

    #if os(iOS)
    func leaveSharedHousehold(_ household: Household) async throws {
        guard let sharedStore = persistence.sharedStore else { return }
        guard HouseholdManager.shared.isSharedHousehold(household, in: persistence.viewContext) else { return }
        guard let share = await fetchShare(for: household) else { return }
        try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore)
        HouseholdManager.shared.refresh(in: persistence.viewContext)
    }
    #endif

    func fetchShare(for household: Household) async -> CKShare? {
        let shares = try? persistence.container.fetchShares(matching: [household.objectID])
        return shares?[household.objectID]
    }
}

#if os(iOS)
struct HouseholdCloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        UICloudSharingController(share: share, container: container)
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
#endif
