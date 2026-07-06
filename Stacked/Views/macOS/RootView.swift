//
//  RootView.swift
//  Stacked
//
//  macOS NavigationSplitView shell.
//

import SwiftUI

#if os(macOS)
struct RootView: View {
    @Environment(AppRouter.self) private var router

    private var mainTabs: [AppTab] { AppTab.mainTabs }

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            VStack(spacing: 0) {
                List(mainTabs, selection: Binding(
                    get: { router.selectedTab },
                    set: { if let value = $0 { router.selectedTab = value } }
                )) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
                .navigationTitle("Stacked")

                Spacer(minLength: 0)

                CollectionSummaryStats(style: .sidebar)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        } detail: {
            destination(for: router.selectedTab)
                .frame(minWidth: 520, minHeight: 480)
        }
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .manage: ManageView()
        case .cost: CostView()
        case .settings: SettingsView()
        }
    }
}
#endif
