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
    @Environment(OrgSharingService.self) private var sharingService
    @Environment(OrgManager.self) private var orgManager
    @Environment(\.managedObjectContext) private var context

    @State private var showMergeOnJoin = false

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            VStack(spacing: 0) {
                List(AppTab.allCases, selection: Binding(
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
                .frame(minWidth: 440, minHeight: 340)
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
