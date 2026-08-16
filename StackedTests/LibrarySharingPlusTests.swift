//
//  LibrarySharingPlusTests.swift
//  StackedTests
//

import CoreData
import XCTest
@testable import Stacked

final class CSVEscapingTests: XCTestCase {
    func testLeavesPlainFieldsUnquoted() {
        XCTAssertEqual(CSVEscaping.escape("Paperback"), "Paperback")
        XCTAssertEqual(CSVEscaping.row(["Title", "Authors"]), "Title,Authors")
    }

    func testQuotesCommasQuotesAndNewlines() {
        XCTAssertEqual(CSVEscaping.escape("Hello, world"), "\"Hello, world\"")
        XCTAssertEqual(CSVEscaping.escape("She said \"hi\""), "\"She said \"\"hi\"\"\"")
        XCTAssertEqual(CSVEscaping.escape("line1\nline2"), "\"line1\nline2\"")
        XCTAssertEqual(CSVEscaping.escape("line1\rline2"), "\"line1\rline2\"")
    }
}

final class EntitlementPolicyTests: XCTestCase {
    func testFreeTitleLimitAllowsCopiesButNotAnotherUniqueTitle() {
        XCTAssertTrue(EntitlementPolicy.canAddUniqueTitle(isPlus: false, currentUniqueTitles: 49))
        XCTAssertFalse(EntitlementPolicy.canAddUniqueTitle(isPlus: false, currentUniqueTitles: 50))
        XCTAssertTrue(EntitlementPolicy.canAddUniqueTitle(isPlus: true, currentUniqueTitles: 500))
    }

    func testFreeLocationLimit() {
        XCTAssertTrue(EntitlementPolicy.canAddLocation(isPlus: false, currentLocations: 1))
        XCTAssertFalse(EntitlementPolicy.canAddLocation(isPlus: false, currentLocations: 2))
        XCTAssertTrue(EntitlementPolicy.canAddLocation(isPlus: true, currentLocations: 12))
    }

    func testRemainingTitlesIsNilForPlus() {
        XCTAssertEqual(EntitlementPolicy.remainingUniqueTitles(isPlus: false, currentUniqueTitles: 40), 10)
        XCTAssertNil(EntitlementPolicy.remainingUniqueTitles(isPlus: true, currentUniqueTitles: 40))
    }

    func testSubscriptionStateFromProductIDs() {
        XCTAssertEqual(
            SubscriptionState.fromEntitledProductIDs([EntitlementPolicy.monthlyProductID]),
            .plus
        )
        XCTAssertEqual(
            SubscriptionState.fromEntitledProductIDs([EntitlementPolicy.annualProductID]),
            .plus
        )
        XCTAssertEqual(SubscriptionState.fromEntitledProductIDs(["unrelated.product"]), .free)
        XCTAssertFalse(SubscriptionState.free.isPlus)
        XCTAssertTrue(SubscriptionState.plus.isPlus)
    }

    func testShareCreationRequiresPlusUnlessShareExists() {
        XCTAssertFalse(HouseholdSharePolicy.canCreateShare(isPlus: false, hasExistingShare: false))
        XCTAssertTrue(HouseholdSharePolicy.canCreateShare(isPlus: false, hasExistingShare: true))
        XCTAssertTrue(HouseholdSharePolicy.canCreateShare(isPlus: true, hasExistingShare: false))
    }
}

final class CopyDeletionPolicyTests: XCTestCase {
    func testPartialRemovalKeepsTheEntry() {
        XCTAssertEqual(CopyDeletionPolicy.action(copyCount: 3, removeCount: 1), .removeCopies(1))
        XCTAssertEqual(CopyDeletionPolicy.action(copyCount: 3, removeCount: 2), .removeCopies(2))
        XCTAssertFalse(CopyDeletionPolicy.showsCollapsedRemoveAll(copyCount: 3, removeCount: 2))
    }

    func testRemovingAllCopiesDeletesTheEntry() {
        XCTAssertEqual(CopyDeletionPolicy.action(copyCount: 3, removeCount: 3), .deleteEntry)
        XCTAssertEqual(CopyDeletionPolicy.action(copyCount: 1, removeCount: 1), .deleteEntry)
        XCTAssertTrue(CopyDeletionPolicy.showsCollapsedRemoveAll(copyCount: 3, removeCount: 3))
    }
}

final class PersistenceSwitchPolicyTests: XCTestCase {
    func testOwnerCanDisconnectToLocal() {
        XCTAssertEqual(
            PersistenceSwitchPolicy.disconnectKind(mode: .iCloud, role: .owner, usesCloudKit: true),
            .disconnectToLocal
        )
    }

    func testParticipantMustLeaveAndKeepACopy() {
        XCTAssertEqual(
            PersistenceSwitchPolicy.disconnectKind(mode: .iCloud, role: .participant, usesCloudKit: true),
            .leaveAndKeepLocalCopy
        )
    }

    func testLocalModeReconnects() {
        XCTAssertEqual(
            PersistenceSwitchPolicy.disconnectKind(mode: .local, role: .localOnly, usesCloudKit: false),
            .reconnect
        )
    }

    func testMacCloudKitOffWithoutLocalIsUnavailable() {
        XCTAssertEqual(
            PersistenceSwitchPolicy.disconnectKind(mode: .iCloud, role: .localOnly, usesCloudKit: false),
            .notAvailable
        )
    }
}

final class LibraryMigrationTests: XCTestCase {
    func testPreviewImportCountsTitlesCopiesAndLocations() throws {
        let payload = LibraryExportPayload(
            stackedLibraryExport: LibraryExportRoot(
                version: 1,
                exportedAt: Date(),
                exportedByDisplayName: "Test",
                householdName: "Home",
                taxonomy: ExportTaxonomy(locations: ["Home Library", "Office"], formats: ["Books"], bindings: ["Paperback"]),
                books: [
                    sampleBook(isbn: "9780000000001", title: "One", copies: 2, location: "Home Library"),
                    sampleBook(isbn: "9780000000002", title: "Two", copies: 1, location: "Office"),
                ]
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let preview = try LibraryMigrationService.previewImport(from: data)
        XCTAssertEqual(preview.uniqueTitles, 2)
        XCTAssertEqual(preview.totalCopies, 3)
        XCTAssertEqual(preview.locationCount, 2)
    }

    @MainActor
    func testImportMergesMatchingISBNIntoExistingCopies() async throws {
        let persistence = PersistenceController(inMemory: true)
        await persistence.waitUntilStoresAreLoaded()
        SeedData.seedIfNeeded(persistence.viewContext)
        HouseholdManager.shared.refresh(in: persistence.viewContext)

        guard let household = HouseholdManager.shared.activeHousehold,
              let collection = HouseholdManager.shared.defaultCollection(in: persistence.viewContext) else {
            XCTFail("Expected a seeded household")
            return
        }

        let existing = Book.create(
            in: persistence.viewContext,
            collection: collection,
            isbn: "9780000000001",
            title: "Owned",
            copies: 1
        )
        try persistence.viewContext.save()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let preview = try LibraryMigrationService.previewImport(from: encoder.encode(
            LibraryExportPayload(
                stackedLibraryExport: LibraryExportRoot(
                    version: 1,
                    exportedAt: Date(),
                    exportedByDisplayName: "Importer",
                    householdName: "Other",
                    taxonomy: ExportTaxonomy(locations: ["Home Library"], formats: ["Books"], bindings: ["Paperback"]),
                    books: [
                        sampleBook(isbn: "9780000000001", title: "Owned", copies: 2, location: "Home Library"),
                        sampleBook(isbn: "9780000000002", title: "New", copies: 1, location: "Home Library"),
                    ]
                )
            )
        ))

        try LibraryMigrationService.applyImport(preview, into: household, context: persistence.viewContext)

        persistence.viewContext.refreshAllObjects()
        XCTAssertEqual(Int(existing.copies), 3)
        let titles = HouseholdManager.shared.allBooks(in: persistence.viewContext).map(\.isbn).sorted()
        XCTAssertEqual(titles, ["9780000000001", "9780000000002"])
    }

    private func sampleBook(isbn: String, title: String, copies: Int, location: String) -> ExportBook {
        ExportBook(
            isbn: isbn,
            title: title,
            authors: "Author",
            publisher: "Pub",
            publishedYear: 2020,
            synopsis: "",
            coverURL: "",
            coverOverrideBase64: nil,
            listPrice: 10,
            actualCost: nil,
            copies: copies,
            rating: 0,
            reviewNotes: "",
            location: location,
            format: "Books",
            binding: "Paperback",
            isManualEntry: false,
            addedAt: Date(),
            addedByDisplayName: "Test",
            createdAt: Date()
        )
    }
}
