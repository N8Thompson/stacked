//
//  BookCollection.swift
//  Stacked
//

import CoreData
import Foundation

@objc(BookCollection)
public class BookCollection: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var ownerDisplayName: String
    @NSManaged public var ownerCloudRecordName: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var org: Org?
    @NSManaged public var books: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BookCollection> {
        NSFetchRequest<BookCollection>(entityName: "BookCollection")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    static func create(
        in context: NSManagedObjectContext,
        org: Org,
        name: String,
        ownerDisplayName: String,
        ownerCloudRecordName: String
    ) -> BookCollection {
        let collection = BookCollection(context: context)
        collection.idString = UUID().uuidString
        collection.name = name
        collection.org = org
        collection.ownerDisplayName = ownerDisplayName
        collection.ownerCloudRecordName = ownerCloudRecordName
        collection.createdAt = Date()
        collection.isActive = true
        return collection
    }
}
