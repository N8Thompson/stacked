//
//  StorageLocation.swift
//  Stacked
//
//  A user-facing "Location" where items are stored (e.g. Home Library, Office).
//

import Foundation
import SwiftData

@Model
final class StorageLocation {
    var name: String = ""
    var isDefault: Bool = false
    var createdAt: Date = Date()

    // Inverse of Book.location. Optional for CloudKit compatibility.
    @Relationship(deleteRule: .nullify, inverse: \Book.location)
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
