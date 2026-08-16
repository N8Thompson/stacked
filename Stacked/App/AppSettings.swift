//
//  AppSettings.swift
//  Stacked
//
//  User preferences. Cost tracking is a Plus-aware preference: subscribers can
//  toggle it, and non-subscribers keep their stored prices without seeing them.
//

import Foundation

@MainActor
@Observable
final class AppSettings {
    var costTrackingPreference: Bool {
        get { OrgManager.shared.activeOrg?.showCostTracking ?? true }
        set {
            OrgManager.shared.activeOrg?.showCostTracking = newValue
            PersistenceController.shared.save()
        }
    }

    var showCostTracking: Bool {
        SubscriptionService.shared.isPlus && costTrackingPreference
    }
}
