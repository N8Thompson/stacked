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

    var id: String {
        switch self {
        case .assistant: return "assistant"
        case .paywall: return "paywall"
        case .faqs: return "faqs"
        case .cost: return "cost"
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
            case .cost:
                NavigationStack {
                    CostSheet()
                }
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
