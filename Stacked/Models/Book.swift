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
    /// Legacy free-text binding; migrated to bindingOption on launch and cleared.
    var binding: String = ""
    var synopsis: String = ""
    /// Personal rating from 0 (unset) to 5 in half-star steps.
    var rating: Double = 0
    /// Personal notes about this item.
    var reviewNotes: String = ""

    /// Remote cover image URL from the search provider.
    var coverURL: String = ""
    /// User-supplied cover image data that overrides the remote cover when set.
    @Attribute(.externalStorage) var coverOverride: Data? = nil

    /// Publisher list price / MSRP. Defaults to 0 when unknown.
    var listPrice: Double = 0
    /// Price the user actually paid. Takes precedence over listPrice when set.
    var actualCost: Double? = nil

    var copies: Int = 1
    var createdAt: Date = Date()
    /// Manual entries allow editing ISBN; catalog items from search do not.
    var isManualEntry: Bool = false

    @Relationship(deleteRule: .nullify) var location: StorageLocation? = nil
    @Relationship(deleteRule: .nullify) var format: ItemFormat? = nil
    @Relationship(deleteRule: .nullify) var bindingOption: ItemBinding? = nil

    init(
        isbn: String,
        title: String,
        authors: String = "",
        publisher: String = "",
        publishedYear: Int? = nil,
        binding: String = "",
        synopsis: String = "",
        rating: Double = 0,
        reviewNotes: String = "",
        coverURL: String = "",
        coverOverride: Data? = nil,
        listPrice: Double = 0,
        actualCost: Double? = nil,
        copies: Int = 1,
        createdAt: Date = Date(),
        isManualEntry: Bool = false,
        location: StorageLocation? = nil,
        format: ItemFormat? = nil,
        bindingOption: ItemBinding? = nil
    ) {
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publishedYear = publishedYear
        self.binding = binding
        self.synopsis = synopsis
        self.rating = rating
        self.reviewNotes = reviewNotes
        self.coverURL = coverURL
        self.coverOverride = coverOverride
        self.listPrice = listPrice
        self.actualCost = actualCost
        self.copies = copies
        self.createdAt = createdAt
        self.isManualEntry = isManualEntry
        self.location = location
        self.format = format
        self.bindingOption = bindingOption
    }

    /// The per-copy value used for cost reporting: actualCost when provided,
    /// otherwise the list price, otherwise zero.
    var effectiveUnitPrice: Double {
        actualCost ?? listPrice
    }

    /// Total value at list price for all copies.
    var totalListValue: Double {
        listPrice * Double(copies)
    }

    /// Total value of all copies of this item (actual cost when set, otherwise list price).
    var totalValue: Double {
        effectiveUnitPrice * Double(copies)
    }
}

extension Collection where Element == Book {
    var totalEstimatedValue: Double {
        reduce(0) { $0 + $1.totalListValue }
    }

    var totalCost: Double {
        reduce(0) { $0 + $1.totalValue }
    }

    var hasAnyActualCost: Bool {
        contains { $0.actualCost != nil }
    }
}

enum BookFormValidation {
    static func isValid(title: String, authors: String, location: StorageLocation?, format: ItemFormat?) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !authors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && location != nil
            && format != nil
    }
}
