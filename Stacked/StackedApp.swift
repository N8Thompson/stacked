//
//  StackedApp.swift
//  Stacked
//

import SwiftUI
import CoreData

@main
struct StackedApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(CloudKitSharingAppDelegate.self) private var appDelegate
    #endif

    @State private var router = AppRouter()
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            iOSAppRoot()
                .environment(router)
                .environment(appSettings)
            #else
            macOSAppRoot()
                .environment(router)
                .environment(appSettings)
            #endif
        }
    }
}

#if os(iOS)
private struct iOSAppRoot: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var bootstrap: iOSAppBootstrap?

    var body: some View {
        Group {
            if let bootstrap {
                RootView()
                    .environment(\.managedObjectContext, bootstrap.persistence.viewContext)
                    .environment(bootstrap.identity)
                    .environment(bootstrap.householdManager)
                    .environment(bootstrap.sharingService)
                    .stackedScreenBackground()
            } else {
                launchPlaceholder
            }
        }
        .environment(router)
        .environment(appSettings)
        .tint(StackedTheme.accent)
        .task {
            guard bootstrap == nil else { return }
            bootstrap = await iOSAppBootstrap.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await iOSAppBootstrap.refreshAfterForeground(bootstrap: bootstrap) }
        }
    }

    private var launchPlaceholder: some View {
        ZStack {
            StackedTheme.Background.primary
            StackedTheme.Gradient.backdrop(for: colorScheme)
            ProgressView()
        }
        .ignoresSafeArea()
    }

    @Environment(\.colorScheme) private var colorScheme
}

@MainActor
private struct iOSAppBootstrap {
    let persistence: PersistenceController
    let identity: CloudKitIdentityService
    let householdManager: HouseholdManager
    let sharingService: HouseholdSharingService

    static func load() async -> iOSAppBootstrap {
        let persistence = PersistenceController.shared
        await persistence.waitUntilStoresAreLoaded()
        #if os(iOS)
        await persistence.waitForInitialCloudKitImport()
        #endif

        let householdManager = HouseholdManager.shared
        householdManager.startObservingIfNeeded()
        householdManager.refresh(in: persistence.viewContext)

        let identity = CloudKitIdentityService.shared
        await identity.refresh()
        SeedData.seedIfNeeded(persistence.viewContext)
        householdManager.refresh(in: persistence.viewContext)

        return iOSAppBootstrap(
            persistence: persistence,
            identity: identity,
            householdManager: householdManager,
            sharingService: HouseholdSharingService.shared
        )
    }

    static func refreshAfterForeground(bootstrap: iOSAppBootstrap?) async {
        await CloudKitIdentityService.shared.refresh()
        guard let bootstrap else { return }
        bootstrap.householdManager.refresh(in: bootstrap.persistence.viewContext)
        bootstrap.householdManager.bumpLibraryRevision()
    }
}
#endif

#if os(macOS)
private struct macOSAppRoot: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var appSettings

    @State private var persistence = PersistenceController.shared
    @State private var identity = CloudKitIdentityService.shared
    @State private var householdManager = HouseholdManager.shared
    @State private var sharingService = HouseholdSharingService.shared

    var body: some View {
        RootView()
            .environment(router)
            .environment(appSettings)
            .environment(\.managedObjectContext, persistence.viewContext)
            .environment(identity)
            .environment(householdManager)
            .environment(sharingService)
            .tint(StackedTheme.accent)
            .stackedScreenBackground()
            .task {
                await persistence.waitUntilStoresAreLoaded()
                householdManager.startObservingIfNeeded()
                householdManager.refresh(in: persistence.viewContext)
                SeedData.seedIfNeeded(persistence.viewContext)
            }
    }
}
#endif
