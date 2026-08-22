//
//  CollectionMergeService.swift
//  Stacked
//
//  Contributes a private library into a shared org on join.
//

import CoreData
import Foundation

enum CollectionMergeService {
    @MainActor
    static func mergePrivateIntoOrg(
        source: BookCollection,
        targetOrg: Org,
        in context: NSManagedObjectContext,
        hasPlusAccess: Bool,
        canContribute: Bool
    ) throws {
        guard canContribute else {
            throw BookSearchError.transport(
                "The collection owner's Stacked + access must be active before participants can add books."
            )
        }
        let targetCollections = (targetOrg.collections as? Set<BookCollection>) ?? []
        guard let targetCollection = targetCollections.first(where: \.isActive) ?? targetCollections.first else {
            throw BookSearchError.transport("The shared collection is not available.")
        }

        let sourceBooks = (source.books as? Set<Book>) ?? []
        var targetBooks = targetCollections.flatMap { ($0.books as? Set<Book>) ?? [] }
        var targetByKey = Dictionary(
            targetBooks.map { (bookIdentityKey($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        if !hasPlusAccess {
            let incomingKeys = Set(sourceBooks.map(bookIdentityKey))
            let existingKeys = Set(targetByKey.keys)
            let newTitleCount = incomingKeys.subtracting(existingKeys).count
            guard existingKeys.count + newTitleCount <= EntitlementPolicy.freeUniqueTitleLimit else {
                throw BookSearchError.transport(
                    "Adding this library would exceed the free limit of \(EntitlementPolicy.freeUniqueTitleLimit) unique titles."
                )
            }

            let existingLocations = Set(
                ((targetOrg.locations as? Set<StorageLocation>) ?? [])
                    .map { BookIdentity.normalizedText($0.name) }
            )
            let incomingLocations = Set(
                sourceBooks.compactMap(\.location?.name).map(BookIdentity.normalizedText)
            )
            let newLocationCount = incomingLocations.subtracting(existingLocations).count
            guard existingLocations.count + newLocationCount <= EntitlementPolicy.freeLocationLimit else {
                throw BookSearchError.transport(
                    "Adding this library would exceed the free limit of \(EntitlementPolicy.freeLocationLimit) locations."
                )
            }
        }

        for book in sourceBooks {
            let key = bookIdentityKey(book)
            if let existing = targetByKey[key] {
                existing.copies += book.copies
                continue
            }

            let targetLocation = book.location.flatMap {
                TaxonomyService.findOrCreateLocation(name: $0.name, org: targetOrg, in: context)
            }
            let targetFormat = book.format.flatMap {
                TaxonomyService.findOrCreateFormat(name: $0.name, org: targetOrg, in: context)
            }
            let targetBinding = book.bindingOption.flatMap {
                TaxonomyService.findOrCreateBinding(name: $0.name, org: targetOrg, in: context)
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
                location: targetLocation,
                format: targetFormat,
                bindingOption: targetBinding
            )
            copy.rating = book.rating
            copy.reviewNotes = book.reviewNotes
            copy.coverOverride = book.coverOverride
            copy.createdAt = book.createdAt
            copy.addedAt = book.addedAt
            copy.addedByCloudRecordName = book.addedByCloudRecordName
            copy.addedByDisplayName = book.addedByDisplayName
            targetBooks.append(copy)
            targetByKey[key] = copy
        }

        if let sourceOrg = source.org, sourceOrg != targetOrg {
            let sourceCollections = (sourceOrg.collections as? Set<BookCollection>) ?? []
            if sourceCollections.count <= 1 {
                context.delete(sourceOrg)
            } else {
                context.delete(source)
            }
        } else {
            context.delete(source)
        }
        try context.save()
    }

    private static func bookIdentityKey(_ book: Book) -> String {
        BookIdentity.key(
            isbn: book.isbn,
            title: book.title,
            authors: book.authors,
            publishedYear: book.publishedYearValue
        )
    }
}
