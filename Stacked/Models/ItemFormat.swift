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
    @NSManaged public var iconName: String
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

    var displayIconName: String {
        if iconName == "tablet" { return "ipad" }
        return iconName.isEmpty ? FormatIconCatalog.suggestedIcon(for: name) : iconName
    }

    static func create(
        in context: NSManagedObjectContext,
        org: Org,
        name: String,
        isDefault: Bool = false,
        iconName: String? = nil
    ) -> ItemFormat {
        let format = ItemFormat(context: context)
        format.idString = UUID().uuidString
        format.name = name
        format.iconName = iconName ?? FormatIconCatalog.suggestedIcon(for: name)
        format.isDefault = isDefault
        format.createdAt = Date()
        format.org = org
        return format
    }
}

struct SymbolCategory: Identifiable {
    let name: String
    let icons: [String]

    var id: String { name }
}

enum FormatIconCatalog {
    static let categories = [
        SymbolCategory(name: "Books & Reading", icons: [
            "books.vertical", "books.vertical.fill", "book", "book.fill",
            "book.closed", "book.closed.fill", "text.book.closed",
            "text.book.closed.fill", "character.book.closed",
            "magazine", "magazine.fill", "newspaper", "newspaper.fill",
        ]),
        SymbolCategory(name: "Paper & Documents", icons: [
            "doc", "doc.fill", "doc.text", "doc.text.fill", "doc.richtext",
            "doc.plaintext", "doc.on.doc", "doc.on.doc.fill", "note.text",
            "note.text.badge.plus", "paperclip", "paperclip.circle",
            "paperclip.circle.fill", "bookmark", "bookmark.fill",
            "tag", "tag.fill", "link", "link.circle",
        ]),
        SymbolCategory(name: "Folders & Storage", icons: [
            "folder", "folder.fill", "folder.badge.plus",
            "archivebox", "archivebox.fill", "tray", "tray.fill",
            "tray.full", "tray.full.fill", "shippingbox", "shippingbox.fill",
            "square.stack", "square.stack.fill", "rectangle.stack",
            "rectangle.stack.fill", "square.stack.3d.up",
            "square.stack.3d.up.fill", "externaldrive", "externaldrive.fill",
        ]),
        SymbolCategory(name: "Digital & Audio", icons: [
            "ipad", "iphone", "laptopcomputer", "desktopcomputer",
            "headphones", "earbuds", "hifispeaker", "hifispeaker.fill",
            "waveform", "music.note", "film", "film.fill",
            "opticaldisc", "gamecontroller", "gamecontroller.fill",
        ]),
        SymbolCategory(name: "Study & Reference", icons: [
            "graduationcap", "graduationcap.fill", "backpack",
            "backpack.fill", "pencil", "pencil.circle", "highlighter",
            "ruler", "pencil.and.ruler", "globe", "building.columns",
            "building.columns.fill", "lightbulb", "lightbulb.fill",
            "quote.opening", "text.quote",
        ]),
    ]

    static func suggestedIcon(for name: String) -> String {
        let normalized = name.lowercased()
        if normalized.contains("audio") { return "headphones" }
        if normalized.contains("ebook") || normalized.contains("digital") { return "ipad" }
        if normalized.contains("journal") { return "book.closed.fill" }
        if normalized.contains("magazine") || normalized.contains("newspaper") { return "newspaper.fill" }
        if normalized.contains("comic") || normalized.contains("graphic") { return "text.book.closed.fill" }
        if normalized.contains("document") { return "doc.text.fill" }
        if normalized.contains("movie") || normalized.contains("film") { return "film.fill" }
        if normalized.contains("music") { return "music.note" }
        if normalized.contains("game") { return "gamecontroller.fill" }
        if normalized.contains("book") { return "books.vertical.fill" }
        return "square.stack.3d.up.fill"
    }
}
