//
//  PlusPromoCode.swift
//  Stacked
//
//  Permanent complimentary Stacked + via redeemable codes.
//  Valid codes are stored as SHA-256 hashes only.
//

import CryptoKit
import Foundation

enum PlusPromoCode {
    static let unlockedKey = "stacked.plus.promoUnlocked"

    /// SHA-256 (hex) of the normalized complimentary code.
    static let validCodeHashes: Set<String> = [
        "fdfa3aee727f398062575faa2e7bf7c43123cc15d495eeaf9b602ab934c20c93",
    ]

    enum RedeemResult: Equatable {
        case unlocked
        case alreadyUnlocked
        case invalid
    }

    static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func hash(_ normalizedCode: String) -> String {
        let digest = SHA256.hash(data: Data(normalizedCode.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func isValidCode(_ raw: String) -> Bool {
        let normalized = normalize(raw)
        guard !normalized.isEmpty else { return false }
        return validCodeHashes.contains(hash(normalized))
    }
}

@MainActor
enum PlusPromoCodeStore {
    private static var ubiquitous: NSUbiquitousKeyValueStore { .default }

    static var isUnlocked: Bool {
        if ubiquitous.bool(forKey: PlusPromoCode.unlockedKey) { return true }
        return UserDefaults.standard.bool(forKey: PlusPromoCode.unlockedKey)
    }

    static func refreshFromiCloud() {
        ubiquitous.synchronize()
        if ubiquitous.bool(forKey: PlusPromoCode.unlockedKey) {
            UserDefaults.standard.set(true, forKey: PlusPromoCode.unlockedKey)
        }
    }

    @discardableResult
    static func redeem(_ raw: String) -> PlusPromoCode.RedeemResult {
        refreshFromiCloud()
        if isUnlocked { return .alreadyUnlocked }
        guard PlusPromoCode.isValidCode(raw) else { return .invalid }

        ubiquitous.set(true, forKey: PlusPromoCode.unlockedKey)
        ubiquitous.synchronize()
        UserDefaults.standard.set(true, forKey: PlusPromoCode.unlockedKey)
        return .unlocked
    }
}
