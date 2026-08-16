//
//  Org.swift
//  Stacked
//

import CoreData
import Foundation

@objc(Org)
public class Org: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var showCostTracking: Bool
    @NSManaged public var collections: NSSet?
    @NSManaged public var locations: NSSet?
    @NSManaged public var formats: NSSet?
    @NSManaged public var bindings: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Org> {
        NSFetchRequest<Org>(entityName: "Org")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    static func create(in context: NSManagedObjectContext, name: String = "Home") -> Org {
        let org = Org(context: context)
        org.idString = UUID().uuidString
        org.name = name
        org.createdAt = Date()
        org.showCostTracking = true
        return org
    }
}
