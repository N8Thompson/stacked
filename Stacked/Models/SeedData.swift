//
//  SeedData.swift
//  Stacked
//
//  Seeds default Location, Formats, and Bindings on first launch.
//

import Foundation
import SwiftData

enum SeedData {
    static let defaultLocationName = "Home Library"
    static let defaultFormatNames = ["Books", "Journals", "Magazines", "Digital"]
    static let defaultBindingNames = ["Paperback", "Hardcover", "Spiral"]

    /// Inserts default records if the store is empty. Safe to call on every launch.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        seedLocationsIfNeeded(context)
        seedFormatsIfNeeded(context)
        seedBindingsIfNeeded(context)
        migrateFormatNamesIfNeeded(context)
        seedDigitalFormatIfNeeded(context)
        TaxonomyService.migrateLegacyBindings(in: context)
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

    @MainActor
    private static func seedBindingsIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ItemBinding>())) ?? []
        guard existing.isEmpty else { return }
        for (index, name) in defaultBindingNames.enumerated() {
            context.insert(ItemBinding(name: name, isDefault: index == 0))
        }
    }

    /// Renames legacy singular default format names to plural.
    @MainActor
    private static func migrateFormatNamesIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "didMigrateFormatNamesV1") else { return }
        let renames = ["Book": "Books", "Journal": "Journals", "Magazine": "Magazines"]
        let formats = (try? context.fetch(FetchDescriptor<ItemFormat>())) ?? []
        for format in formats {
            if let newName = renames[format.name] {
                format.name = newName
            }
        }
        UserDefaults.standard.set(true, forKey: "didMigrateFormatNamesV1")
    }

    /// Adds the Digital format for existing libraries that predate it.
    @MainActor
    private static func seedDigitalFormatIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "didSeedDigitalFormatV1") else { return }
        let formats = (try? context.fetch(FetchDescriptor<ItemFormat>())) ?? []
        if !formats.contains(where: { $0.name.caseInsensitiveCompare("Digital") == .orderedSame }) {
            context.insert(ItemFormat(name: "Digital", isDefault: false))
        }
        UserDefaults.standard.set(true, forKey: "didSeedDigitalFormatV1")
    }
}
