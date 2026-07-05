//
//  ItemBinding.swift
//  Stacked
//
//  A user-facing physical edition option (e.g. Paperback, Hardcover).
//

import Foundation
import SwiftData

@Model
final class ItemBinding {
    var name: String = ""
    var isDefault: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Book.bindingOption)
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
