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
    @NSManaged public var iconName: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var org: Org?
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

    var displayIconName: String {
        return iconName.isEmpty ? LocationIconCatalog.suggestedIcon(for: name) : iconName
    }

    static func create(
        in context: NSManagedObjectContext,
        org: Org,
        name: String,
        isDefault: Bool = false,
        iconName: String? = nil
    ) -> StorageLocation {
        let location = StorageLocation(context: context)
        location.idString = UUID().uuidString
        location.name = name
        location.iconName = iconName ?? LocationIconCatalog.suggestedIcon(for: name)
        location.isDefault = isDefault
        location.createdAt = Date()
        location.org = org
        return location
    }
}

enum LocationIconCatalog {
    static let categories = [
        SymbolCategory(name: "Buildings & Rooms", icons: [
            "house", "house.fill", "building.2", "building.2.fill",
            "building.columns", "building.columns.fill", "storefront",
            "storefront.fill", "graduationcap", "graduationcap.fill",
            "studentdesk", "cross", "cross.fill", "cross.circle",
            "cross.circle.fill",
            "door.left.hand.open", "door.right.hand.open", "bed.double",
            "bed.double.fill", "sofa", "sofa.fill", "chair", "chair.fill",
        ]),
        SymbolCategory(name: "Shelves & Storage", icons: [
            "books.vertical", "books.vertical.fill", "books.vertical.circle",
            "books.vertical.circle.fill",
            "archivebox", "archivebox.fill", "tray", "tray.fill",
            "tray.full", "tray.full.fill", "cabinet", "cabinet.fill",
            "shippingbox", "shippingbox.fill", "externaldrive",
            "externaldrive.fill", "folder", "folder.fill",
        ]),
        SymbolCategory(name: "Places & Navigation", icons: [
            "mappin", "mappin.circle", "mappin.circle.fill",
            "location", "location.fill", "map", "map.fill",
            "globe.americas", "signpost.right", "signpost.right.fill",
            "arrow.up.and.down.and.arrow.left.and.right", "safari",
            "safari.fill", "car", "car.fill", "tram", "tram.fill",
        ]),
        SymbolCategory(name: "Organization", icons: [
            "square.grid.2x2", "square.grid.2x2.fill", "rectangle.grid.2x2",
            "rectangle.grid.2x2.fill", "square.stack", "square.stack.fill",
            "rectangle.stack", "rectangle.stack.fill", "tag", "tag.fill",
            "bookmark", "bookmark.fill", "number", "list.bullet",
            "checklist", "ellipsis.circle", "ellipsis.circle.fill",
        ]),
    ]

    static func suggestedIcon(for name: String) -> String {
        let normalized = name.lowercased()
        if normalized.contains("home") { return "house.fill" }
        if normalized.contains("office") { return "building.2.fill" }
        if normalized.contains("school") || normalized.contains("university") {
            return "graduationcap.fill"
        }
        if normalized.contains("church") || normalized.contains("chapel") {
            return "cross.circle.fill"
        }
        if normalized.contains("bed") { return "bed.double.fill" }
        if normalized.contains("shelf") || normalized.contains("bookcase") {
            return "books.vertical.fill"
        }
        if normalized.contains("storage") || normalized.contains("box") {
            return "archivebox.fill"
        }
        return "books.vertical.fill"
    }
}
