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
    private(set) var hasComplimentaryPlus = false
    private(set) var hasStoreSubscription = false
    private(set) var products: [Product] = []
    private(set) var purchaseError: String?
    private(set) var isLoading = false

    private var storeIsPlus = false
    private var updatesTask: Task<Void, Never>?
    private var iCloudObserver: NSObjectProtocol?

    #if DEBUG
    private static let debugOverrideKey = "stacked.debugForcePlus"

    var hasDebugPlusOverride: Bool {
        UserDefaults.standard.object(forKey: Self.debugOverrideKey) != nil
    }
    #endif

    private init() {
        PlusPromoCodeStore.refreshFromiCloud()
        observeiCloudPromoUnlock()
        applyResolvedEntitlement()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        PlusPromoCodeStore.refreshFromiCloud()
        do {
            products = try await Product.products(for: EntitlementPolicy.allProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
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
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        purchaseError = nil
        PlusPromoCodeStore.refreshFromiCloud()
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
        applyResolvedEntitlement()
    }

    @discardableResult
    func redeemPromoCode(_ raw: String) -> PlusPromoCode.RedeemResult {
        let result = PlusPromoCodeStore.redeem(raw)
        applyResolvedEntitlement()
        return result
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if EntitlementPolicy.allProductIDs.contains(transaction.productID) {
                entitled = true
                break
            }
        }
        storeIsPlus = entitled
        PlusPromoCodeStore.refreshFromiCloud()
        applyResolvedEntitlement()
    }

    #if DEBUG
    func setDebugPlus(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.debugOverrideKey)
        applyResolvedEntitlement()
    }
    #endif

    private func applyResolvedEntitlement() {
        hasComplimentaryPlus = PlusPromoCodeStore.isUnlocked
        hasStoreSubscription = storeIsPlus
        #if DEBUG
        if UserDefaults.standard.object(forKey: Self.debugOverrideKey) != nil {
            isPlus = UserDefaults.standard.bool(forKey: Self.debugOverrideKey)
            return
        }
        #endif
        isPlus = storeIsPlus || hasComplimentaryPlus
    }

    private func observeiCloudPromoUnlock() {
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                PlusPromoCodeStore.refreshFromiCloud()
                self?.applyResolvedEntitlement()
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
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
