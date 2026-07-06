//
//  HouseholdManager.swift
//  Stacked
//
//  Tracks the active household and scopes fetches to it.
//

import CoreData
import Foundation

@MainActor
@Observable
final class HouseholdManager {
    static let shared = HouseholdManager()

    private(set) var activeHousehold: Household?
    /// Bumped when Core Data saves or remote sync merges so SwiftUI re-reads library data.
    private(set) var libraryRevision = 0

    private var observers: [NSObjectProtocol] = []

    private init() {}

    func startObservingIfNeeded() {
        guard observers.isEmpty else { return }

        let context = PersistenceController.shared.viewContext
        let center = NotificationCenter.default

        let didSave = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, Self.shouldRefreshUI(for: notification, viewing: context) else { return }
            bumpLibraryRevision()
        }

        let remoteChange = center.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: PersistenceController.shared.container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLibraryRevision()
        }

        let cloudKitEvent = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: PersistenceController.shared.container,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLibraryRevision()
        }

        observers = [didSave, remoteChange, cloudKitEvent]
    }

    func bumpLibraryRevision() {
        libraryRevision &+= 1
    }

    private static func shouldRefreshUI(for notification: Notification, viewing context: NSManagedObjectContext) -> Bool {
        guard let savedContext = notification.object as? NSManagedObjectContext else { return false }
        return savedContext.persistentStoreCoordinator === context.persistentStoreCoordinator
    }

    func refresh(in context: NSManagedObjectContext) {
        let request = Household.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Household.createdAt, ascending: false)]
        let households = (try? context.fetch(request)) ?? []

        #if os(iOS)
        if let sharedStore = PersistenceController.shared.sharedStore {
            activeHousehold = households.first { household in
                persistentStore(for: household, in: context) == sharedStore
            }
        }
        #endif

        activeHousehold = activeHousehold ?? preferredHousehold(from: households, in: context)
    }

    private func preferredHousehold(from households: [Household], in context: NSManagedObjectContext) -> Household? {
        households.max { lhs, rhs in
            bookCount(for: lhs, in: context) < bookCount(for: rhs, in: context)
        }
    }

    private func bookCount(for household: Household, in context: NSManagedObjectContext) -> Int {
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "collection.household == %@", household)
        return (try? context.count(for: request)) ?? 0
    }

    func persistentStore(for object: NSManagedObject, in context: NSManagedObjectContext) -> NSPersistentStore? {
        guard let coordinator = context.persistentStoreCoordinator,
              let entityName = object.entity.name else { return nil }

        for store in coordinator.persistentStores {
            let request = NSFetchRequest<NSManagedObjectID>(entityName: entityName)
            request.predicate = NSPredicate(format: "SELF == %@", object.objectID)
            request.resultType = .managedObjectIDResultType
            request.fetchLimit = 1
            request.affectedStores = [store]
            if let ids = try? context.fetch(request), !ids.isEmpty {
                return store
            }
        }
        return nil
    }

    func store(for household: Household, in context: NSManagedObjectContext) -> NSPersistentStore? {
        persistentStore(for: household, in: context)
    }

    func isSharedHousehold(_ household: Household, in context: NSManagedObjectContext) -> Bool {
        #if os(iOS)
        guard let sharedStore = PersistenceController.shared.sharedStore else { return false }
        return store(for: household, in: context) == sharedStore
        #else
        return false
        #endif
    }

    func privateLibraryCollection(in context: NSManagedObjectContext) -> BookCollection? {
        #if os(iOS)
        guard let privateStore = PersistenceController.shared.privateStore else { return nil }

        let request = BookCollection.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookCollection.createdAt, ascending: true)]
        let collections = (try? context.fetch(request)) ?? []

        return collections.first { collection in
            guard persistentStore(for: collection, in: context) == privateStore else { return false }
            let books = (collection.books as? Set<Book>) ?? []
            return !books.isEmpty
        }
        #else
        return nil
        #endif
    }

    func privateBookCount(in context: NSManagedObjectContext) -> Int {
        guard let collection = privateLibraryCollection(in: context) else { return 0 }
        return ((collection.books as? Set<Book>) ?? []).reduce(0) { $0 + Int($1.copies) }
    }

    func allBooks(in context: NSManagedObjectContext) -> [Book] {
        _ = libraryRevision
        guard let household = activeHousehold else { return [] }
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "collection.household == %@", household)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Book.title, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func defaultCollection(in context: NSManagedObjectContext) -> BookCollection? {
        guard let household = activeHousehold else { return nil }
        let collections = (household.collections as? Set<BookCollection>) ?? []
        return collections.first { $0.isActive } ?? collections.first
    }

    var locations: [StorageLocation] {
        _ = libraryRevision
        guard let household = activeHousehold,
              let context = household.managedObjectContext else { return [] }
        let request = StorageLocation.fetchRequest()
        request.predicate = NSPredicate(format: "household == %@", household)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StorageLocation.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    var formats: [ItemFormat] {
        _ = libraryRevision
        guard let household = activeHousehold,
              let context = household.managedObjectContext else { return [] }
        let request = ItemFormat.fetchRequest()
        request.predicate = NSPredicate(format: "household == %@", household)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemFormat.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    var bindings: [ItemBinding] {
        _ = libraryRevision
        guard let household = activeHousehold,
              let context = household.managedObjectContext else { return [] }
        let request = ItemBinding.fetchRequest()
        request.predicate = NSPredicate(format: "household == %@", household)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemBinding.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
}
