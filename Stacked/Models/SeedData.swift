//
//  SeedData.swift
//  Stacked
//
//  Seeds default Household, Collection, Location, Formats, and Bindings on first launch.
//

import CoreData
import Foundation

enum SeedData {
    static let defaultLocationName = "Home Library"
    static let defaultFormatNames = ["Books", "Journals"]
    static let defaultBindingNames = ["Paperback", "Hardcover", "Spiral"]

    @MainActor
    static func seedIfNeeded(_ context: NSManagedObjectContext) {
        let count = (try? context.count(for: Household.fetchRequest())) ?? 0
        guard count == 0 else {
            HouseholdManager.shared.refresh(in: context)
            return
        }

        let identity = CloudKitIdentityService.shared
        let household = Household.create(in: context, name: "Home")
        _ = BookCollection.create(
            in: context,
            household: household,
            name: "My Library",
            ownerDisplayName: identity.displayName,
            ownerCloudRecordName: identity.recordName ?? ""
        )

        StorageLocation.create(in: context, household: household, name: defaultLocationName, isDefault: true)

        for (index, name) in defaultFormatNames.enumerated() {
            ItemFormat.create(in: context, household: household, name: name, isDefault: index == 0)
        }

        for (index, name) in defaultBindingNames.enumerated() {
            ItemBinding.create(in: context, household: household, name: name, isDefault: index == 0)
        }

        TaxonomyService.migrateLegacyBindings(in: context)
        try? context.save()
        HouseholdManager.shared.refresh(in: context)
    }
}
