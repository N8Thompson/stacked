//
//  OrgManager.swift
//  Stacked
//
//  Tracks the active org and scopes fetches to it.
//

import CoreData
import Foundation

@MainActor
@Observable
final class OrgManager {
    static let shared = OrgManager()

    private(set) var activeOrg: Org?
    /// Bumped when Core Data saves or remote sync merges so SwiftUI re-reads library data.
    private(set) var libraryRevision = 0

    private var observers: [NSObjectProtocol] = []

    private init() {}

    func restartObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        startObservingIfNeeded()
    }

    func startObservingIfNeeded() {
        guard observers.isEmpty else { return }

        let context = PersistenceController.shared.viewContext
        let coordinator = PersistenceController.shared.container.persistentStoreCoordinator
        let container = PersistenceController.shared.container
        let center = NotificationCenter.default

        let didSave = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self, Self.shouldRefreshUI(for: notification, viewing: context) else { return }
                bumpLibraryRevision()
            }
        }

        let remoteChange = center.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coordinator,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bumpLibraryRevision()
            }
        }

        let cloudKitEvent = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bumpLibraryRevision()
            }
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
        activeOrg = nil
        let request = Org.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Org.createdAt, ascending: false)]
        let orgs = (try? context.fetch(request)) ?? []

        if PersistenceController.shared.usesCloudKit,
           let sharedStore = PersistenceController.shared.sharedStore {
            activeOrg = orgs.first { org in
                persistentStore(for: org, in: context) == sharedStore
            }
        }

        activeOrg = activeOrg ?? preferredOrg(from: orgs, in: context)
    }

    private func preferredOrg(from orgs: [Org], in context: NSManagedObjectContext) -> Org? {
        orgs.max { lhs, rhs in
            bookCount(for: lhs, in: context) < bookCount(for: rhs, in: context)
        }
    }

    private func bookCount(for org: Org, in context: NSManagedObjectContext) -> Int {
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "collection.org == %@", org)
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

    func store(for org: Org, in context: NSManagedObjectContext) -> NSPersistentStore? {
        persistentStore(for: org, in: context)
    }

    func isSharedOrg(_ org: Org, in context: NSManagedObjectContext) -> Bool {
        guard PersistenceController.shared.usesCloudKit,
              let sharedStore = PersistenceController.shared.sharedStore else { return false }
        return store(for: org, in: context) == sharedStore
    }

    func privateLibraryCollection(in context: NSManagedObjectContext) -> BookCollection? {
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
    }

    func privateBookCount(in context: NSManagedObjectContext) -> Int {
        guard let collection = privateLibraryCollection(in: context) else { return 0 }
        return ((collection.books as? Set<Book>) ?? []).reduce(0) { $0 + Int($1.copies) }
    }

    func allBooks(in context: NSManagedObjectContext) -> [Book] {
        _ = libraryRevision
        guard let org = activeOrg else { return [] }
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "collection.org == %@", org)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Book.title, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func defaultCollection(in context: NSManagedObjectContext) -> BookCollection? {
        guard let org = activeOrg else { return nil }
        let collections = (org.collections as? Set<BookCollection>) ?? []
        return collections.first { $0.isActive } ?? collections.first
    }

    var locations: [StorageLocation] {
        _ = libraryRevision
        guard let org = activeOrg,
              let context = org.managedObjectContext else { return [] }
        let request = StorageLocation.fetchRequest()
        request.predicate = NSPredicate(format: "org == %@", org)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StorageLocation.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    var formats: [ItemFormat] {
        _ = libraryRevision
        guard let org = activeOrg,
              let context = org.managedObjectContext else { return [] }
        let request = ItemFormat.fetchRequest()
        request.predicate = NSPredicate(format: "org == %@", org)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemFormat.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    var bindings: [ItemBinding] {
        _ = libraryRevision
        guard let org = activeOrg,
              let context = org.managedObjectContext else { return [] }
        let request = ItemBinding.fetchRequest()
        request.predicate = NSPredicate(format: "org == %@", org)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemBinding.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
}
