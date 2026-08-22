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
        XCTAssertFalse(OrgSharePolicy.canCreateShare(isPlus: false, hasExistingShare: false))
        XCTAssertTrue(OrgSharePolicy.canCreateShare(isPlus: false, hasExistingShare: true))
        XCTAssertTrue(OrgSharePolicy.canCreateShare(isPlus: true, hasExistingShare: false))
    }

    func testOwnerPlusCoversParticipantsUntilExpiration() {
        let future = Date().addingTimeInterval(60)
        XCTAssertTrue(
            OrgAccessPolicy.hasPlusAccess(
                localIsPlus: false,
                role: .participant,
                ownerHasPermanentPlus: false,
                ownerPlusExpirationDate: future
            )
        )
        XCTAssertFalse(
            OrgAccessPolicy.hasPlusAccess(
                localIsPlus: true,
                role: .participant,
                ownerHasPermanentPlus: false,
                ownerPlusExpirationDate: Date().addingTimeInterval(-1)
            )
        )
    }

    func testPermanentOwnerAccessCoversParticipants() {
        XCTAssertTrue(
            OrgAccessPolicy.hasPlusAccess(
                localIsPlus: false,
                role: .participant,
                ownerHasPermanentPlus: true,
                ownerPlusExpirationDate: nil
            )
        )
    }

    func testPromoCodeValidationIsCaseInsensitiveAndIgnoresSpaces() {
        XCTAssertTrue(PlusPromoCode.isValidCode("9bjp-qa4b-cmwm-bwa2"))
        XCTAssertTrue(PlusPromoCode.isValidCode(" 9BJP-QA4B-CMWM-BWA2 "))
        XCTAssertTrue(PlusPromoCode.isValidCode("9BJP QA4B CMWM BWA2"))
        XCTAssertFalse(PlusPromoCode.isValidCode("STACKED-PLUS"))
        XCTAssertFalse(PlusPromoCode.isValidCode(""))
    }
}

final class BookIdentityTests: XCTestCase {
    func testISBN10AndISBN13ResolveToSameIdentity() {
        let isbn10 = "0306406152"
        let isbn13 = "9780306406157"
        XCTAssertEqual(BookIdentity.canonicalISBN(isbn10), isbn13)
        XCTAssertEqual(
            BookIdentity.key(isbn: isbn10, title: "", authors: "", publishedYear: nil),
            BookIdentity.key(isbn: isbn13, title: "", authors: "", publishedYear: nil)
        )
    }

    func testManualIdentityIgnoresCaseSpacingAndDiacritics() {
        XCTAssertEqual(
            BookIdentity.key(isbn: "", title: "  Cien   Años ", authors: "GARCÍA", publishedYear: 1967),
            BookIdentity.key(isbn: "", title: "cien años", authors: "garcia", publishedYear: 1967)
        )
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
                orgName: "Home",
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
        OrgManager.shared.refresh(in: persistence.viewContext)

        guard let org = OrgManager.shared.activeOrg,
              let collection = OrgManager.shared.defaultCollection(in: persistence.viewContext) else {
            XCTFail("Expected a seeded org")
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
                    orgName: "Other",
                    taxonomy: ExportTaxonomy(locations: ["Home Library"], formats: ["Books"], bindings: ["Paperback"]),
                    books: [
                        sampleBook(isbn: "9780000000001", title: "Owned", copies: 2, location: "Home Library"),
                        sampleBook(isbn: "9780000000002", title: "New", copies: 1, location: "Home Library"),
                    ]
                )
            )
        ))

        try LibraryMigrationService.applyImport(
            preview,
            into: org,
            context: persistence.viewContext,
            access: .enforceLimits(hasPlusAccess: true, canContribute: true)
        )

        persistence.viewContext.refreshAllObjects()
        XCTAssertEqual(Int(existing.copies), 3)
        let titles = OrgManager.shared.allBooks(in: persistence.viewContext).map(\.isbn).sorted()
        XCTAssertEqual(titles, ["9780000000001", "9780000000002"])
    }

    @MainActor
    func testFreeImportCannotAddBeyondUniqueTitleLimit() async throws {
        let persistence = PersistenceController(inMemory: true)
        await persistence.waitUntilStoresAreLoaded()
        SeedData.seedIfNeeded(persistence.viewContext)
        OrgManager.shared.refresh(in: persistence.viewContext)

        guard let org = OrgManager.shared.activeOrg,
              let collection = OrgManager.shared.defaultCollection(in: persistence.viewContext) else {
            XCTFail("Expected a seeded org")
            return
        }
        for index in 0..<EntitlementPolicy.freeUniqueTitleLimit {
            _ = Book.create(
                in: persistence.viewContext,
                collection: collection,
                isbn: String(format: "978000000%04d", index),
                title: "Existing \(index)"
            )
        }
        try persistence.viewContext.save()

        let payload = LibraryExportPayload(
            stackedLibraryExport: LibraryExportRoot(
                version: 1,
                exportedAt: Date(),
                exportedByDisplayName: "Importer",
                orgName: "Other",
                taxonomy: ExportTaxonomy(locations: ["Home Library"], formats: [], bindings: []),
                books: [sampleBook(isbn: "9789999999999", title: "One too many", copies: 1, location: "Home Library")]
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let preview = try LibraryMigrationService.previewImport(from: encoder.encode(payload))

        XCTAssertThrowsError(
            try LibraryMigrationService.applyImport(
                preview,
                into: org,
                context: persistence.viewContext,
                access: .enforceLimits(hasPlusAccess: false, canContribute: true)
            )
        )
    }

    @MainActor
    func testBackupUsesRequestedOrgInsteadOfActiveOrg() async throws {
        let persistence = PersistenceController(inMemory: true)
        await persistence.waitUntilStoresAreLoaded()
        SeedData.seedIfNeeded(persistence.viewContext)
        OrgManager.shared.refresh(in: persistence.viewContext)

        let otherOrg = Org.create(in: persistence.viewContext, name: "Department")
        let otherCollection = BookCollection.create(
            in: persistence.viewContext,
            org: otherOrg,
            name: "Department Library",
            ownerDisplayName: "Test",
            ownerCloudRecordName: ""
        )
        _ = Book.create(
            in: persistence.viewContext,
            collection: otherCollection,
            isbn: "9780306406157",
            title: "Department Book"
        )
        _ = StorageLocation.create(
            in: persistence.viewContext,
            org: otherOrg,
            name: "Department Office",
            isDefault: true
        )
        try persistence.viewContext.save()

        let payload = try LibraryMigrationService.backupPayload(
            otherOrg,
            context: persistence.viewContext
        ).stackedLibraryExport
        XCTAssertEqual(payload.orgName, "Department")
        XCTAssertEqual(payload.books.map(\.title), ["Department Book"])
        XCTAssertEqual(payload.taxonomy.locations, ["Department Office"])
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
