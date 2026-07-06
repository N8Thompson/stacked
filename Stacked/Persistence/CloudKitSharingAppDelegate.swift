//
//  CloudKitSharingAppDelegate.swift
//  Stacked
//

#if os(iOS)
import CloudKit
import UIKit

final class CloudKitSharingAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await HouseholdSharingService.shared.acceptShare(metadata: cloudKitShareMetadata)
            HouseholdManager.shared.refresh(in: PersistenceController.shared.viewContext)
        }
    }
}
#endif
