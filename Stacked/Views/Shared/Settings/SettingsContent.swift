//
//  SettingsContent.swift
//  Stacked
//
//  Shared settings sections, state, CRUD, and presentation modifiers.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import CloudKit

struct SettingsContent: View {
    @Binding var editor: NameEditorTarget?
    @Binding var deleteRequest: TaxonomyDeleteRequest?
    @Binding var taxonomyError: String?

    @Environment(\.managedObjectContext) private var context
    @Environment(AppSettings.self) private var appSettings
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(CloudKitIdentityService.self) private var identity
    @Environment(HouseholdSharingService.self) private var sharingService

    @State private var showSharing = false
    @State private var share: CKShare?
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var showImporter = false
    @State private var migrationPreview: MigrationPreview?
    @State private var migrationError: String?
    @State private var showExportBeforeLeave = false
    @State private var isSharedParticipant = false

    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }
    private var bindings: [ItemBinding] { householdManager.bindings }
    private var household: Household? { householdManager.activeHousehold }

    var body: some View {
        settingsSections
            .sheet(isPresented: $showSharing) {
                #if os(iOS)
                if let share {
                    HouseholdCloudSharingView(
                        share: share,
                        container: CKContainer(identifier: PersistenceController.cloudKitContainerID)
                    )
                }
                #endif
            }
            .sheet(isPresented: $showExportShare) {
                if let exportURL {
                    ExportShareSheet(items: [exportURL])
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, LibraryMigrationService.exportType],
                allowsMultipleSelection: false
            ) { result in
                handleImportPicker(result)
            }
            .sheet(item: $migrationPreview) { preview in
                MigrationPreviewSheet(preview: preview) {
                    applyImport(preview)
                }
            }
            .alert("Export before leaving?", isPresented: $showExportBeforeLeave) {
                Button("Export library") {
                    exportLibrary()
                    leaveHousehold()
                }
                Button("Leave without exporting", role: .destructive) {
                    leaveHousehold()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Export a full copy of the household library before you go. You can delete unwanted titles after importing elsewhere.")
            }
            .alert("Migration failed", isPresented: Binding(
                get: { migrationError != nil },
                set: { if !$0 { migrationError = nil } }
            )) {
                Button("OK", role: .cancel) { migrationError = nil }
            } message: {
                Text(migrationError ?? "")
            }
            .task(id: household?.objectID) {
                await refreshParticipantStatus()
            }
    }

    @ViewBuilder
    var settingsSections: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            iCloudSection
            householdSection
            migrationSection
            costSection
            locationsSection
            formatsSection
            bindingsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #else
        iCloudSection
        householdSection
        migrationSection
        costSection
        locationsSection
        formatsSection
        bindingsSection
        #endif
    }

    @ViewBuilder
    private var iCloudSection: some View {
        #if os(macOS)
        settingsCard(
            title: "iCloud",
            footer: "The Mac app keeps your library on this device. Use Export library to move it, or open Stacked on iPhone or iPad for iCloud sync and household sharing."
        ) {
            settingsRow(title: "Sync", value: "This Mac")
        }
        #else
        Section {
            LabeledContent("Account") {
                Text(identity.isSignedIn ? "Signed in" : "Not signed in")
                    .foregroundStyle(identity.isSignedIn ? StackedTheme.Text.secondary : StackedTheme.Semantic.destructive)
            }
            if identity.isSignedIn {
                LabeledContent("Sync") {
                    Text("Active")
                        .foregroundStyle(StackedTheme.Text.secondary)
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Your library syncs through iCloud. Sign in under Settings → Apple ID to back up and share.")
        }
        #endif
    }

    @ViewBuilder
    private var householdSection: some View {
        #if os(macOS)
        if let household {
            settingsCard(
                title: "Household",
                footer: "Household sharing is available on iPhone and iPad."
            ) {
                settingsRow(title: "Household", value: household.name)
                if sharingService.pendingMergeAfterJoin {
                    cardDivider()
                    cardButton(title: "Add my books to household", systemImage: "books.vertical") {
                        contributePrivateLibrary()
                    }
                }
            }
        }
        #else
        Section {
            if let household {
                LabeledContent("Household") {
                    Text(household.name)
                }
                Button {
                    Task { await inviteToHousehold(household) }
                } label: {
                    Label("Invite to household", systemImage: "person.badge.plus")
                }
                if sharingService.pendingMergeAfterJoin {
                    Button("Add my books to household") {
                        contributePrivateLibrary()
                    }
                }
                if isSharedParticipant {
                    Button("Leave household", role: .destructive) {
                        showExportBeforeLeave = true
                    }
                }
            }
        } header: {
            Text("Household")
        } footer: {
            Text("Invite your partner so you share one library and avoid buying the same book twice.")
        }
        #endif
    }

    @ViewBuilder
    private var migrationSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Move your library",
            footer: "Export or import a complete copy of your library to move it between Stacked users. Imported books will show you as the adder. No book lookup is performed on import."
        ) {
            cardButton(title: "Export library", systemImage: "square.and.arrow.up") {
                exportLibrary()
            }
            cardDivider()
            cardButton(title: "Import library", systemImage: "square.and.arrow.down") {
                showImporter = true
            }
        }
        #else
        Section {
            Button {
                exportLibrary()
            } label: {
                Label("Export library", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("Import library", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Move your library")
        } footer: {
            Text("Export or import a complete copy of your library to move it between Stacked users. Imported books will show you as the adder. No book lookup is performed on import.")
        }
        #endif
    }

    @ViewBuilder
    private var costSection: some View {
        #if os(macOS)
        settingsCard(
            title: "Cost",
            footer: "This will allow you to see costs associated with your collection and include them when exporting your library."
        ) {
            Toggle(
                "Track item costs",
                isOn: Binding(
                    get: { appSettings.showCostTracking },
                    set: { appSettings.showCostTracking = $0 }
                )
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if appSettings.showCostTracking {
                cardDivider()
                NavigationLink {
                    CostView()
                } label: {
                    Label("Cost information", systemImage: "dollarsign.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        #else
        Section {
            Toggle(
                "Track item costs",
                isOn: Binding(
                    get: { appSettings.showCostTracking },
                    set: { appSettings.showCostTracking = $0 }
                )
            )
            if appSettings.showCostTracking {
                NavigationLink {
                    CostView()
                } label: {
                    Label("Cost information", systemImage: "dollarsign.circle")
                }
            }
        } header: {
            Text("Cost")
        } footer: {
            Text("This will allow you to see costs associated with your collection and include them when exporting your library.")
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
                    onRename: { editor = renameLocation(location) },
                    onMakeDefault: location.isDefault ? nil : { makeDefaultLocation(location) },
                    onDelete: locations.count > 1 ? { requestDeleteLocation(location) } : nil
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            cardDivider()
            cardButton(title: "Add location", systemImage: "plus") {
                editor = addLocation()
            }
        }
        #else
        Section {
            ForEach(locations) { location in
                taxonomyRow(
                    name: location.name,
                    isDefault: location.isDefault,
                    onRename: { editor = renameLocation(location) },
                    onMakeDefault: location.isDefault ? nil : { makeDefaultLocation(location) },
                    onDelete: locations.count > 1 ? { requestDeleteLocation(location) } : nil
                )
            }
            Button { editor = addLocation() } label: {
                Label("Add location", systemImage: "plus")
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
                    onRename: { editor = renameFormat(format) },
                    onMakeDefault: format.isDefault ? nil : { makeDefaultFormat(format) },
                    onDelete: { requestDeleteFormat(format) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            cardDivider()
            cardButton(title: "Add format", systemImage: "plus") {
                editor = addFormat()
            }
        }
        #else
        Section {
            ForEach(formats) { format in
                taxonomyRow(
                    name: format.name,
                    isDefault: format.isDefault,
                    onRename: { editor = renameFormat(format) },
                    onMakeDefault: format.isDefault ? nil : { makeDefaultFormat(format) },
                    onDelete: { requestDeleteFormat(format) }
                )
            }
            Button { editor = addFormat() } label: {
                Label("Add format", systemImage: "plus")
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
                    onRename: { editor = renameBinding(binding) },
                    onMakeDefault: binding.isDefault ? nil : { makeDefaultBinding(binding) },
                    onDelete: { requestDeleteBinding(binding) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            cardDivider()
            cardButton(title: "Add binding", systemImage: "plus") {
                editor = addBinding()
            }
        }
        #else
        Section {
            ForEach(bindings) { binding in
                taxonomyRow(
                    name: binding.name,
                    isDefault: binding.isDefault,
                    onRename: { editor = renameBinding(binding) },
                    onMakeDefault: binding.isDefault ? nil : { makeDefaultBinding(binding) },
                    onDelete: { requestDeleteBinding(binding) }
                )
            }
            Button { editor = addBinding() } label: {
                Label("Add binding", systemImage: "plus")
            }
        } header: {
            Text("Bindings")
        } footer: {
            Text("Physical edition (e.g. Paperback, Hardcover, Spiral).")
        }
        #endif
    }

    @ViewBuilder
    private func taxonomyRow(
        name: String,
        isDefault: Bool,
        onRename: @escaping () -> Void,
        onMakeDefault: (() -> Void)?,
        onDelete: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: onRename) {
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
            .buttonStyle(.plain)

            Menu {
                Button("Rename", action: onRename)
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
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .swipeActions(edge: .leading) {
            if let onMakeDefault {
                Button("Default", action: onMakeDefault).tint(StackedTheme.accent)
            }
        }
        #endif
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

    #if os(iOS)
    private func inviteToHousehold(_ household: Household) async {
        do {
            let newShare = try await sharingService.createShare(for: household)
            share = newShare
            showSharing = true
        } catch {
            migrationError = error.localizedDescription
        }
    }
    #endif

    private func contributePrivateLibrary() {
        guard let household,
              let source = householdManager.privateLibraryCollection(in: context) else { return }
        try? CollectionMergeService.mergePrivateIntoHousehold(source: source, targetHousehold: household, in: context)
        sharingService.pendingMergeAfterJoin = false
    }

    private func refreshParticipantStatus() async {
        #if os(iOS)
        guard let household else {
            isSharedParticipant = false
            return
        }
        guard householdManager.isSharedHousehold(household, in: context) else {
            isSharedParticipant = false
            return
        }
        isSharedParticipant = !(await sharingService.isOwner(of: household))
        #else
        isSharedParticipant = false
        #endif
    }

    private func leaveHousehold() {
        #if os(iOS)
        guard let household else { return }
        Task {
            do {
                try await sharingService.leaveSharedHousehold(household)
            } catch {
                migrationError = error.localizedDescription
            }
        }
        #endif
    }

    private func exportLibrary() {
        guard let household else { return }
        do {
            exportURL = try LibraryMigrationService.exportHousehold(household, context: context)
            showExportShare = true
        } catch {
            migrationError = error.localizedDescription
        }
    }

    private func handleImportPicker(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            migrationError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                migrationError = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                migrationPreview = try LibraryMigrationService.previewImport(from: url)
            } catch {
                migrationError = error.localizedDescription
            }
        }
    }

    private func applyImport(_ preview: MigrationPreview) {
        guard let household else { return }
        do {
            try LibraryMigrationService.applyImport(preview, into: household, context: context)
            migrationPreview = nil
        } catch {
            migrationError = error.localizedDescription
        }
    }

    private func addLocation() -> NameEditorTarget {
        NameEditorTarget(title: "New Location", initialName: "") { name in
            guard let household else { return }
            let isFirst = locations.isEmpty
            _ = StorageLocation.create(in: context, household: household, name: name, isDefault: isFirst)
            PersistenceController.shared.save()
        }
    }

    private func renameLocation(_ location: StorageLocation) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Location", initialName: location.name) { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            location.name = trimmed
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultLocation(_ location: StorageLocation) {
        for other in locations { other.isDefault = false }
        location.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteLocation(_ location: StorageLocation) {
        guard locations.count > 1 else { return }
        if location.titleCount > 0 {
            deleteRequest = TaxonomyDeleteRequest(target: .location(location))
        } else {
            deleteUnused(location)
        }
    }

    private func deleteUnused(_ location: StorageLocation) {
        let wasDefault = location.isDefault
        context.delete(location)
        if wasDefault, let next = locations.first(where: { $0.id != location.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }

    private func renameFormat(_ format: ItemFormat) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Format", initialName: format.name) { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            format.name = trimmed
            PersistenceController.shared.save()
        }
    }

    private func addFormat() -> NameEditorTarget {
        NameEditorTarget(title: "New Format", initialName: "") { name in
            guard let household else { return }
            let isFirst = formats.isEmpty
            _ = ItemFormat.create(in: context, household: household, name: name, isDefault: isFirst)
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultFormat(_ format: ItemFormat) {
        for other in formats { other.isDefault = false }
        format.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteFormat(_ format: ItemFormat) {
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
        let wasDefault = format.isDefault
        context.delete(format)
        if wasDefault, let next = formats.first(where: { $0.id != format.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }

    private func addBinding() -> NameEditorTarget {
        NameEditorTarget(title: "New Binding", initialName: "") { name in
            guard let household else { return }
            let isFirst = bindings.isEmpty
            _ = ItemBinding.create(in: context, household: household, name: name, isDefault: isFirst)
            PersistenceController.shared.save()
        }
    }

    private func renameBinding(_ binding: ItemBinding) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Binding", initialName: binding.name) { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            binding.name = trimmed
            PersistenceController.shared.save()
        }
    }

    private func makeDefaultBinding(_ binding: ItemBinding) {
        for other in bindings { other.isDefault = false }
        binding.isDefault = true
        PersistenceController.shared.save()
    }

    private func requestDeleteBinding(_ binding: ItemBinding) {
        if binding.titleCount > 0 {
            deleteRequest = TaxonomyDeleteRequest(target: .binding(binding))
        } else {
            deleteUnused(binding)
        }
    }

    private func deleteUnused(_ binding: ItemBinding) {
        let wasDefault = binding.isDefault
        context.delete(binding)
        if wasDefault, let next = bindings.first(where: { $0.id != binding.id }) {
            next.isDefault = true
        }
        PersistenceController.shared.save()
    }
}

extension MigrationPreview: Identifiable {
    var id: String { "\(uniqueTitles)-\(totalCopies)-\(locationCount)" }
}
