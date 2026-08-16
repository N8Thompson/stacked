//
//  PersistenceMode.swift
//  Stacked
//

import Foundation

enum PersistenceMode: String, Codable {
    case iCloud
    case local

    static let preferenceKey = "stacked.persistenceMode"

    static var current: PersistenceMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: preferenceKey) else {
                #if os(iOS)
                return .iCloud
                #else
                return .local
                #endif
            }
            return PersistenceMode(rawValue: raw) ?? .iCloud
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
        }
    }
}
