//
//  PersistenceSwitchService.swift
//  Stacked
//
//  Copies the active collection between iCloud and a local-only store.
//

import CoreData
import Foundation

enum PersistenceSwitchService {
    @MainActor
    static func copyActiveLibraryToLocalStore() async throws {
        let source = PersistenceController.shared
        guard let household = HouseholdManager.shared.activeHousehold else {
            throw BookSearchError.transport("There is no library to keep on this device.")
        }
        let payload = try LibraryMigrationService.backupPayload(household, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))

        source.reload(mode: .local)
        HouseholdManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        SeedData.seedIfNeeded(source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
        guard let localHousehold = HouseholdManager.shared.activeHousehold else {
            throw BookSearchError.transport("Couldn't create a local library.")
        }
        try LibraryMigrationService.applyImport(preview, into: localHousehold, context: source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
    }

    @MainActor
    static func mergeLocalLibraryIntoiCloud() async throws {
        let source = PersistenceController.shared
        guard source.mode == .local, let household = HouseholdManager.shared.activeHousehold else {
            throw BookSearchError.transport("There is no local library to merge.")
        }
        let payload = try LibraryMigrationService.backupPayload(household, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))

        source.reload(mode: .iCloud)
        HouseholdManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        #if os(iOS)
        await source.waitForInitialCloudKitImport()
        #endif
        SeedData.seedIfNeeded(source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
        guard let cloudHousehold = HouseholdManager.shared.activeHousehold else {
            throw BookSearchError.transport("Couldn't open your iCloud library.")
        }
        try LibraryMigrationService.applyImport(preview, into: cloudHousehold, context: source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
    }

    @MainActor
    static func discardLocalAndUseiCloud() async {
        let source = PersistenceController.shared
        source.reload(mode: .iCloud)
        HouseholdManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        #if os(iOS)
        await source.waitForInitialCloudKitImport()
        #endif
        SeedData.seedIfNeeded(source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
    }

    #if os(iOS)
    @MainActor
    static func leaveShareAndKeepLocalCopy(_ household: Household) async throws {
        let source = PersistenceController.shared
        let payload = try LibraryMigrationService.backupPayload(household, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))
        try await HouseholdSharingService.shared.leaveSharedHousehold(household)
        source.reload(mode: .local)
        HouseholdManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        SeedData.seedIfNeeded(source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
        guard let localHousehold = HouseholdManager.shared.activeHousehold else {
            throw BookSearchError.transport("Couldn't create a local library.")
        }
        try LibraryMigrationService.applyImport(preview, into: localHousehold, context: source.viewContext)
        HouseholdManager.shared.refresh(in: source.viewContext)
    }
    #endif

    private static func encode(_ payload: LibraryExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
}
