//
//  PaywallView.swift
//  Stacked
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    var reason: String = "Enjoy these benefits when you upgrade to Stacked +."

    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: PaywallTier = .plus
    @State private var selectedPeriod: PlusPeriod = .annual

    private enum PaywallTier {
        case plus
        case free
    }

    private enum PlusPeriod {
        case annual
        case monthly
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        titleBlock
                        benefits
                        plans
                        if let purchaseError = subscriptions.purchaseError {
                            Text(purchaseError)
                                .font(.footnote)
                                .foregroundStyle(StackedTheme.Semantic.destructive)
                                .frame(maxWidth: .infinity)
                        }
                        disclaimer
                        subscribeButton
                        legalLinks
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .presentationBackground {
            Color(hex: 0x141F1C)
        }
        #endif
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 680)
        #endif
        .task {
            await subscriptions.load()
            if subscriptions.isPlus { dismiss() }
            if annualProduct == nil, monthlyProduct != nil {
                selectedPeriod = .monthly
            }
        }
        .onChange(of: subscriptions.isPlus) { _, entitled in
            if entitled { dismiss() }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x141F1C),
                    StackedTheme.Brand.forest,
                    StackedTheme.Brand.moss,
                    Color(hex: 0x141F1C),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [StackedTheme.Brand.sage.opacity(0.22), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StackedTheme.Brand.cream.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(StackedTheme.Brand.cream.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock Stacked +")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(StackedTheme.Brand.cream)
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(StackedTheme.Brand.cream.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("Unlimited titles and locations")
            benefit("Bluetooth rapid scanner")
            benefit("Cost tracking")
            benefit("Share a collection with other users")
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(StackedTheme.Brand.sageLight)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(StackedTheme.Brand.cream)
        }
    }

    // MARK: Plans

    private var plans: some View {
        VStack(spacing: 12) {
            plusPlanCard
            freePlanCard
        }
    }

    private var plusPlanCard: some View {
        let selected = selectedTier == .plus
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedTier = .plus
            } label: {
                HStack {
                    Text("Stacked +")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(StackedTheme.Brand.cream)
                    Spacer()
                    selectionMark(selected)
                }
            }
            .buttonStyle(.plain)

            if selected {
                VStack(spacing: 8) {
                    periodRow(
                        title: "Yearly",
                        price: annualPriceLabel,
                        badge: annualDiscountBadge,
                        selected: selectedPeriod == .annual,
                        enabled: annualProduct != nil || subscriptions.products.isEmpty
                    ) {
                        selectedTier = .plus
                        selectedPeriod = .annual
                    }
                    periodRow(
                        title: "Monthly",
                        price: monthlyPriceLabel,
                        badge: nil,
                        selected: selectedPeriod == .monthly,
                        enabled: monthlyProduct != nil || subscriptions.products.isEmpty
                    ) {
                        selectedTier = .plus
                        selectedPeriod = .monthly
                    }
                }
            } else {
                Text(plusSummary)
                    .font(.footnote)
                    .foregroundStyle(StackedTheme.Brand.cream.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StackedTheme.Brand.cream.opacity(selected ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    selected ? StackedTheme.Brand.sageLight : StackedTheme.Brand.cream.opacity(0.16),
                    lineWidth: selected ? 2 : 1
                )
        )
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Group {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(StackedTheme.Brand.sageLight)
            } else {
                Circle()
                    .strokeBorder(StackedTheme.Brand.cream.opacity(0.28), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
    }

    private var freePlanCard: some View {
        let selected = selectedTier == .free
        return Button {
            selectedTier = .free
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stacked")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(StackedTheme.Brand.cream)
                    Text("\(EntitlementPolicy.freeUniqueTitleLimit) titles · \(EntitlementPolicy.freeLocationLimit) locations · Free")
                        .font(.footnote)
                        .foregroundStyle(StackedTheme.Brand.cream.opacity(0.6))
                }
                Spacer()
                if selected {
                    selectionMark(true)
                } else {
                    selectionMark(false)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(StackedTheme.Brand.cream.opacity(selected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        selected ? StackedTheme.Brand.sageLight : StackedTheme.Brand.cream.opacity(0.16),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func periodRow(
        title: String,
        price: String,
        badge: String?,
        selected: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? StackedTheme.Brand.sageLight : StackedTheme.Brand.cream.opacity(0.35),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(StackedTheme.Brand.sageLight)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StackedTheme.Brand.cream)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(StackedTheme.Brand.forest)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(StackedTheme.Brand.gold))
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(StackedTheme.Brand.cream.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(StackedTheme.Brand.cream.opacity(selected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selected ? StackedTheme.Brand.sageLight.opacity(0.85) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private var disclaimer: some View {
        Text(disclaimerText)
            .font(.caption)
            .foregroundStyle(StackedTheme.Brand.cream.opacity(0.5))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var subscribeButton: some View {
        Button {
            Task { await confirmSelection() }
        } label: {
            Group {
                if subscriptions.isLoading, selectedTier == .plus {
                    ProgressView()
                        .tint(StackedTheme.Brand.forest)
                } else {
                    Text(selectedTier == .plus ? "Subscribe" : "Continue with Stacked")
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(StackedTheme.Brand.forest)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(StackedTheme.Brand.cream)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedTier == .plus && subscriptions.isLoading)
    }

    private var legalLinks: some View {
        HStack(spacing: 0) {
            Button("Restore Purchase") {
                Task { await subscriptions.restore() }
            }
            Spacer()
            Link("Privacy Policy", destination: EntitlementPolicy.privacyURL)
            Spacer()
            Link("Terms of Use", destination: EntitlementPolicy.termsURL)
        }
        .font(.footnote)
        .foregroundStyle(StackedTheme.Brand.cream.opacity(0.55))
        .padding(.top, 4)
    }

    // MARK: Copy and products

    private var monthlyProduct: Product? {
        subscriptions.products.first { $0.id == EntitlementPolicy.monthlyProductID }
    }

    private var annualProduct: Product? {
        subscriptions.products.first { $0.id == EntitlementPolicy.annualProductID }
    }

    private var monthlyPriceLabel: String {
        if let monthlyProduct {
            return "\(monthlyProduct.displayPrice)/month"
        }
        return "$2.99/month"
    }

    private var annualPriceLabel: String {
        if let annualProduct {
            return "\(annualProduct.displayPrice)/year"
        }
        return "$24.99/year"
    }

    private var annualDiscountBadge: String? {
        guard let percent = annualSavingsPercent else { return nil }
        return "-\(percent)%"
    }

    private var annualSavingsPercent: Int? {
        let monthly = monthlyProduct.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 2.99
        let annual = annualProduct.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 24.99
        let yearOfMonthly = monthly * 12
        guard yearOfMonthly > annual, yearOfMonthly > 0 else { return nil }
        return max(1, Int((1 - annual / yearOfMonthly) * 100))
    }

    private var plusSummary: String {
        "\(annualPriceLabel) or \(monthlyPriceLabel)"
    }

    private var disclaimerText: String {
        switch selectedTier {
        case .free:
            return "You can upgrade to Stacked + anytime."
        case .plus:
            if selectedPeriod == .annual, hasAnnualTrial {
                return "7-day free trial, then \(annualPriceLabel). Auto-renews until canceled."
            }
            if selectedPeriod == .annual {
                return "\(annualPriceLabel). Auto-renews until canceled."
            }
            return "\(monthlyPriceLabel). Auto-renews until canceled."
        }
    }

    private var hasAnnualTrial: Bool {
        annualProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private func confirmSelection() async {
        switch selectedTier {
        case .free:
            dismiss()
        case .plus:
            let product = selectedPeriod == .annual ? annualProduct : monthlyProduct
            guard let product else {
                await subscriptions.load()
                return
            }
            await subscriptions.purchase(product)
        }
    }
}
