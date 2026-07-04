//
//  SeedData.swift
//  Stacked
//
//  Seeds default Location and Formats on first launch.
//

import Foundation
import SwiftData

enum SeedData {
    static let defaultLocationName = "Home Library"
    static let defaultFormatNames = ["Book", "Journal", "Magazine"]

    /// Inserts default records if the store is empty. Safe to call on every launch.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        seedLocationsIfNeeded(context)
        seedFormatsIfNeeded(context)
        try? context.save()
    }

    @MainActor
    private static func seedLocationsIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<StorageLocation>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(StorageLocation(name: defaultLocationName, isDefault: true))
    }

    @MainActor
    private static func seedFormatsIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ItemFormat>())) ?? []
        guard existing.isEmpty else { return }
        for (index, name) in defaultFormatNames.enumerated() {
            context.insert(ItemFormat(name: name, isDefault: index == 0))
        }
    }
}
