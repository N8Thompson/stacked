//
//  CloudKitSharingAppDelegate.swift
//  Stacked
//

import CloudKit
#if os(iOS)
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
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        print("CloudKit push registration succeeded on iOS.")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("CloudKit push registration failed on iOS: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await OrgSharingService.shared.acceptShare(metadata: cloudKitShareMetadata)
            OrgManager.shared.refresh(in: PersistenceController.shared.viewContext)
        }
    }
}
#elseif os(macOS)
import AppKit

final class CloudKitSharingAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        print("CloudKit push registration succeeded on macOS.")
        #endif
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("CloudKit push registration failed on macOS: \(error.localizedDescription)")
    }

    func application(_ application: NSApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            await OrgSharingService.shared.acceptShare(metadata: metadata)
            OrgManager.shared.refresh(in: PersistenceController.shared.viewContext)
        }
    }
}
#endif
