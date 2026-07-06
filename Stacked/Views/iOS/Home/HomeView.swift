//
//  HomeView.swift
//  Stacked
//
//  iOS home with iCloud sign-in banner.
//

import SwiftUI

#if os(iOS)
struct HomeView: View {
    @Environment(CloudKitIdentityService.self) private var identity

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                HomeScreen {
                    if !identity.isSignedIn {
                        iCloudBanner
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: { Label("Add", systemImage: "plus") }
                    }
                }
                .addBookSheet(isPresented: $showAddSheet, preselection: AddPreselection())
            }
            .stackedScreenBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var iCloudBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3)
                .foregroundStyle(StackedTheme.Semantic.star)
            VStack(alignment: .leading, spacing: 4) {
                Text("Not signed in to iCloud")
                    .font(.subheadline.weight(.semibold))
                Text("Sign in under Settings → Apple ID to sync your library and share with your household.")
                    .font(.caption)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .stackedCardStyle(cornerRadius: 12)
    }
}
#endif
