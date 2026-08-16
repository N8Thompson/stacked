//
//  SettingsSheet.swift
//  Stacked
//

import SwiftUI

enum SettingsSheet: Identifiable {
    case assistant
    case paywall(String)
    case faqs
    case cost
    case redeemCode

    var id: String {
        switch self {
        case .assistant: return "assistant"
        case .paywall: return "paywall"
        case .faqs: return "faqs"
        case .cost: return "cost"
        case .redeemCode: return "redeemCode"
        }
    }
}

extension View {
    func settingsDestinationSheets(_ sheet: Binding<SettingsSheet?>) -> some View {
        self.sheet(item: sheet) { item in
            switch item {
            case .assistant:
                CollectionAssistantSheet()
            case .paywall(let reason):
                PaywallView(reason: reason)
            case .faqs:
                NavigationStack {
                    FAQView()
                }
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 560)
                #endif
            case .cost:
                NavigationStack {
                    CostSheet()
                }
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 420)
                #endif
            case .redeemCode:
                NavigationStack {
                    RedeemPlusCodeView()
                }
                #if os(macOS)
                .frame(minWidth: 360, minHeight: 280)
                #endif
            }
        }
    }
}

private struct CostSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CostView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }
}
