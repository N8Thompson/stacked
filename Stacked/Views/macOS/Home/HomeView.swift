//
//  HomeView.swift
//  Stacked
//
//  macOS home without iCloud banner.
//

import SwiftUI

#if os(macOS)
struct HomeView: View {
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            HomeScreen()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: { Label("Add", systemImage: "plus") }
                    }
                }
                .addBookSheet(isPresented: $showAddSheet, preselection: AddPreselection())
        }
    }
}
#endif
