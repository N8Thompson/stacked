//
//  StackedApp.swift
//  Stacked
//
//  Created by Nate Thompson on 7/3/26.
//

import SwiftUI
import SwiftData

@main
struct StackedApp: App {
    @State private var router = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            StorageLocation.self,
            ItemFormat.self,
        ])
        // CloudKit sync is iOS-only; personal dev teams can't use iCloud on macOS.
        #if os(iOS)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        #else
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        #endif

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .task {
                    SeedData.seedIfNeeded(sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
