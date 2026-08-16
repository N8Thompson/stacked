//
//  RedeemPlusCodeView.swift
//  Stacked
//

import SwiftUI

struct RedeemPlusCodeView: View {
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var message: String?
    @State private var didSucceed = false

    var body: some View {
        Form {
            Section {
                TextField("Promo code", text: $code)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
            } footer: {
                Text("Redeem a Stacked + code for permanent complimentary access on this Apple Account. It does not share your library with anyone.")
            }

            Section {
                Button("Redeem") {
                    redeem()
                }
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(didSucceed ? StackedTheme.Text.secondary : StackedTheme.Semantic.destructive)
                }
            }
        }
        .navigationTitle("Redeem code")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func redeem() {
        switch subscriptions.redeemPromoCode(code) {
        case .unlocked:
            didSucceed = true
            message = "Stacked + is unlocked on this Apple Account."
            code = ""
        case .alreadyUnlocked:
            didSucceed = true
            message = "Stacked + is already unlocked on this Apple Account."
        case .invalid:
            didSucceed = false
            message = "That code isn’t valid. Check it and try again."
        }
    }
}
