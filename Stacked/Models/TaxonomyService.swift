//
//  TaxonomyService.swift
//  Stacked
//
//  Find-or-create helpers for Locations, Formats, and Bindings.
//

import Foundation
import SwiftData

enum TaxonomyService {
    @MainActor
    static func findOrCreateLocation(name: String, in context: ModelContext) -> StorageLocation? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = (try? context.fetch(FetchDescriptor<StorageLocation>())) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        let location = StorageLocation(name: trimmed, isDefault: isFirst)
        context.insert(location)
        return location
    }

    @MainActor
    static func findOrCreateFormat(name: String, in context: ModelContext) -> ItemFormat? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = (try? context.fetch(FetchDescriptor<ItemFormat>())) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        let format = ItemFormat(name: trimmed, isDefault: isFirst)
        context.insert(format)
        return format
    }

    @MainActor
    static func findOrCreateBinding(name: String, in context: ModelContext) -> ItemBinding? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = (try? context.fetch(FetchDescriptor<ItemBinding>())) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        let binding = ItemBinding(name: trimmed, isDefault: isFirst)
        context.insert(binding)
        return binding
    }

    @MainActor
    static func migrateLegacyBindings(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "didMigrateBindingsV1") else { return }
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        for book in books {
            guard book.bindingOption == nil, !book.binding.isEmpty else { continue }
            book.bindingOption = findOrCreateBinding(name: book.binding, in: context)
            book.binding = ""
        }
        UserDefaults.standard.set(true, forKey: "didMigrateBindingsV1")
    }
}
