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
    @Environment(OrgSharingService.self) private var sharingService
    @Environment(OrgManager.self) private var orgManager
    @Environment(\.managedObjectContext) private var context

    @State private var showMergeOnJoin = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                destination(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .onChange(of: sharingService.pendingMergeAfterJoin) { _, pending in
            if pending, orgManager.privateBookCount(in: context) > 0 {
                showMergeOnJoin = true
            }
        }
        .onAppear {
            if sharingService.pendingMergeAfterJoin, orgManager.privateBookCount(in: context) > 0 {
                showMergeOnJoin = true
            }
        }
        .sheet(isPresented: $showMergeOnJoin) {
            MergeOnJoinSheet(bookCount: orgManager.privateBookCount(in: context))
        }
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .manage: ManageView()
        case .settings: SettingsView()
        }
    }
}
#endif
