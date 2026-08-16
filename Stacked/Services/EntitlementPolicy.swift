//
//  EntitlementPolicy.swift
//  Stacked
//
//  Central free vs Plus limits. Existing data is never hidden or deleted.
//

import Foundation

enum EntitlementPolicy {
    static let freeUniqueTitleLimit = 50
    static let freeLocationLimit = 2

    static let monthlyProductID = "com.thompson.Stacked.plus.monthly"
    static let annualProductID = "com.thompson.Stacked.plus.annual"
    static let allProductIDs: Set<String> = [monthlyProductID, annualProductID]

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://www.apple.com/legal/privacy/")!

    static func uniqueTitleCount(in books: [Book]) -> Int {
        books.count
    }

    static func canAddUniqueTitle(isPlus: Bool, currentUniqueTitles: Int) -> Bool {
        isPlus || currentUniqueTitles < freeUniqueTitleLimit
    }

    static func canAddLocation(isPlus: Bool, currentLocations: Int) -> Bool {
        isPlus || currentLocations < freeLocationLimit
    }

    static func remainingUniqueTitles(isPlus: Bool, currentUniqueTitles: Int) -> Int? {
        guard !isPlus else { return nil }
        return max(0, freeUniqueTitleLimit - currentUniqueTitles)
    }
}
