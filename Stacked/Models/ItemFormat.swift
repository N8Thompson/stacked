//
//  ItemFormat.swift
//  Stacked
//

import CoreData
import Foundation

@objc(ItemFormat)
public class ItemFormat: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var org: Org?
    @NSManaged public var books: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItemFormat> {
        NSFetchRequest<ItemFormat>(entityName: "ItemFormat")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    var titleCount: Int {
        (books as? Set<Book> ?? []).count
    }

    static func create(in context: NSManagedObjectContext, org: Org, name: String, isDefault: Bool = false) -> ItemFormat {
        let format = ItemFormat(context: context)
        format.idString = UUID().uuidString
        format.name = name
        format.isDefault = isDefault
        format.createdAt = Date()
        format.org = org
        return format
    }
}
