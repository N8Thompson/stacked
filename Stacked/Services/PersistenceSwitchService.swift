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
        guard let org = OrgManager.shared.activeOrg else {
            throw BookSearchError.transport("There is no library to keep on this device.")
        }
        let payload = try LibraryMigrationService.backupPayload(org, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))

        source.reload(mode: .local)
        OrgManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        try throwIfStoreFailed(source)
        SeedData.seedIfNeeded(source.viewContext)
        OrgManager.shared.refresh(in: source.viewContext)
        guard let localOrg = OrgManager.shared.activeOrg else {
            throw BookSearchError.transport("Couldn't create a local library.")
        }
        try LibraryMigrationService.applyImport(
            preview,
            into: localOrg,
            context: source.viewContext,
            access: .preserveExistingLibrary
        )
        OrgManager.shared.refresh(in: source.viewContext)
    }

    @MainActor
    static func mergeLocalLibraryIntoiCloud() async throws {
        let source = PersistenceController.shared
        guard source.mode == .local, let org = OrgManager.shared.activeOrg else {
            throw BookSearchError.transport("There is no local library to merge.")
        }
        let payload = try LibraryMigrationService.backupPayload(org, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))
        let hasPlusAccess = SubscriptionService.shared.isPlus

        source.reload(mode: .iCloud)
        OrgManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        await source.waitForInitialCloudKitImport()
        try throwIfStoreFailed(source)
        SeedData.seedIfNeeded(source.viewContext)
        OrgManager.shared.refresh(in: source.viewContext)
        guard let cloudOrg = OrgManager.shared.activeOrg else {
            throw BookSearchError.transport("Couldn't open your iCloud library.")
        }
        try LibraryMigrationService.applyImport(
            preview,
            into: cloudOrg,
            context: source.viewContext,
            access: .enforceLimits(hasPlusAccess: hasPlusAccess, canContribute: true)
        )
        OrgManager.shared.refresh(in: source.viewContext)
    }

    @MainActor
    static func discardLocalAndUseiCloud() async {
        let source = PersistenceController.shared
        source.reload(mode: .iCloud)
        OrgManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        await source.waitForInitialCloudKitImport()
        guard source.loadError == nil else { return }
        SeedData.seedIfNeeded(source.viewContext)
        OrgManager.shared.refresh(in: source.viewContext)
    }

    @MainActor
    static func leaveShareAndKeepLocalCopy(_ org: Org) async throws {
        let source = PersistenceController.shared
        let payload = try LibraryMigrationService.backupPayload(org, context: source.viewContext)
        let preview = try LibraryMigrationService.previewImport(from: encode(payload))
        try await OrgSharingService.shared.leaveSharedOrg(org)
        source.reload(mode: .local)
        OrgManager.shared.restartObserving()
        await source.waitUntilStoresAreLoaded()
        try throwIfStoreFailed(source)
        SeedData.seedIfNeeded(source.viewContext)
        OrgManager.shared.refresh(in: source.viewContext)
        guard let localOrg = OrgManager.shared.activeOrg else {
            throw BookSearchError.transport("Couldn't create a local library.")
        }
        try LibraryMigrationService.applyImport(
            preview,
            into: localOrg,
            context: source.viewContext,
            access: .preserveExistingLibrary
        )
        OrgManager.shared.refresh(in: source.viewContext)
    }

    private static func encode(_ payload: LibraryExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @MainActor
    private static func throwIfStoreFailed(_ persistence: PersistenceController) throws {
        if let message = persistence.loadError {
            throw BookSearchError.transport(message)
        }
    }
}
