//
//  TaxonomyService.swift
//  Stacked
//
//  Find-or-create helpers for Locations, Formats, and Bindings.
//

import CoreData
import Foundation

enum TaxonomyService {
    @MainActor
    static func findOrCreateLocation(name: String, household: Household, in context: NSManagedObjectContext) -> StorageLocation? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = household.locations as? Set<StorageLocation> ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        return StorageLocation.create(in: context, household: household, name: trimmed, isDefault: isFirst)
    }

    @MainActor
    static func findOrCreateFormat(name: String, household: Household, in context: NSManagedObjectContext) -> ItemFormat? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = household.formats as? Set<ItemFormat> ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        return ItemFormat.create(in: context, household: household, name: trimmed, isDefault: isFirst)
    }

    @MainActor
    static func findOrCreateBinding(name: String, household: Household, in context: NSManagedObjectContext) -> ItemBinding? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = household.bindings as? Set<ItemBinding> ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        let isFirst = existing.isEmpty
        return ItemBinding.create(in: context, household: household, name: trimmed, isDefault: isFirst)
    }

    @MainActor
    static func migrateLegacyBindings(in context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: "didMigrateLegacyBindingsV1") else { return }
        let books = (try? context.fetch(Book.fetchRequest())) ?? []
        for book in books where !book.binding.isEmpty {
            if book.bindingOption == nil, let household = book.collection?.household {
                book.bindingOption = findOrCreateBinding(name: book.binding, household: household, in: context)
            }
            book.binding = ""
        }
        UserDefaults.standard.set(true, forKey: "didMigrateLegacyBindingsV1")
    }

    @MainActor
    static func delete(
        _ location: StorageLocation,
        reassignTo replacement: StorageLocation,
        remainingLocations: [StorageLocation],
        in context: NSManagedObjectContext
    ) {
        for book in location.books as? Set<Book> ?? [] {
            book.location = replacement
        }
        let wasDefault = location.isDefault
        context.delete(location)
        if wasDefault, let next = remainingLocations.first(where: { $0.id != location.id }) {
            next.isDefault = true
        }
    }

    @MainActor
    static func delete(
        _ format: ItemFormat,
        reassignTo replacement: ItemFormat,
        remainingFormats: [ItemFormat],
        in context: NSManagedObjectContext
    ) {
        for book in format.books as? Set<Book> ?? [] {
            book.format = replacement
        }
        let wasDefault = format.isDefault
        context.delete(format)
        if wasDefault, let next = remainingFormats.first(where: { $0.id != format.id }) {
            next.isDefault = true
        }
    }

    @MainActor
    static func delete(
        _ binding: ItemBinding,
        reassignTo replacement: ItemBinding?,
        remainingBindings: [ItemBinding],
        in context: NSManagedObjectContext
    ) {
        for book in binding.books as? Set<Book> ?? [] {
            book.bindingOption = replacement
        }
        let wasDefault = binding.isDefault
        context.delete(binding)
        if wasDefault, let next = remainingBindings.first(where: { $0.id != binding.id }) {
            next.isDefault = true
        }
    }

    @MainActor
    static func performDelete(
        _ request: TaxonomyDeleteRequest,
        replacementLocation: StorageLocation?,
        replacementFormat: ItemFormat?,
        replacementBinding: ItemBinding?,
        locations: [StorageLocation],
        formats: [ItemFormat],
        bindings: [ItemBinding],
        in context: NSManagedObjectContext
    ) {
        switch request.target {
        case .location(let location):
            guard let replacementLocation else { return }
            delete(
                location,
                reassignTo: replacementLocation,
                remainingLocations: locations,
                in: context
            )
        case .format(let format):
            guard let replacementFormat else { return }
            delete(
                format,
                reassignTo: replacementFormat,
                remainingFormats: formats,
                in: context
            )
        case .binding(let binding):
            delete(
                binding,
                reassignTo: replacementBinding,
                remainingBindings: bindings,
                in: context
            )
        }
        PersistenceController.shared.save()
    }
}
