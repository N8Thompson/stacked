//
//  RootView.swift
//  Stacked
//
//  Adaptive shell: a TabView on iOS, a NavigationSplitView sidebar on macOS.
//

import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    private var mainTabs: [AppTab] {
        AppTab.mainTabs
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        tabBody
        #endif
    }

    // MARK: iOS / iPadOS

    private var tabBody: some View {
        @Bindable var router = router
        return TabView(selection: $router.selectedTab) {
            ForEach(mainTabs) { tab in
                destination(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
    }

    // MARK: macOS

    #if os(macOS)
    private var macBody: some View {
        @Bindable var router = router
        return NavigationSplitView {
            List(mainTabs, selection: Binding(
                get: { router.selectedTab },
                set: { if let value = $0 { router.selectedTab = value } }
            )) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .navigationTitle("Stacked")
        } detail: {
            destination(for: router.selectedTab)
                .frame(minWidth: 520, minHeight: 480)
        }
    }
    #endif

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
