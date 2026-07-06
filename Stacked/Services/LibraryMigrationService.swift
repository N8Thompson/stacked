//
//  LibraryMigrationService.swift
//  Stacked
//
//  Full-fidelity JSON export/import for moving libraries between Stacked users.
//

import CoreData
import Foundation
import UniformTypeIdentifiers

struct MigrationPreview {
    var uniqueTitles: Int
    var totalCopies: Int
    var locationCount: Int
    var payload: LibraryExportPayload
}

struct LibraryExportPayload: Codable {
    var stackedLibraryExport: LibraryExportRoot
}

struct LibraryExportRoot: Codable {
    var version: Int
    var exportedAt: Date
    var exportedByDisplayName: String
    var householdName: String
    var taxonomy: ExportTaxonomy
    var books: [ExportBook]
}

struct ExportTaxonomy: Codable {
    var locations: [String]
    var formats: [String]
    var bindings: [String]
}

struct ExportBook: Codable {
    var isbn: String
    var title: String
    var authors: String
    var publisher: String
    var publishedYear: Int?
    var synopsis: String
    var coverURL: String
    var coverOverrideBase64: String?
    var listPrice: Double
    var actualCost: Double?
    var copies: Int
    var rating: Double
    var reviewNotes: String
    var location: String
    var format: String
    var binding: String
    var isManualEntry: Bool
    var addedAt: Date
    var addedByDisplayName: String
    var createdAt: Date
}

enum LibraryMigrationService {
    static let exportType = UTType(filenameExtension: "stackedlibrary") ?? .json

    @MainActor
    static func exportHousehold(_ household: Household, context: NSManagedObjectContext) throws -> URL {
        let books = HouseholdManager.shared.allBooks(in: context)
        let payload = LibraryExportPayload(
            stackedLibraryExport: LibraryExportRoot(
                version: 1,
                exportedAt: Date(),
                exportedByDisplayName: CloudKitIdentityService.shared.displayName,
                householdName: household.name,
                taxonomy: ExportTaxonomy(
                    locations: HouseholdManager.shared.locations.map(\.name),
                    formats: HouseholdManager.shared.formats.map(\.name),
                    bindings: HouseholdManager.shared.bindings.map(\.name)
                ),
                books: books.map(exportBook)
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Stacked-Library-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).stackedlibrary")
        try data.write(to: url)
        return url
    }

    static func previewImport(from url: URL) throws -> MigrationPreview {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LibraryExportPayload.self, from: data)
        guard payload.stackedLibraryExport.version == 1 else {
            throw BookSearchError.transport("Unsupported export version.")
        }
        let books = payload.stackedLibraryExport.books
        let unique = Set(books.map { $0.isbn.isEmpty ? $0.title : $0.isbn }).count
        let copies = books.reduce(0) { $0 + $1.copies }
        let locations = Set(books.map(\.location).filter { !$0.isEmpty }).count
        return MigrationPreview(
            uniqueTitles: unique,
            totalCopies: copies,
            locationCount: locations,
            payload: payload
        )
    }

    @MainActor
    static func applyImport(_ preview: MigrationPreview, into household: Household, context: NSManagedObjectContext) throws {
        guard let collection = HouseholdManager.shared.defaultCollection(in: context) else {
            throw BookSearchError.transport("No collection to import into.")
        }
        let identity = CloudKitIdentityService.shared
        let importDate = Date()

        for name in preview.payload.stackedLibraryExport.taxonomy.locations {
            _ = TaxonomyService.findOrCreateLocation(name: name, household: household, in: context)
        }
        for name in preview.payload.stackedLibraryExport.taxonomy.formats {
            _ = TaxonomyService.findOrCreateFormat(name: name, household: household, in: context)
        }
        for name in preview.payload.stackedLibraryExport.taxonomy.bindings {
            _ = TaxonomyService.findOrCreateBinding(name: name, household: household, in: context)
        }

        for exported in preview.payload.stackedLibraryExport.books {
            if let isbn = exported.isbn.nilIfEmpty,
               let existing = findBook(isbn: isbn, in: context) {
                existing.copies += Int32(exported.copies)
                continue
            }

            let book = Book.create(
                in: context,
                collection: collection,
                isbn: exported.isbn,
                title: exported.title,
                authors: exported.authors,
                publisher: exported.publisher,
                publishedYear: exported.publishedYear,
                synopsis: exported.synopsis,
                coverURL: exported.coverURL,
                listPrice: exported.listPrice,
                actualCost: exported.actualCost,
                copies: exported.copies,
                isManualEntry: exported.isManualEntry
            )
            book.createdAt = exported.createdAt
            book.rating = exported.rating
            book.reviewNotes = exported.reviewNotes
            if let b64 = exported.coverOverrideBase64 {
                book.coverOverride = Data(base64Encoded: b64)
            }
            if !exported.location.isEmpty {
                book.location = TaxonomyService.findOrCreateLocation(name: exported.location, household: household, in: context)
            }
            if !exported.format.isEmpty {
                book.format = TaxonomyService.findOrCreateFormat(name: exported.format, household: household, in: context)
            }
            if !exported.binding.isEmpty {
                book.bindingOption = TaxonomyService.findOrCreateBinding(name: exported.binding, household: household, in: context)
            }
            book.addedAt = importDate
            book.addedByCloudRecordName = identity.recordName ?? ""
            book.addedByDisplayName = identity.displayName
        }

        try context.save()
    }

    private static func exportBook(_ book: Book) -> ExportBook {
        ExportBook(
            isbn: book.isbn,
            title: book.title,
            authors: book.authors,
            publisher: book.publisher,
            publishedYear: book.publishedYearValue,
            synopsis: book.synopsis,
            coverURL: book.coverURL,
            coverOverrideBase64: book.coverOverride?.base64EncodedString(),
            listPrice: book.listPrice,
            actualCost: book.actualCostValue,
            copies: Int(book.copies),
            rating: book.rating,
            reviewNotes: book.reviewNotes,
            location: book.location?.name ?? "",
            format: book.format?.name ?? "",
            binding: book.bindingOption?.name ?? "",
            isManualEntry: book.isManualEntry,
            addedAt: book.addedAt ?? book.createdAt ?? Date(),
            addedByDisplayName: book.addedByDisplayName,
            createdAt: book.createdAt ?? Date()
        )
    }

    private static func findBook(isbn: String, in context: NSManagedObjectContext) -> Book? {
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "isbn == %@", isbn)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
