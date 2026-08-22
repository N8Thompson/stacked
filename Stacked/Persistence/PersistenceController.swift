//
//  PersistenceController.swift
//  Stacked
//
//  Reloadable Core Data stack. iOS and Mac can run in iCloud or local-only mode
//  using separate SQLite files so CloudKit is never toggled on the same store.
//

import CoreData
import CloudKit

@MainActor
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    static let cloudKitContainerID = "iCloud.com.thompson.Stacked"

    private(set) var container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private(set) var storesAreLoaded = false
    private(set) var mode: PersistenceMode
    private(set) var loadError: String?

    private var expectedStoreCount = 1
    private var loadedStoreCount = 0
    private let inMemory: Bool
    private var initialCloudImportCompleted = false
    private var cloudEventObserver: NSObjectProtocol?

    var viewContext: NSManagedObjectContext { container.viewContext }

    var usesCloudKit: Bool {
        !inMemory && mode == .iCloud
    }

    init(inMemory: Bool = false, mode: PersistenceMode = PersistenceMode.current) {
        self.inMemory = inMemory
        self.mode = inMemory ? .local : mode
        self.container = NSPersistentCloudKitContainer(name: "Stacked")
        if !inMemory {
            Self.removeObsoletePrelaunchStores()
        }
        configureAndLoadStores()
    }

    func reload(mode: PersistenceMode) {
        save()
        self.mode = inMemory ? .local : mode
        PersistenceMode.current = self.mode
        privateStore = nil
        sharedStore = nil
        storesAreLoaded = false
        loadError = nil
        loadedStoreCount = 0
        initialCloudImportCompleted = false
        if let cloudEventObserver {
            NotificationCenter.default.removeObserver(cloudEventObserver)
            self.cloudEventObserver = nil
        }
        container = NSPersistentCloudKitContainer(name: "Stacked")
        configureAndLoadStores()
        NotificationCenter.default.post(name: .stackedPersistenceDidReload, object: nil)
    }

    private func configureAndLoadStores() {
        guard let privateDescription = container.persistentStoreDescriptions.first else {
            loadError = "Stacked couldn't configure its local database."
            storesAreLoaded = true
            return
        }

        if inMemory {
            expectedStoreCount = 1
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
            privateDescription.cloudKitContainerOptions = nil
        } else if mode == .iCloud {
            expectedStoreCount = 2
            privateDescription.url = Self.cloudPrivateStoreURL
            privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )

            let sharedDescription = privateDescription.copy() as! NSPersistentStoreDescription
            sharedDescription.url = Self.sharedStoreURL
            sharedDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )
            sharedDescription.cloudKitContainerOptions?.databaseScope = .shared
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions.append(sharedDescription)
        } else {
            expectedStoreCount = 1
            privateDescription.url = Self.localStoreURL
            privateDescription.cloudKitContainerOptions = nil
        }

        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if mode == .iCloud, !inMemory {
            observeInitialCloudKitEvents()
        }

        container.loadPersistentStores { description, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    loadError = "Stacked couldn't open its database: \(error.localizedDescription)"
                } else if description.url == Self.sharedStoreURL {
                    sharedStore = container.persistentStoreCoordinator.persistentStores
                        .first { $0.url == Self.sharedStoreURL }
                } else {
                    privateStore = container.persistentStoreCoordinator.persistentStores
                        .first { $0.url == description.url }
                }
                loadedStoreCount += 1
                if loadedStoreCount >= expectedStoreCount {
                    storesAreLoaded = true
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
    }

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            loadError = "Stacked couldn't save your changes: \(error.localizedDescription)"
        }
    }

    func waitUntilStoresAreLoaded() async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while !storesAreLoaded {
            if clock.now >= deadline {
                loadError = "Stacked timed out while opening its database."
                return
            }
            await Task.yield()
        }
    }

    /// Waits for CloudKit to import an existing library before local first-run seeding.
    func waitForInitialCloudKitImport(maxWait: Duration = .seconds(30)) async {
        guard usesCloudKit else { return }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: maxWait)

        while clock.now < deadline {
            if loadError != nil || initialCloudImportCompleted { return }
            let count = (try? viewContext.count(for: Org.fetchRequest())) ?? 0
            if count > 0 { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func observeInitialCloudKitEvents() {
        cloudEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil else { return }
            Task { @MainActor in
                guard let self else { return }
                #if DEBUG
                let eventName: String
                switch event.type {
                case .setup: eventName = "setup"
                case .import: eventName = "import"
                case .export: eventName = "export"
                @unknown default: eventName = "unknown"
                }
                print(
                    "CloudKit \(eventName) \(event.succeeded ? "succeeded" : "failed"): "
                        + (event.error?.localizedDescription ?? "no error")
                )
                #endif
                if !event.succeeded, (event.type == .setup || event.type == .import) {
                    self.loadError = "iCloud sync couldn't start: \(event.error?.localizedDescription ?? "Unknown iCloud error.")"
                }
                if event.type == .import {
                    self.initialCloudImportCompleted = true
                }
            }
        }
    }

    static var cloudPrivateStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedPrivateV2.sqlite")
    }

    static var localStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedLocalV2.sqlite")
    }

    static var sharedStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedSharedV2.sqlite")
    }

    private static func removeObsoletePrelaunchStores() {
        let directory = NSPersistentContainer.defaultDirectoryURL()
        let baseNames = ["Stacked.sqlite", "StackedPrivate.sqlite", "StackedShared.sqlite", "StackedLocal.sqlite"]
        for baseName in baseNames {
            let storeURL = directory.appendingPathComponent(baseName)
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
        }
    }
}

extension Notification.Name {
    static let stackedPersistenceDidReload = Notification.Name("stackedPersistenceDidReload")
}
