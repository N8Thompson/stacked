//
//  AppRouter.swift
//  Stacked
//
//  Shared navigation state: which tab is selected and any filter that Home
//  has requested Manage to apply.
//

import Foundation
import SwiftData

enum AppTab: Int, Hashable, CaseIterable, Identifiable {
    case home
    case manage
    case cost
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .manage: return "Library"
        case .cost: return "Cost"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .manage: return "books.vertical"
        case .cost: return "dollarsign.circle"
        case .settings: return "gearshape"
        }
    }
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .home

    /// A one-shot filter request produced when the user taps a Home tile.
    /// Manage consumes and clears it when it appears.
    var pendingFilter: ManageFilterRequest?

    func openManage(location: StorageLocation? = nil, format: ItemFormat? = nil) {
        pendingFilter = ManageFilterRequest(
            locationID: location?.persistentModelID,
            formatID: format?.persistentModelID
        )
        selectedTab = .manage
    }
}

struct ManageFilterRequest {
    var locationID: PersistentIdentifier?
    var formatID: PersistentIdentifier?
}
