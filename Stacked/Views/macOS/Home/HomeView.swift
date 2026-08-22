//
//  HomeView.swift
//  Stacked
//
//  macOS home without iCloud banner.
//

import SwiftUI

#if os(macOS)
struct HomeView: View {
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            HomeScreen {
                CollectionAccessBanner()
            }
                .toolbar {
                    if subscriptions.canContributeToCurrentOrg {
                        ToolbarItem(placement: .primaryAction) {
                            Button { showAddSheet = true } label: { Label("Add", systemImage: "plus") }
                        }
                    }
                }
                .addBookSheet(isPresented: $showAddSheet, preselection: AddPreselection())
        }
    }
}
#endif
