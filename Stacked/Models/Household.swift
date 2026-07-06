//
//  Household.swift
//  Stacked
//

import CoreData
import Foundation

@objc(Household)
public class Household: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var showCostTracking: Bool
    @NSManaged public var collections: NSSet?
    @NSManaged public var locations: NSSet?
    @NSManaged public var formats: NSSet?
    @NSManaged public var bindings: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Household> {
        NSFetchRequest<Household>(entityName: "Household")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    static func create(in context: NSManagedObjectContext, name: String = "Home") -> Household {
        let household = Household(context: context)
        household.idString = UUID().uuidString
        household.name = name
        household.createdAt = Date()
        household.showCostTracking = true
        return household
    }
}
