//
//  LibraryMigrationService.swift
//  Stacked
//
//  Full-fidelity JSON backup/import plus portable CSV export.
//

import CoreData
import Foundation
import UniformTypeIdentifiers

struct MigrationPreview: Identifiable {
    let id = UUID()
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
    var orgName: String
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
    static let exportType = UTType.stackedLibrary
    static let portableCSVHeader = [
        "Title", "Authors", "ISBN", "Publisher", "Published Year", "Format",
        "Binding", "Location", "Copies", "List Price", "Actual Cost", "Rating", "Notes",
    ]

    @MainActor
    static func exportOrg(_ org: Org, context: NSManagedObjectContext) throws -> URL {
        let payload = try backupPayload(org, context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Stacked-Library-\(fileTimestamp()).stackedlibrary")
        try data.write(to: url)
        return url
    }

    @MainActor
    static func portableCSVURL(_ org: Org, context: NSManagedObjectContext) throws -> URL {
        let books = OrgManager.shared.allBooks(in: context)
        var rows = [CSVEscaping.row(portableCSVHeader)]
        for book in books.sorted(by: { $0.title < $1.title }) {
            rows.append(CSVEscaping.row([
                book.title,
                book.authors,
                book.isbn,
                book.publisher,
                book.publishedYearValue.map(String.init) ?? "",
                book.format?.name ?? "",
                book.bindingOption?.name ?? "",
                book.location?.name ?? "",
                String(Int(book.copies)),
                String(format: "%.2f", book.listPrice),
                book.actualCostValue.map { String(format: "%.2f", $0) } ?? "",
                book.rating > 0 ? String(format: "%.1f", book.rating) : "",
                book.reviewNotes,
            ]))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Stacked-Library-\(fileTimestamp()).csv")
        try Data(rows.joined(separator: "\n").utf8).write(to: url)
        return url
    }

    @MainActor
    static func backupPayload(_ org: Org, context: NSManagedObjectContext) throws -> LibraryExportPayload {
        let books = OrgManager.shared.allBooks(in: context)
        return LibraryExportPayload(
            stackedLibraryExport: LibraryExportRoot(
                version: 1,
                exportedAt: Date(),
                exportedByDisplayName: CloudKitIdentityService.shared.displayName,
                orgName: org.name,
                taxonomy: ExportTaxonomy(
                    locations: OrgManager.shared.locations.map(\.name),
                    formats: OrgManager.shared.formats.map(\.name),
                    bindings: OrgManager.shared.bindings.map(\.name)
                ),
                books: books.map(exportBook)
            )
        )
    }

    static func previewImport(from url: URL) throws -> MigrationPreview {
        let data = try Data(contentsOf: url)
        return try previewImport(from: data)
    }

    static func previewImport(from data: Data) throws -> MigrationPreview {
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
    static func applyImport(_ preview: MigrationPreview, into org: Org, context: NSManagedObjectContext) throws {
        guard let collection = OrgManager.shared.defaultCollection(in: context) else {
            throw BookSearchError.transport("No collection to import into.")
        }
        let identity = CloudKitIdentityService.shared
        let importDate = Date()

        for name in preview.payload.stackedLibraryExport.taxonomy.locations {
            _ = TaxonomyService.findOrCreateLocation(name: name, org: org, in: context)
        }
        for name in preview.payload.stackedLibraryExport.taxonomy.formats {
            _ = TaxonomyService.findOrCreateFormat(name: name, org: org, in: context)
        }
        for name in preview.payload.stackedLibraryExport.taxonomy.bindings {
            _ = TaxonomyService.findOrCreateBinding(name: name, org: org, in: context)
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
                book.location = TaxonomyService.findOrCreateLocation(name: exported.location, org: org, in: context)
            }
            if !exported.format.isEmpty {
                book.format = TaxonomyService.findOrCreateFormat(name: exported.format, org: org, in: context)
            }
            if !exported.binding.isEmpty {
                book.bindingOption = TaxonomyService.findOrCreateBinding(name: exported.binding, org: org, in: context)
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

    private static func fileTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}

extension UTType {
    static let stackedLibrary = UTType(exportedAs: "com.thompson.Stacked.library")
}
