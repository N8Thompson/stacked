//
//  Book.swift
//  Stacked
//
//  A catalog item, deduplicated by ISBN. Carries a single Location, a single
//  Format, and a copies count. CloudKit requires defaults on every property
//  and optional relationships, so uniqueness is enforced in-app rather than
//  with @Attribute(.unique).
//

import Foundation
import SwiftData

@Model
final class Book {
    var isbn: String = ""
    var title: String = ""
    var authors: String = ""
    var publisher: String = ""
    var publishedYear: Int? = nil
    /// Physical edition from the catalog (e.g. Paperback, Hardcover).
    var binding: String = ""
    var synopsis: String = ""

    /// Remote cover image URL from the search provider.
    var coverURL: String = ""
    /// User-supplied cover image data that overrides the remote cover when set.
    @Attribute(.externalStorage) var coverOverride: Data? = nil

    /// Publisher list price / MSRP from the search provider.
    var listPrice: Double? = nil
    /// Price the user actually paid. Takes precedence over listPrice when set.
    var actualCost: Double? = nil

    var copies: Int = 1
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify) var location: StorageLocation? = nil
    @Relationship(deleteRule: .nullify) var format: ItemFormat? = nil

    init(
        isbn: String,
        title: String,
        authors: String = "",
        publisher: String = "",
        publishedYear: Int? = nil,
        binding: String = "",
        synopsis: String = "",
        coverURL: String = "",
        coverOverride: Data? = nil,
        listPrice: Double? = nil,
        actualCost: Double? = nil,
        copies: Int = 1,
        createdAt: Date = Date(),
        location: StorageLocation? = nil,
        format: ItemFormat? = nil
    ) {
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publishedYear = publishedYear
        self.binding = binding
        self.synopsis = synopsis
        self.coverURL = coverURL
        self.coverOverride = coverOverride
        self.listPrice = listPrice
        self.actualCost = actualCost
        self.copies = copies
        self.createdAt = createdAt
        self.location = location
        self.format = format
    }

    /// The per-copy value used for cost reporting: actualCost when provided,
    /// otherwise the list price, otherwise zero.
    var effectiveUnitPrice: Double {
        actualCost ?? listPrice ?? 0
    }

    /// Total value of all copies of this item.
    var totalValue: Double {
        effectiveUnitPrice * Double(copies)
    }
}
