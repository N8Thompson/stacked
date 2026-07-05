//
//  AppSettings.swift
//  Stacked
//
//  User preferences persisted via UserDefaults.
//

import Foundation

@Observable
final class AppSettings {
    private static let costTrackingKey = "showCostTracking"

    /// When false, cost values are hidden in the UI. Values are still stored on each item.
    /// The cost report is opened from Settings when enabled.
    var showCostTracking: Bool {
        didSet {
            UserDefaults.standard.set(showCostTracking, forKey: Self.costTrackingKey)
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.costTrackingKey) != nil {
            showCostTracking = UserDefaults.standard.bool(forKey: Self.costTrackingKey)
        } else {
            showCostTracking = true
        }
    }
}

extension AppTab {
    /// Main navigation tabs. Cost is accessed from Settings, not the tab bar.
    static var mainTabs: [AppTab] {
        allCases.filter { $0 != .cost }
    }
}
