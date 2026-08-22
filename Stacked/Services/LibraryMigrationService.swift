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

enum LibraryImportAccess {
    /// Used when copying the same library between this user's local and iCloud stores.
    case preserveExistingLibrary
    /// Used for additive imports and merges into a library.
    case enforceLimits(hasPlusAccess: Bool, canContribute: Bool)
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
    static func portableCSVURL(_ org: Org, context _: NSManagedObjectContext) throws -> URL {
        let books = books(in: org)
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
    static func backupPayload(_ org: Org, context _: NSManagedObjectContext) throws -> LibraryExportPayload {
        let books = books(in: org)
        let locations = ((org.locations as? Set<StorageLocation>) ?? []).map(\.name).sorted()
        let formats = ((org.formats as? Set<ItemFormat>) ?? []).map(\.name).sorted()
        let bindings = ((org.bindings as? Set<ItemBinding>) ?? []).map(\.name).sorted()
        return LibraryExportPayload(
            stackedLibraryExport: LibraryExportRoot(
                version: 1,
                exportedAt: Date(),
                exportedByDisplayName: CloudKitIdentityService.shared.displayName,
                orgName: org.name,
                taxonomy: ExportTaxonomy(
                    locations: locations,
                    formats: formats,
                    bindings: bindings
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
        let unique = Set(books.map {
            BookIdentity.key(
                isbn: $0.isbn,
                title: $0.title,
                authors: $0.authors,
                publishedYear: $0.publishedYear
            )
        }).count
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
    static func applyImport(
        _ preview: MigrationPreview,
        into org: Org,
        context: NSManagedObjectContext,
        access: LibraryImportAccess
    ) throws {
        let collections = (org.collections as? Set<BookCollection>) ?? []
        guard let collection = collections.first(where: \.isActive) ?? collections.first else {
            throw BookSearchError.transport("No collection to import into.")
        }
        try validateImport(preview, into: org, access: access)
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

        var existingBooks = books(in: org)
        var booksByKey = Dictionary(
            existingBooks.map { (bookIdentityKey($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for exported in preview.payload.stackedLibraryExport.books {
            let key = bookIdentityKey(exported)
            if let existing = booksByKey[key] {
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
            booksByKey[key] = book
            existingBooks.append(book)
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

    private static func validateImport(
        _ preview: MigrationPreview,
        into org: Org,
        access: LibraryImportAccess
    ) throws {
        guard case .enforceLimits(let hasPlusAccess, let canContribute) = access else { return }
        guard canContribute else {
            throw BookSearchError.transport(
                "The collection owner's Stacked + access must be active before participants can import books."
            )
        }
        guard !hasPlusAccess else { return }

        let currentBooks = books(in: org)
        let existingKeys = Set(currentBooks.map(bookIdentityKey))
        let incomingKeys = Set(preview.payload.stackedLibraryExport.books.map(bookIdentityKey))
        let newTitleCount = incomingKeys.subtracting(existingKeys).count
        guard existingKeys.count + newTitleCount <= EntitlementPolicy.freeUniqueTitleLimit else {
            throw BookSearchError.transport(
                "This import would exceed the free limit of \(EntitlementPolicy.freeUniqueTitleLimit) unique titles."
            )
        }

        let existingLocations = Set(
            ((org.locations as? Set<StorageLocation>) ?? []).map { BookIdentity.normalizedText($0.name) }
        )
        let root = preview.payload.stackedLibraryExport
        let incomingLocations = Set(
            (root.taxonomy.locations + root.books.map(\.location))
                .map(BookIdentity.normalizedText)
                .filter { !$0.isEmpty }
        )
        let newLocationCount = incomingLocations.subtracting(existingLocations).count
        guard existingLocations.count + newLocationCount <= EntitlementPolicy.freeLocationLimit else {
            throw BookSearchError.transport(
                "This import would exceed the free limit of \(EntitlementPolicy.freeLocationLimit) locations."
            )
        }
    }

    private static func books(in org: Org) -> [Book] {
        let collections = (org.collections as? Set<BookCollection>) ?? []
        return collections.flatMap { ($0.books as? Set<Book>) ?? [] }
    }

    private static func bookIdentityKey(_ book: Book) -> String {
        BookIdentity.key(
            isbn: book.isbn,
            title: book.title,
            authors: book.authors,
            publishedYear: book.publishedYearValue
        )
    }

    private static func bookIdentityKey(_ book: ExportBook) -> String {
        BookIdentity.key(
            isbn: book.isbn,
            title: book.title,
            authors: book.authors,
            publishedYear: book.publishedYear
        )
    }

    private static func fileTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}

extension UTType {
    static let stackedLibrary = UTType(exportedAs: "com.thompson.Stacked.library")
}
