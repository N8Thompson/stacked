//
//  RootView.swift
//  Stacked
//
//  iOS / iPadOS tab shell.
//

import SwiftUI

#if os(iOS)
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HouseholdSharingService.self) private var sharingService
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context

    @State private var showMergeOnJoin = false

    private var mainTabs: [AppTab] { AppTab.mainTabs }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(mainTabs) { tab in
                destination(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .onChange(of: sharingService.pendingMergeAfterJoin) { _, pending in
            if pending, householdManager.privateBookCount(in: context) > 0 {
                showMergeOnJoin = true
            }
        }
        .sheet(isPresented: $showMergeOnJoin) {
            MergeOnJoinSheet(bookCount: householdManager.privateBookCount(in: context))
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
