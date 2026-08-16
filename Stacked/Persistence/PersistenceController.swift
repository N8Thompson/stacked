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

    private var expectedStoreCount = 1
    private var loadedStoreCount = 0
    private let inMemory: Bool

    var viewContext: NSManagedObjectContext { container.viewContext }

    var usesCloudKit: Bool {
        !inMemory && mode == .iCloud
    }

    init(inMemory: Bool = false, mode: PersistenceMode = PersistenceMode.current) {
        self.inMemory = inMemory
        self.mode = inMemory ? .local : mode
        self.container = NSPersistentCloudKitContainer(name: "Stacked")
        configureAndLoadStores()
    }

    func reload(mode: PersistenceMode) {
        save()
        self.mode = inMemory ? .local : mode
        PersistenceMode.current = self.mode
        privateStore = nil
        sharedStore = nil
        storesAreLoaded = false
        loadedStoreCount = 0
        container = NSPersistentCloudKitContainer(name: "Stacked")
        configureAndLoadStores()
        NotificationCenter.default.post(name: .stackedPersistenceDidReload, object: nil)
    }

    private func configureAndLoadStores() {
        guard let privateDescription = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description.")
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

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Core Data store failed: \(error)")
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if description.url == Self.sharedStoreURL {
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
        try? viewContext.save()
    }

    func waitUntilStoresAreLoaded() async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while !storesAreLoaded {
            if clock.now >= deadline { return }
            await Task.yield()
        }
    }

    /// Waits for CloudKit to import an existing library before local first-run seeding.
    func waitForInitialCloudKitImport(maxWait: Duration = .seconds(12)) async {
        guard usesCloudKit else { return }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: maxWait)

        while clock.now < deadline {
            let count = (try? viewContext.count(for: Org.fetchRequest())) ?? 0
            if count > 0 { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    static var cloudPrivateStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedPrivate.sqlite")
    }

    static var localStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedLocal.sqlite")
    }

    static var sharedStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedShared.sqlite")
    }
}

extension Notification.Name {
    static let stackedPersistenceDidReload = Notification.Name("stackedPersistenceDidReload")
}
