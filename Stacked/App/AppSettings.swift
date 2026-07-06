//
//  AppSettings.swift
//  Stacked
//
//  User preferences; cost tracking lives on the active Household and syncs via iCloud.
//

import Foundation

@MainActor
@Observable
final class AppSettings {
    var showCostTracking: Bool {
        get { HouseholdManager.shared.activeHousehold?.showCostTracking ?? true }
        set {
            HouseholdManager.shared.activeHousehold?.showCostTracking = newValue
            PersistenceController.shared.save()
        }
    }
}

extension AppTab {
    static var mainTabs: [AppTab] {
        allCases.filter { $0 != .cost }
    }
}
