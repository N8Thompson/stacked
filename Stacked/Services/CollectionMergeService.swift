//
//  CollectionMergeService.swift
//  Stacked
//
//  Contributes a private library into a shared household on join.
//

import CoreData
import Foundation

enum CollectionMergeService {
    @MainActor
    static func mergePrivateIntoHousehold(
        source: BookCollection,
        targetHousehold: Household,
        in context: NSManagedObjectContext
    ) throws {
        let identity = CloudKitIdentityService.shared
        let targetCollection = BookCollection.create(
            in: context,
            household: targetHousehold,
            name: "\(identity.displayName)'s Library",
            ownerDisplayName: identity.displayName,
            ownerCloudRecordName: identity.recordName ?? ""
        )

        let sourceBooks = (source.books as? Set<Book>) ?? []
        for book in sourceBooks {
            if !book.isbn.isEmpty, let existing = findBook(isbn: book.isbn, household: targetHousehold, in: context) {
                existing.copies += book.copies
                continue
            }

            let copy = Book.create(
                in: context,
                collection: targetCollection,
                isbn: book.isbn,
                title: book.title,
                authors: book.authors,
                publisher: book.publisher,
                publishedYear: book.publishedYearValue,
                synopsis: book.synopsis,
                coverURL: book.coverURL,
                listPrice: book.listPrice,
                actualCost: book.actualCostValue,
                copies: Int(book.copies),
                isManualEntry: book.isManualEntry,
                location: book.location,
                format: book.format,
                bindingOption: book.bindingOption
            )
            copy.rating = book.rating
            copy.reviewNotes = book.reviewNotes
            copy.coverOverride = book.coverOverride
            copy.createdAt = book.createdAt
            copy.addedAt = book.addedAt
            copy.addedByCloudRecordName = book.addedByCloudRecordName
            copy.addedByDisplayName = book.addedByDisplayName
        }

        source.isActive = false
        try context.save()
    }

    @MainActor
    private static func findBook(isbn: String, household: Household, in context: NSManagedObjectContext) -> Book? {
        let collections = household.collections as? Set<BookCollection> ?? []
        let books = collections.flatMap { ($0.books as? Set<Book>) ?? [] }
        return books.first { $0.isbn == isbn }
    }
}
