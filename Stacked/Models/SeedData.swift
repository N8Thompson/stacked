//
//  SeedData.swift
//  Stacked
//
//  Seeds default Org, Collection, Location, Formats, and Bindings on first launch.
//

import CoreData
import Foundation

enum SeedData {
    static let defaultLocationName = "Home Library"
    static let defaultFormatNames = ["Books", "Journals"]
    static let defaultBindingNames = ["Paperback", "Hardcover", "Spiral"]

    @MainActor
    static func seedIfNeeded(_ context: NSManagedObjectContext) {
        let count = (try? context.count(for: Org.fetchRequest())) ?? 0
        guard count == 0 else {
            OrgManager.shared.refresh(in: context)
            return
        }

        let identity = CloudKitIdentityService.shared
        let org = Org.create(in: context, name: "Home")
        _ = BookCollection.create(
            in: context,
            org: org,
            name: "My Library",
            ownerDisplayName: identity.displayName,
            ownerCloudRecordName: identity.recordName ?? ""
        )

        StorageLocation.create(in: context, org: org, name: defaultLocationName, isDefault: true)

        for (index, name) in defaultFormatNames.enumerated() {
            ItemFormat.create(in: context, org: org, name: name, isDefault: index == 0)
        }

        for (index, name) in defaultBindingNames.enumerated() {
            ItemBinding.create(in: context, org: org, name: name, isDefault: index == 0)
        }

        TaxonomyService.migrateLegacyBindings(in: context)
        try? context.save()
        OrgManager.shared.refresh(in: context)
    }
}
