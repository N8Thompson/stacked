//
//  LibraryPolicies.swift
//  Stacked
//
//  Testable rules for copy deletion, persistence switching, and entitlements.
//

import Foundation

enum CopyDeletionPolicy {
    enum Action: Equatable {
        case removeCopies(Int)
        case deleteEntry
    }

    static func action(copyCount: Int, removeCount: Int) -> Action {
        if copyCount <= 1 || removeCount >= copyCount {
            return .deleteEntry
        }
        return .removeCopies(max(1, removeCount))
    }

    static func showsCollapsedRemoveAll(copyCount: Int, removeCount: Int) -> Bool {
        copyCount > 1 && removeCount >= copyCount
    }
}

enum PersistenceSwitchPolicy {
    enum DisconnectKind: Equatable {
        case notAvailable
        case disconnectToLocal
        case leaveAndKeepLocalCopy
        case reconnect
    }

    static func disconnectKind(
        mode: PersistenceMode,
        role: OrgRole,
        usesCloudKit: Bool
    ) -> DisconnectKind {
        guard usesCloudKit || mode == .local else { return .notAvailable }
        if mode == .local { return .reconnect }
        if role == .participant { return .leaveAndKeepLocalCopy }
        return .disconnectToLocal
    }
}

enum SubscriptionState: Equatable {
    case free
    case plus

    var isPlus: Bool { self == .plus }

    static func fromEntitledProductIDs(_ productIDs: Set<String>) -> SubscriptionState {
        productIDs.contains(where: { EntitlementPolicy.allProductIDs.contains($0) }) ? .plus : .free
    }
}

enum OrgSharePolicy {
    static func canCreateShare(isPlus: Bool, hasExistingShare: Bool) -> Bool {
        isPlus || hasExistingShare
    }
}
