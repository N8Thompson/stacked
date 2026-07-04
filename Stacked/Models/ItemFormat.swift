//
//  ItemFormat.swift
//  Stacked
//
//  A user-facing "Format" describing the kind of item (e.g. Book, Journal, Magazine).
//

import Foundation
import SwiftData

@Model
final class ItemFormat {
    var name: String = ""
    var isDefault: Bool = false
    var createdAt: Date = Date()

    // Inverse of Book.format. Optional for CloudKit compatibility.
    @Relationship(deleteRule: .nullify, inverse: \Book.format)
    var books: [Book]? = nil

    init(name: String, isDefault: Bool = false, createdAt: Date = Date()) {
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    var bookCount: Int {
        (books ?? []).reduce(0) { $0 + $1.copies }
    }
}
