//
//  StorageLocation.swift
//  Stacked
//

import CoreData
import Foundation

@objc(StorageLocation)
public class StorageLocation: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var household: Household?
    @NSManaged public var books: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StorageLocation> {
        NSFetchRequest<StorageLocation>(entityName: "StorageLocation")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    var bookCount: Int {
        (books as? Set<Book> ?? []).reduce(0) { $0 + Int($1.copies) }
    }

    var titleCount: Int {
        (books as? Set<Book> ?? []).count
    }

    static func create(in context: NSManagedObjectContext, household: Household, name: String, isDefault: Bool = false) -> StorageLocation {
        let location = StorageLocation(context: context)
        location.idString = UUID().uuidString
        location.name = name
        location.isDefault = isDefault
        location.createdAt = Date()
        location.household = household
        return location
    }
}
