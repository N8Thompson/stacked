//
//  SubscriptionService.swift
//  Stacked
//
//  StoreKit 2 wrapper for Stacked Plus. Injectable for tests.
//

import Foundation
import StoreKit

@MainActor
protocol SubscriptionProviding: AnyObject {
    var isPlus: Bool { get }
    var products: [Product] { get }
    var purchaseError: String? { get }
    var isLoading: Bool { get }
    func load() async
    func purchase(_ product: Product) async
    func restore() async
}

@MainActor
@Observable
final class SubscriptionService: SubscriptionProviding {
    static let shared = SubscriptionService()

    private(set) var isPlus = false
    private(set) var hasStoreSubscription = false
    private(set) var storeExpirationDate: Date?
    private(set) var products: [Product] = []
    private(set) var purchaseError: String?
    private(set) var isLoading = false

    private var storeIsPlus = false
    private var updatesTask: Task<Void, Never>?

    #if DEBUG
    private static let debugOverrideKey = "stacked.debugForcePlus"

    var hasDebugPlusOverride: Bool {
        UserDefaults.standard.object(forKey: Self.debugOverrideKey) != nil
    }
    #endif

    private init() {
        applyResolvedEntitlement()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil
        do {
            products = try await Product.products(for: EntitlementPolicy.allProductIDs)
                .sorted { $0.price < $1.price }
            if products.isEmpty {
                purchaseError = "Subscriptions are temporarily unavailable. Please try again shortly."
            }
        } catch {
            purchaseError = friendlyPurchaseError(error)
        }
        await refreshEntitlements()
        startListeningForUpdatesIfNeeded()
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshEntitlements()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval. You’ll get access after it’s approved."
            @unknown default:
                break
            }
        } catch {
            purchaseError = friendlyPurchaseError(error)
        }
    }

    func restore() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPlus {
                purchaseError = "No active Stacked + subscription was found for this Apple Account."
            }
        } catch {
            purchaseError = friendlyPurchaseError(error)
        }
        applyResolvedEntitlement()
    }

    func refreshEntitlements() async {
        var entitled = false
        var latestExpiration: Date?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if EntitlementPolicy.allProductIDs.contains(transaction.productID) {
                entitled = true
                if let expiration = transaction.expirationDate {
                    if let current = latestExpiration {
                        latestExpiration = max(current, expiration)
                    } else {
                        latestExpiration = expiration
                    }
                }
            }
        }
        storeIsPlus = entitled
        storeExpirationDate = latestExpiration
        applyResolvedEntitlement()
        await OrgSharingService.shared.publishOwnerEntitlementIfNeeded()
    }

    #if DEBUG
    func setDebugPlus(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.debugOverrideKey)
        applyResolvedEntitlement()
    }
    #endif

    private func applyResolvedEntitlement() {
        hasStoreSubscription = storeIsPlus
        #if DEBUG
        if UserDefaults.standard.object(forKey: Self.debugOverrideKey) != nil {
            isPlus = UserDefaults.standard.bool(forKey: Self.debugOverrideKey)
            return
        }
        #endif
        isPlus = storeIsPlus
    }

    func hasPlusAccess(for org: Org?, role: OrgRole) -> Bool {
        OrgAccessPolicy.hasPlusAccess(
            localIsPlus: isPlus,
            role: role,
            ownerHasPermanentPlus: org?.ownerHasPermanentPlus ?? false,
            ownerPlusExpirationDate: org?.ownerPlusExpirationDate
        )
    }

    var currentOrgHasPlusAccess: Bool {
        hasPlusAccess(
            for: OrgManager.shared.activeOrg,
            role: OrgSharingService.shared.currentRole
        )
    }

    var canContributeToCurrentOrg: Bool {
        let role = OrgSharingService.shared.currentRole
        if role == .participant {
            return currentOrgHasPlusAccess
        }
        return true
    }

    private func startListeningForUpdatesIfNeeded() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    continue
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func friendlyPurchaseError(_ error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return "A network error occurred. Check your connection and try again."
            case .systemError:
                return "Unable to complete the purchase. Please try again in a moment."
            case .notAvailableInStorefront:
                return "This subscription isn’t available in your App Store country or region."
            case .notEntitled:
                return "This Apple Account isn’t entitled to this purchase."
            case .userCancelled:
                return "Purchase canceled."
            default:
                break
            }
        }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty || message.localizedCaseInsensitiveContains("Unable to Complete Request") {
            return "Unable to complete the purchase. Confirm you’re signed into the App Store and try again."
        }
        return message
    }
}

#if DEBUG
@MainActor
@Observable
final class PreviewSubscriptionService: SubscriptionProviding {
    var isPlus: Bool
    var products: [Product] = []
    var purchaseError: String?
    var isLoading = false

    init(isPlus: Bool = false) {
        self.isPlus = isPlus
    }

    func load() async {}
    func purchase(_ product: Product) async {}
    func restore() async {}
}
#endif
