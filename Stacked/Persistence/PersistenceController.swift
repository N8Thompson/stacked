//
//  PersistenceController.swift
//  Stacked
//
//  Core Data + CloudKit private and shared persistent stores.
//

import CoreData
import CloudKit

@MainActor
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    static let cloudKitContainerID = "iCloud.com.thompson.Stacked"

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private(set) var storesAreLoaded = false

    private let expectedStoreCount: Int
    private var loadedStoreCount = 0

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        #if os(iOS)
        expectedStoreCount = inMemory ? 1 : 2
        #else
        expectedStoreCount = 1
        #endif
        container = NSPersistentCloudKitContainer(name: "Stacked")

        guard let privateDescription = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description.")
        }

        if inMemory {
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
        } else {
            #if os(iOS)
            privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )

            let sharedDescription = privateDescription.copy() as! NSPersistentStoreDescription
            sharedDescription.url = Self.sharedStoreURL
            sharedDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )
            sharedDescription.cloudKitContainerOptions?.databaseScope = .shared
            container.persistentStoreDescriptions.append(sharedDescription)
            #endif
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
                        .first { $0.url != Self.sharedStoreURL }
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
        while !storesAreLoaded {
            await Task.yield()
        }
    }

    #if os(iOS)
    /// Waits for CloudKit to import an existing library before local first-run seeding.
    func waitForInitialCloudKitImport(maxWait: Duration = .seconds(12)) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: maxWait)

        while clock.now < deadline {
            let count = (try? viewContext.count(for: Household.fetchRequest())) ?? 0
            if count > 0 { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
    #endif

    static var privateStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedPrivate.sqlite")
    }

    static var sharedStoreURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("StackedShared.sqlite")
    }
}
