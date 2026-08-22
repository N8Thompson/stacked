//
//  AppSettings.swift
//  Stacked
//
//  User preferences. Cost tracking follows the active org owner's Plus access,
//  so every participant sees the same shared cost information.
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
        SubscriptionService.shared.hasPlusAccess(
            for: OrgManager.shared.activeOrg,
            role: OrgSharingService.shared.currentRole
        ) && costTrackingPreference
    }
}
