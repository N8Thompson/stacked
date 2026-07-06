//
//  Book.swift
//  Stacked
//

import CoreData
import Foundation
import SwiftUI

@objc(Book)
public class Book: NSManagedObject, Identifiable {
    @NSManaged public var idString: String
    @NSManaged public var isbn: String
    @NSManaged public var title: String
    @NSManaged public var authors: String
    @NSManaged public var publisher: String
    @NSManaged public var publishedYear: NSNumber?
    @NSManaged public var binding: String
    @NSManaged public var synopsis: String
    @NSManaged public var rating: Double
    @NSManaged public var reviewNotes: String
    @NSManaged public var coverURL: String
    @NSManaged public var coverOverride: Data?
    @NSManaged public var listPrice: Double
    @NSManaged public var actualCost: NSNumber?
    @NSManaged public var copies: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var isManualEntry: Bool
    @NSManaged public var addedAt: Date?
    @NSManaged public var addedByCloudRecordName: String
    @NSManaged public var addedByDisplayName: String
    @NSManaged public var collection: BookCollection?
    @NSManaged public var location: StorageLocation?
    @NSManaged public var format: ItemFormat?
    @NSManaged public var bindingOption: ItemBinding?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Book> {
        NSFetchRequest<Book>(entityName: "Book")
    }

    public var id: UUID {
        UUID(uuidString: idString) ?? UUID()
    }

    var publishedYearValue: Int? {
        get { publishedYear?.intValue }
        set { publishedYear = newValue.map { NSNumber(value: $0) } }
    }

    var actualCostValue: Double? {
        get { actualCost?.doubleValue }
        set { actualCost = newValue.map { NSNumber(value: $0) } }
    }

    var effectiveUnitPrice: Double {
        actualCostValue ?? listPrice
    }

    var totalListValue: Double {
        listPrice * Double(copies)
    }

    var totalValue: Double {
        effectiveUnitPrice * Double(copies)
    }
}

extension Book {
    @MainActor
    static func create(
        in context: NSManagedObjectContext,
        collection: BookCollection,
        isbn: String,
        title: String,
        authors: String = "",
        publisher: String = "",
        publishedYear: Int? = nil,
        synopsis: String = "",
        coverURL: String = "",
        listPrice: Double = 0,
        actualCost: Double? = nil,
        copies: Int = 1,
        isManualEntry: Bool = false,
        location: StorageLocation? = nil,
        format: ItemFormat? = nil,
        bindingOption: ItemBinding? = nil
    ) -> Book {
        let book = Book(context: context)
        book.idString = UUID().uuidString
        book.isbn = isbn
        book.title = title
        book.authors = authors
        book.publisher = publisher
        book.publishedYearValue = publishedYear
        book.synopsis = synopsis
        book.coverURL = coverURL
        book.listPrice = listPrice
        book.actualCostValue = actualCost
        book.copies = Int32(copies)
        book.createdAt = Date()
        book.isManualEntry = isManualEntry
        book.collection = collection
        book.location = location
        book.format = format
        book.bindingOption = bindingOption
        CloudKitIdentityService.shared.applyProvenance(to: book)
        return book
    }
}

extension Array where Element == Book {
    var totalEstimatedValue: Double {
        reduce(0) { $0 + $1.totalListValue }
    }

    var totalCost: Double {
        reduce(0) { $0 + $1.totalValue }
    }

    var hasAnyActualCost: Bool {
        contains { $0.actualCostValue != nil }
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

extension Book {
    func stringBinding(_ keyPath: ReferenceWritableKeyPath<Book, String>) -> Binding<String> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    var copiesBinding: Binding<Int> {
        Binding(
            get: { Int(self.copies) },
            set: { self.copies = Int32($0) }
        )
    }

    var ratingBinding: Binding<Double> {
        Binding(
            get: { self.rating },
            set: { self.rating = $0 }
        )
    }
}
