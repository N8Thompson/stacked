//
//  SettingsContent.swift
//  Stacked
//
//  Shared settings sections, state, CRUD, and presentation modifiers.
//

import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsContent: View {
    @Binding var editor: NameEditorTarget?
    @Binding var deleteRequest: TaxonomyDeleteRequest?
    @Binding var taxonomyError: String?
    @Binding var sheet: SettingsSheet?

    @Environment(\.managedObjectContext) private var context
    @Environment(AppSettings.self) private var appSettings
    @Environment(OrgManager.self) private var orgManager
    @Environment(CloudKitIdentityService.self) private var identity
    @Environment(OrgSharingService.self) private var sharingService
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var persistenceError: String?
    @State private var showDisconnectConfirm = false
    @State private var showReconnectOptions = false
    @State private var showLeaveAndKeepCopy = false
    @State private var isOpeningUserManagement = false

    private var locations: [StorageLocation] { orgManager.locations }
    private var formats: [ItemFormat] { orgManager.formats }
    private var bindings: [ItemBinding] { orgManager.bindings }
    private var org: Org? { orgManager.activeOrg }

    var body: some View {
        settingsSections
            .onAppear {
                guard let error = sharingService.lastSharingError else { return }
                persistenceError = error
                sharingService.lastSharingError = nil
            }
            .onChange(of: sharingService.lastSharingError) { _, error in
                guard let error else { return }
                persistenceError = error
                sharingService.lastSharingError = nil
            }
            .alert("Use only on this device?", isPresented: $showDisconnectConfirm) {
                Button("Keep a local copy") {
                    disconnectToLocal()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Future changes will stay on \(deviceName). Your iCloud copy is not deleted. Other devices will keep the last synced version until you reconnect.")
            }
            .alert("Reconnect iCloud?", isPresented: $showReconnectOptions) {
                Button("Merge this device into iCloud") {
                    reconnectMerging()
                }
                Button("Discard local changes and use iCloud", role: .destructive) {
                    reconnectDiscarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Merging adds this device's titles to iCloud. Matching ISBNs become extra copies.")
            }
            .alert("Leave and keep a copy?", isPresented: $showLeaveAndKeepCopy) {
                Button("Leave and keep a local copy", role: .destructive) {
                    leaveAndKeepLocalCopy()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You're viewing someone else's shared collection. Stacked will copy it to this device and then remove your access.")
            }
            .alert("Couldn't update library", isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )) {
                Button("OK", role: .cancel) { persistenceError = nil }
            } message: {
                Text(persistenceError ?? "")
            }
    }

    @ViewBuilder
    var settingsSections: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            subscriptionSection
            iCloudSection
            orgSection
            collectionSection
            costSection
            locationsSection
            formatsSection
            bindingsSection
            aboutSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #else
        subscriptionSection
        iCloudSection
        orgSection
        collectionSection
        costSection
        locationsSection
        formatsSection
        bindingsSection
        aboutSection
        #endif
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Stacked +",
            footer: plusFooter
        ) {
            settingsRow(title: "Status", value: plusStatusLabel)
            cardDivider()
            if subscriptions.hasStoreSubscription {
                cardButton(title: "Manage subscription", systemImage: "creditcard") {
                    openManageSubscriptions()
                }
                cardDivider()
            } else if !subscriptions.isPlus {
                cardButton(title: "Upgrade to Stacked +", systemImage: "star") {
                    presentPaywall("Stacked + unlocks unlimited titles, more locations, cost tracking, and collection sharing.")
                }
                cardDivider()
            }
            cardButton(title: "Redeem code", systemImage: "gift") {
                sheet = .redeemCode
            }
            cardDivider()
            cardButton(title: "Restore purchases", systemImage: "arrow.clockwise") {
                Task { await subscriptions.restore() }
            }
            #if DEBUG
            cardDivider()
            cardButton(
                title: subscriptions.isPlus ? "Simulate Free tier" : "Simulate Plus",
                systemImage: "ladybug"
            ) {
                subscriptions.setDebugPlus(!subscriptions.isPlus)
            }
            #endif
        }
        #else
        Section {
            LabeledContent("Status") {
                Text(plusStatusLabel)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
            if subscriptions.hasStoreSubscription {
                Button {
                    openManageSubscriptions()
                } label: {
                    Label("Manage subscription", systemImage: "creditcard")
                }
            } else if !subscriptions.isPlus {
                Button {
                    presentPaywall("Stacked + unlocks unlimited titles, more locations, cost tracking, and collection sharing.")
                } label: {
                    Label("Upgrade to Stacked +", systemImage: "star")
                }
            }
            Button {
                sheet = .redeemCode
            } label: {
                Label("Redeem code", systemImage: "gift")
            }
            Button {
                Task { await subscriptions.restore() }
            } label: {
                Label("Restore purchases", systemImage: "arrow.clockwise")
            }
            #if DEBUG
            Button {
                subscriptions.setDebugPlus(!subscriptions.isPlus)
            } label: {
                Label(
                    subscriptions.isPlus ? "Simulate Free tier" : "Simulate Plus",
                    systemImage: "ladybug"
                )
            }
            #endif
        } header: {
            Text("Stacked +")
        } footer: {
            Text(plusFooter)
        }
        #endif
    }

    @ViewBuilder
    private var iCloudSection: some View {
        #if os(macOS)
        settingsCard(
            title: "iCloud",
            footer: iCloudFooter
        ) {
            settingsRow(
                title: "Account",
                value: identity.isSignedIn ? "Signed in" : "Not signed in"
            )
            cardDivider()
            settingsRow(title: "Library", value: libraryLocationLabel)
            switch disconnectKind {
            case .disconnectToLocal:
                cardDivider()
                cardButton(title: "Use only on this device", systemImage: "externaldrive") {
                    showDisconnectConfirm = true
                }
            case .leaveAndKeepLocalCopy:
                cardDivider()
                cardButton(title: "Leave and keep a local copy", systemImage: "rectangle.portrait.and.arrow.right") {
                    showLeaveAndKeepCopy = true
                }
            case .reconnect:
                cardDivider()
                cardButton(title: "Reconnect iCloud", systemImage: "icloud") {
                    showReconnectOptions = true
                }
            case .notAvailable:
                EmptyView()
            }
        }
        #else
        Section {
            LabeledContent("Account") {
                Text(identity.isSignedIn ? "Signed in" : "Not signed in")
                    .foregroundStyle(identity.isSignedIn ? StackedTheme.Text.secondary : StackedTheme.Semantic.destructive)
            }
            LabeledContent("Library") {
                Text(libraryLocationLabel)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
            switch disconnectKind {
            case .disconnectToLocal:
                Button("Use only on this device") {
                    showDisconnectConfirm = true
                }
            case .leaveAndKeepLocalCopy:
                Button("Leave and keep a local copy") {
                    showLeaveAndKeepCopy = true
                }
            case .reconnect:
                Button("Reconnect iCloud") {
                    showReconnectOptions = true
                }
            case .notAvailable:
                EmptyView()
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(iCloudFooter)
        }
        #endif
    }

    @ViewBuilder
    private var orgSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Users",
            footer: userManagementFooter
        ) {
            if isOpeningUserManagement {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Opening user management…")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                cardButton(title: "User management", systemImage: "person.2") {
                    Task { await openUserManagement() }
                }
            }
            if sharingService.pendingMergeAfterJoin {
                cardDivider()
                cardButton(title: "Add my books to shared collection", systemImage: "square.and.arrow.down.on.square") {
                    contributePrivateLibrary()
                }
            }
        }
        #else
        Section {
            Button {
                Task { await openUserManagement() }
            } label: {
                if isOpeningUserManagement {
                    HStack {
                        ProgressView()
                        Text("Opening user management…")
                    }
                } else {
                    Label("User management", systemImage: "person.2")
                }
            }
            .disabled(isOpeningUserManagement)
            if sharingService.pendingMergeAfterJoin {
                Button("Add my books to shared collection") {
                    contributePrivateLibrary()
                }
            }
        } header: {
            Text("Users")
        } footer: {
            Text(userManagementFooter)
        }
        #endif
    }

    @ViewBuilder
    private var collectionSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Collection",
            footer: "Send a Stacked backup, import one, or export a CSV. Live sharing is in User management."
        ) {
            cardButton(title: "Move or share collection", systemImage: "square.and.arrow.up.on.square") {
                sheet = .assistant
            }
        }
        #else
        Section {
            Button {
                sheet = .assistant
            } label: {
                Label("Move or share collection", systemImage: "square.and.arrow.up.on.square")
            }
        } header: {
            Text("Collection")
        } footer: {
            Text("Send a Stacked backup, import one, or export a CSV. Live sharing is in User management.")
        }
        #endif
    }

    @ViewBuilder
    private var costSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Cost",
            footer: costFooter
        ) {
            if subscriptions.currentOrgHasPlusAccess {
                Toggle(
                    "Track item costs",
                    isOn: Binding(
                        get: { appSettings.costTrackingPreference },
                        set: { appSettings.costTrackingPreference = $0 }
                    )
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if appSettings.showCostTracking {
                    cardDivider()
                    cardButton(title: "Cost information", systemImage: "dollarsign.circle") {
                        sheet = .cost
                    }
                }
            } else {
                cardButton(title: "Unlock cost tracking", systemImage: "lock") {
                    presentPaywall("Stacked + unlocks unlimited titles, more locations, cost tracking, and collection sharing.")
                }
            }
        }
        #else
        Section {
            if subscriptions.currentOrgHasPlusAccess {
                Toggle(
                    "Track item costs",
                    isOn: Binding(
                        get: { appSettings.costTrackingPreference },
                        set: { appSettings.costTrackingPreference = $0 }
                    )
                )
                if appSettings.showCostTracking {
                    Button {
                        sheet = .cost
                    } label: {
                        Label("Cost information", systemImage: "dollarsign.circle")
                    }
                }
            } else {
                Button {
                    presentPaywall("Cost tracking is included with Stacked +.")
                } label: {
                    Label("Unlock cost tracking", systemImage: "lock")
                }
            }
        } header: {
            Text("Cost")
        } footer: {
            Text(costFooter)
        }
        #endif
    }

    @ViewBuilder
    private var locationsSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Locations",
            footer: "Where items are stored (e.g. Home Library, Office)."
        ) {
            ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                if index > 0 { cardDivider() }
                taxonomyRow(
                    name: location.name,
                    isDefault: location.isDefault,
                    iconName: location.displayIconName,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameLocation(location) },
                    onMakeDefault: location.isDefault ? nil : { makeDefaultLocation(location) },
                    onDelete: locations.count > 1 ? { requestDeleteLocation(location) } : nil
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            if subscriptions.canContributeToCurrentOrg {
                cardDivider()
                cardButton(title: "Add location", systemImage: "plus") {
                    requestAddLocation()
                }
            }
        }
        #else
        Section {
            ForEach(locations) { location in
                taxonomyRow(
                    name: location.name,
                    isDefault: location.isDefault,
                    iconName: location.displayIconName,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameLocation(location) },
                    onMakeDefault: location.isDefault ? nil : { makeDefaultLocation(location) },
                    onDelete: locations.count > 1 ? { requestDeleteLocation(location) } : nil
                )
            }
            if subscriptions.canContributeToCurrentOrg {
                Button { requestAddLocation() } label: {
                    Label("Add location", systemImage: "plus")
                }
            }
        } header: {
            Text("Locations")
        } footer: {
            Text("Where items are stored (e.g. Home Library, Office).")
        }
        #endif
    }

    @ViewBuilder
    private var formatsSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Formats",
            footer: "The kind of item (e.g. Books, Journals)."
        ) {
            ForEach(Array(formats.enumerated()), id: \.element.id) { index, format in
                if index > 0 { cardDivider() }
                taxonomyRow(
                    name: format.name,
                    isDefault: format.isDefault,
                    iconName: format.displayIconName,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameFormat(format) },
                    onMakeDefault: format.isDefault ? nil : { makeDefaultFormat(format) },
                    onDelete: { requestDeleteFormat(format) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            if subscriptions.canContributeToCurrentOrg {
                cardDivider()
                cardButton(title: "Add format", systemImage: "plus") {
                    requestAddFormat()
                }
            }
        }
        #else
        Section {
            ForEach(formats) { format in
                taxonomyRow(
                    name: format.name,
                    isDefault: format.isDefault,
                    iconName: format.displayIconName,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameFormat(format) },
                    onMakeDefault: format.isDefault ? nil : { makeDefaultFormat(format) },
                    onDelete: { requestDeleteFormat(format) }
                )
            }
            if subscriptions.canContributeToCurrentOrg {
                Button { requestAddFormat() } label: {
                    Label("Add format", systemImage: "plus")
                }
            }
        } header: {
            Text("Formats")
        } footer: {
            Text("The kind of item (e.g. Books, Journals).")
        }
        #endif
    }

    @ViewBuilder
    private var bindingsSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Bindings",
            footer: "Physical edition (e.g. Paperback, Hardcover, Spiral)."
        ) {
            ForEach(Array(bindings.enumerated()), id: \.element.id) { index, binding in
                if index > 0 { cardDivider() }
                taxonomyRow(
                    name: binding.name,
                    isDefault: binding.isDefault,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameBinding(binding) },
                    onMakeDefault: binding.isDefault ? nil : { makeDefaultBinding(binding) },
                    onDelete: { requestDeleteBinding(binding) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            if subscriptions.canContributeToCurrentOrg {
                cardDivider()
                cardButton(title: "Add binding", systemImage: "plus") {
                    requestAddBinding()
                }
            }
        }
        #else
        Section {
            ForEach(bindings) { binding in
                taxonomyRow(
                    name: binding.name,
                    isDefault: binding.isDefault,
                    canEdit: subscriptions.canContributeToCurrentOrg,
                    onRename: { editor = renameBinding(binding) },
                    onMakeDefault: binding.isDefault ? nil : { makeDefaultBinding(binding) },
                    onDelete: { requestDeleteBinding(binding) }
                )
            }
            if subscriptions.canContributeToCurrentOrg {
                Button { requestAddBinding() } label: {
                    Label("Add binding", systemImage: "plus")
                }
            }
        } header: {
            Text("Bindings")
        } footer: {
            Text("Physical edition (e.g. Paperback, Hardcover, Spiral).")
        }
        #endif
    }

    @ViewBuilder
    private var aboutSection: some View {
        #if os(macOS)
        settingsCard(title: "About") {
            cardButton(title: "FAQs", systemImage: "questionmark.circle") {
                sheet = .faqs
            }
        }
        #else
        Section {
            Button {
                sheet = .faqs
            } label: {
                Label("FAQs", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
        }
        #endif
    }

    @ViewBuilder
    private func taxonomyRow(
        name: String,
        isDefault: Bool,
        iconName: String? = nil,
        canEdit: Bool = true,
        onRename: @escaping () -> Void,
        onMakeDefault: (() -> Void)?,
        onDelete: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            if let iconName {
                Image(systemName: iconName)
                    .frame(width: 22)
                    .foregroundStyle(StackedTheme.accent)
            }

            if canEdit {
                Button(action: onRename) {
                    taxonomyRowLabel(name: name, isDefault: isDefault)
                }
                .buttonStyle(.plain)
            } else {
                taxonomyRowLabel(name: name, isDefault: isDefault)
            }

            if canEdit {
                Menu {
                    Button(iconName == nil ? "Rename" : "Edit", action: onRename)
                    if let onMakeDefault {
                        Button("Make Default", action: onMakeDefault)
                    }
                    if let onDelete {
                        Button("Delete", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(StackedTheme.Text.secondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            if canEdit, let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .swipeActions(edge: .leading) {
            if canEdit, let onMakeDefault {
                Button("Default", action: onMakeDefault).tint(StackedTheme.accent)
            }
        }
        #endif
    }

    private func taxonomyRowLabel(name: String, isDefault: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .foregroundStyle(StackedTheme.Text.primary)
            if isDefault {
                Text("Default")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(StackedTheme.accentMuted))
                    .foregroundStyle(StackedTheme.accent)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    #if os(macOS)
    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(StackedTheme.Text.primary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(StackedTheme.Text.tertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stackedCardStyle(cornerRadius: 12)
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(StackedTheme.Text.primary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(StackedTheme.Text.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func cardButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func cardDivider() -> some View {
        Divider()
            .overlay(StackedTheme.Border.subtle)
            .padding(.leading, 14)
    }
    #endif

    private var deviceName: String {
        #if os(macOS)
        "this Mac"
        #else
        "this iPhone"
        #endif
    }

    private var libraryLocationLabel: String {
        if PersistenceController.shared.mode == .local {
            #if os(macOS)
            return "This Mac"
            #else
            return "This iPhone"
            #endif
        }
        return "iCloud"
    }

    private var disconnectKind: PersistenceSwitchPolicy.DisconnectKind {
        PersistenceSwitchPolicy.disconnectKind(
            mode: PersistenceController.shared.mode,
            role: sharingService.currentRole,
            usesCloudKit: PersistenceController.shared.usesCloudKit
        )
    }

    private var iCloudFooter: String {
        switch disconnectKind {
        case .reconnect:
            return "\(libraryLocationLabel) has a local copy. iCloud is not being updated. Reconnect to merge this device into iCloud, or discard local changes and use iCloud."
        case .leaveAndKeepLocalCopy:
            return "You're viewing someone else's shared collection. Leave and keep a local copy if you want the titles on \(deviceName). Leaving removes your access; the owner's collection stays."
        case .disconnectToLocal:
            return "Your library lives in iCloud and syncs to your other devices. Use only on this device keeps a copy here without deleting iCloud."
        case .notAvailable:
            #if os(macOS)
            return "Sign in under System Settings → Apple Account to back up and share."
            #else
            return "Sign in under Settings → Apple ID to back up and share."
            #endif
        }
    }

    private var plusStatusLabel: String {
        #if DEBUG
        if subscriptions.hasDebugPlusOverride {
            return subscriptions.isPlus ? "Subscribed (simulated)" : "Free (simulated)"
        }
        #endif
        if subscriptions.hasComplimentaryPlus {
            return "Complimentary"
        }
        return subscriptions.isPlus ? "Subscribed" : "Free"
    }

    private var plusFooter: String {
        let status: String
        if subscriptions.hasComplimentaryPlus {
            status = "Stacked + is unlocked with a complimentary code on this Apple Account and works on iPhone and Mac."
        } else if subscriptions.isPlus {
            status = "Stacked + is active on this Apple Account and works on iPhone and Mac."
        } else {
            status = "Free libraries include \(EntitlementPolicy.freeUniqueTitleLimit) unique titles and \(EntitlementPolicy.freeLocationLimit) locations. Existing titles stay if a subscription ends."
        }
        #if DEBUG
        return status + " Simulate Plus is a debug control and overrides App Store status on this device."
        #else
        return status
        #endif
    }

    private var costFooter: String {
        if subscriptions.currentOrgHasPlusAccess {
            return "Show costs associated with your collection in the library and on Cost information."
        }
        return "Cost tracking is included with Stacked +. Your existing prices are kept and never deleted."
    }

    private var userManagementFooter: String {
        if sharingService.currentRole == .participant,
           !subscriptions.currentOrgHasPlusAccess {
            return "This collection is read-only because the owner's Stacked + access is not active."
        }
        if sharingService.currentRole == .owner,
           !subscriptions.isPlus {
            return "Participants become read-only while the owner's Stacked + access is inactive. Existing users and data are kept."
        }
        return "The owner's Stacked + access covers every participant. All users can view costs and contribute; only the owner can manage access."
    }

    private func presentPaywall(_ reason: String) {
        sheet = .paywall(reason)
    }

    private func requireContributionAccess() -> Bool {
        guard subscriptions.canContributeToCurrentOrg else {
            persistenceError = "This collection is read-only while the owner's Stacked + access is inactive."
            return false
        }
        return true
    }

    private func requestAddLocation() {
        guard subscriptions.canContributeToCurrentOrg else {
            persistenceError = "The collection owner's Stacked + access must be active before participants can add locations."
            return
        }
        if EntitlementPolicy.canAddLocation(
            isPlus: subscriptions.currentOrgHasPlusAccess,
            currentLocations: locations.count
        ) {
            editor = addLocation()
        } else {
            presentPaywall("The free library includes \(EntitlementPolicy.freeLocationLimit) locations. Upgrade to add more. Your existing locations stay.")
        }
    }

    private func requestAddFormat() {
        guard subscriptions.canContributeToCurrentOrg else {
            persistenceError = "The collection owner's Stacked + access must be active before participants can add formats."
            return
        }
        editor = addFormat()
    }

    private func requestAddBinding() {
        guard subscriptions.canContributeToCurrentOrg else {
            persistenceError = "The collection owner's Stacked + access must be active before participants can add bindings."
            return
        }
        editor = addBinding()
    }

    private func openManageSubscriptions() {
        #if os(iOS)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func contributePrivateLibrary() {
        guard let org,
              let source = orgManager.privateLibraryCollection(in: context) else { return }
        do {
            try CollectionMergeService.mergePrivateIntoOrg(
                source: source,
                targetOrg: org,
                in: context,
                hasPlusAccess: subscriptions.currentOrgHasPlusAccess,
                canContribute: subscriptions.canContributeToCurrentOrg
            )
            sharingService.pendingMergeAfterJoin = false
            orgManager.refresh(in: context)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func openUserManagement() async {
        guard !isOpeningUserManagement, let org else { return }
        isOpeningUserManagement = true
        defer { isOpeningUserManagement = false }

        do {
            let presented = try await sharingService.presentUserManagement(
                for: org,
                isPlus: subscriptions.isPlus
            )
            if !presented {
                presentPaywall("Sharing a collection with other users is included with Stacked +.")
            }
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func disconnectToLocal() {
        Task {
            do {
                try await PersistenceSwitchService.copyActiveLibraryToLocalStore()
            } catch {
                persistenceError = error.localizedDescription
            }
        }
    }

    private func reconnectMerging() {
        Task {
            do {
                try await PersistenceSwitchService.mergeLocalLibraryIntoiCloud()
            } catch {
                persistenceError = error.localizedDescription
            }
        }
    }

    private func reconnectDiscarding() {
        Task {
            await PersistenceSwitchService.discardLocalAndUseiCloud()
        }
    }

    private func leaveAndKeepLocalCopy() {
        Task {
            do {
                guard let org else { return }
                try await PersistenceSwitchService.leaveShareAndKeepLocalCopy(org)
            } catch {
                persistenceError = error.localizedDescription
            }
        }
    }

    private func addLocation() -> NameEditorTarget {
        NameEditorTarget(
            title: "New Location",
            initialName: "",
            initialIconName: "books.vertical.fill",
            iconCategories: LocationIconCatalog.categories
        ) { name, iconName in
            guard requireContributionAccess() else { return }
            guard let org else { return }
            let isFirst = locations.isEmpty
            _ = StorageLocation.create(
                in: context,
                org: org,
                name: name,
                isDefault: isFirst,
                iconName: iconName
            )
            PersistenceController.shared.save()
        }
    }

    private func renameLocation(_ location: StorageLocation) -> NameEditorTarget {
        NameEditorTarget(
            title: "Edit Location",
            initialName: location.name,
            initialIconName: location.displayIconName,
            iconCategories: LocationIconCatalog.categories
        ) { name, iconName in
            guard requireContributionAccess() else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            location.name = trimmed
            location.iconName = iconName
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultLocation(_ location: StorageLocation) {
        guard requireContributionAccess() else { return }
        for other in locations { other.isDefault = false }
        location.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteLocation(_ location: StorageLocation) {
        guard requireContributionAccess() else { return }
        guard locations.count > 1 else { return }
        if location.titleCount > 0 {
            deleteRequest = TaxonomyDeleteRequest(target: .location(location))
        } else {
            deleteUnused(location)
        }
    }

    private func deleteUnused(_ location: StorageLocation) {
        guard requireContributionAccess() else { return }
        let wasDefault = location.isDefault
        context.delete(location)
        if wasDefault, let next = locations.first(where: { $0.id != location.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }

    private func renameFormat(_ format: ItemFormat) -> NameEditorTarget {
        NameEditorTarget(
            title: "Edit Format",
            initialName: format.name,
            initialIconName: format.displayIconName,
            iconCategories: FormatIconCatalog.categories
        ) { name, iconName in
            guard requireContributionAccess() else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            format.name = trimmed
            format.iconName = iconName
            PersistenceController.shared.save()
        }
    }

    private func addFormat() -> NameEditorTarget {
        NameEditorTarget(
            title: "New Format",
            initialName: "",
            initialIconName: "square.stack.3d.up.fill",
            iconCategories: FormatIconCatalog.categories
        ) { name, iconName in
            guard requireContributionAccess() else { return }
            guard let org else { return }
            let isFirst = formats.isEmpty
            _ = ItemFormat.create(
                in: context,
                org: org,
                name: name,
                isDefault: isFirst,
                iconName: iconName
            )
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultFormat(_ format: ItemFormat) {
        guard requireContributionAccess() else { return }
        for other in formats { other.isDefault = false }
        format.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteFormat(_ format: ItemFormat) {
        guard requireContributionAccess() else { return }
        if format.titleCount > 0 {
            guard formats.count > 1 else {
                taxonomyError = "Add another format before deleting the only one in use."
                return
            }
            deleteRequest = TaxonomyDeleteRequest(target: .format(format))
        } else {
            deleteUnused(format)
        }
    }

    private func deleteUnused(_ format: ItemFormat) {
        guard requireContributionAccess() else { return }
        let wasDefault = format.isDefault
        context.delete(format)
        if wasDefault, let next = formats.first(where: { $0.id != format.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }

    private func addBinding() -> NameEditorTarget {
        NameEditorTarget(title: "New Binding", initialName: "") { name in
            guard requireContributionAccess() else { return }
            guard let org else { return }
            let isFirst = bindings.isEmpty
            _ = ItemBinding.create(in: context, org: org, name: name, isDefault: isFirst)
            PersistenceController.shared.save()
        }
    }

    private func renameBinding(_ binding: ItemBinding) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Binding", initialName: binding.name) { name in
            guard requireContributionAccess() else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            binding.name = trimmed
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultBinding(_ binding: ItemBinding) {
        guard requireContributionAccess() else { return }
        for other in bindings { other.isDefault = false }
        binding.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteBinding(_ binding: ItemBinding) {
        guard requireContributionAccess() else { return }
        if binding.titleCount > 0 {
            deleteRequest = TaxonomyDeleteRequest(target: .binding(binding))
        } else {
            deleteUnused(binding)
        }
    }

    private func deleteUnused(_ binding: ItemBinding) {
        guard requireContributionAccess() else { return }
        let wasDefault = binding.isDefault
        context.delete(binding)
        if wasDefault, let next = bindings.first(where: { $0.id != binding.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }
}
