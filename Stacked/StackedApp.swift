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
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(CloudKitSharingAppDelegate.self) private var appDelegate
    #endif

    @State private var router = AppRouter()
    @State private var appSettings = AppSettings()
    @State private var subscriptions = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            iOSAppRoot()
                .environment(router)
                .environment(appSettings)
                .environment(subscriptions)
            #else
            macOSAppRoot()
                .environment(router)
                .environment(appSettings)
                .environment(subscriptions)
            #endif
        }
    }
}

#if os(iOS)
private struct iOSAppRoot: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var appSettings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase

    @State private var bootstrap: AppBootstrap?

    var body: some View {
        Group {
            if let bootstrap {
                RootView()
                    .environment(\.managedObjectContext, bootstrap.persistence.viewContext)
                    .environment(bootstrap.identity)
                    .environment(bootstrap.orgManager)
                    .environment(bootstrap.sharingService)
                    .stackedScreenBackground()
            } else {
                launchPlaceholder
            }
        }
        .environment(router)
        .environment(appSettings)
        .environment(subscriptions)
        .tint(StackedTheme.accent)
        .task {
            await subscriptions.load()
            guard bootstrap == nil else { return }
            bootstrap = await AppBootstrap.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stackedPersistenceDidReload)) { _ in
            Task {
                bootstrap = nil
                bootstrap = await AppBootstrap.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await subscriptions.refreshEntitlements()
                await AppBootstrap.refreshAfterForeground(bootstrap: bootstrap)
            }
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
#endif

#if os(macOS)
private struct macOSAppRoot: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var appSettings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase

    @State private var bootstrap: AppBootstrap?

    var body: some View {
        Group {
            if let bootstrap {
                RootView()
                    .environment(\.managedObjectContext, bootstrap.persistence.viewContext)
                    .environment(bootstrap.identity)
                    .environment(bootstrap.orgManager)
                    .environment(bootstrap.sharingService)
                    .stackedScreenBackground()
            } else {
                launchPlaceholder
            }
        }
        .environment(router)
        .environment(appSettings)
        .environment(subscriptions)
        .tint(StackedTheme.accent)
        .task {
            await subscriptions.load()
            guard bootstrap == nil else { return }
            bootstrap = await AppBootstrap.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stackedPersistenceDidReload)) { _ in
            Task {
                bootstrap = nil
                bootstrap = await AppBootstrap.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await subscriptions.refreshEntitlements()
                await AppBootstrap.refreshAfterForeground(bootstrap: bootstrap)
            }
        }
    }

    private var launchPlaceholder: some View {
        ZStack {
            StackedTheme.Background.primary
            StackedTheme.Gradient.backdrop(for: colorScheme)
            ProgressView()
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}
#endif

@MainActor
private struct AppBootstrap {
    let persistence: PersistenceController
    let identity: CloudKitIdentityService
    let orgManager: OrgManager
    let sharingService: OrgSharingService

    static func load() async -> AppBootstrap {
        let persistence = PersistenceController.shared
        await persistence.waitUntilStoresAreLoaded()
        await persistence.waitForInitialCloudKitImport()

        let orgManager = OrgManager.shared
        orgManager.startObservingIfNeeded()
        orgManager.refresh(in: persistence.viewContext)

        let identity = CloudKitIdentityService.shared
        await identity.refresh()
        SeedData.seedIfNeeded(persistence.viewContext)
        orgManager.refresh(in: persistence.viewContext)

        let sharingService = OrgSharingService.shared
        await sharingService.refreshRole(for: orgManager.activeOrg)

        return AppBootstrap(
            persistence: persistence,
            identity: identity,
            orgManager: orgManager,
            sharingService: sharingService
        )
    }

    static func refreshAfterForeground(bootstrap: AppBootstrap?) async {
        await CloudKitIdentityService.shared.refresh()
        guard let bootstrap else { return }
        bootstrap.orgManager.refresh(in: bootstrap.persistence.viewContext)
        bootstrap.orgManager.bumpLibraryRevision()
        await bootstrap.sharingService.refreshRole(for: bootstrap.orgManager.activeOrg)
    }
}
