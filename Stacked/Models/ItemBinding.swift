//
//  ItemBinding.swift
//  Stacked
//

import CoreData
import Foundation

@objc(ItemBinding)
public class ItemBinding: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var household: Household?
    @NSManaged public var books: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItemBinding> {
        NSFetchRequest<ItemBinding>(entityName: "ItemBinding")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    var titleCount: Int {
        (books as? Set<Book> ?? []).count
    }

    static func create(in context: NSManagedObjectContext, household: Household, name: String, isDefault: Bool = false) -> ItemBinding {
        let binding = ItemBinding(context: context)
        binding.idString = UUID().uuidString
        binding.name = name
        binding.isDefault = isDefault
        binding.createdAt = Date()
        binding.household = household
        return binding
    }
}
