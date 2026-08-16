//
//  CollectionAssistantSheet.swift
//  Stacked
//
//  Guides share, Stacked-backup, and CSV export so users pick the right path.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct CollectionAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(HouseholdSharingService.self) private var sharingService
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var step: Step
    @State private var preparedShare: PreparedShareItem?
    @State private var showImporter = false
    @State private var migrationPreview: MigrationPreview?
    @State private var errorMessage: String?
    @State private var isOpeningUserManagement = false
    @State private var showPaywall = false

    private var household: Household? { householdManager.activeHousehold }

    enum Step {
        case choose
        case stackedCopy
        case csv
    }

    init(initialStep: Step = .choose) {
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose: chooseStep
                case .stackedCopy: stackedCopyStep
                case .csv: csvStep
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .choose ? "Done" : "Back") {
                        if step == .choose {
                            dismiss()
                        } else {
                            step = .choose
                        }
                    }
                }
            }
        }
        .sheet(item: $preparedShare) { item in
            ExportShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: "Sharing a collection with other users is included with Stacked +.")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .stackedLibrary],
            allowsMultipleSelection: false
        ) { result in
            handleImportPicker(result)
        }
        .sheet(item: $migrationPreview) { preview in
            MigrationPreviewSheet(preview: preview) {
                applyImport(preview)
            }
        }
        .alert("Couldn't continue", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var title: String {
        switch step {
        case .choose: return "Move or share"
        case .stackedCopy: return "Another Stacked library"
        case .csv: return "Use elsewhere"
        }
    }

    private var chooseStep: some View {
        List {
            Section {
                Text("Hi, I'm Dewey. I'll help you share, copy, or take your collection with you.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }

            Section("Are you looking to…") {
                #if os(iOS)
                Button {
                    Task { await openUserManagement() }
                } label: {
                    if isOpeningUserManagement {
                        HStack {
                            ProgressView()
                            Text("Opening user management…")
                        }
                    } else {
                        option(
                            title: "Share my collection with someone",
                            subtitle: "Give another user full access to manage and contribute to the same live collection."
                        )
                    }
                }
                .disabled(isOpeningUserManagement)
                #endif

                Button {
                    step = .stackedCopy
                } label: {
                    option(
                        title: "Move, copy, or import a Stacked library",
                        subtitle: "Send a backup to another person, or import a Stacked backup into this library. The two libraries stay independent."
                    )
                }

                Button {
                    step = .csv
                } label: {
                    option(
                        title: "Use my collection in another app",
                        subtitle: "Export a CSV you can open in Numbers, Excel, or other software."
                    )
                }
            }
        }
    }

    private var stackedCopyStep: some View {
        List {
            Section {
                Text("Send a backup from this library, or import one into it. After import, the two libraries stay independent.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
            Section {
                Button("Send a Stacked backup") {
                    exportStackedBackup()
                }
                Button("Import a Stacked backup") {
                    showImporter = true
                }
            } footer: {
                Text("Use this when someone is starting their own Stacked library, or when splitting a collection. Matching ISBNs add copies instead of duplicating titles.")
            }
        }
    }

    private var csvStep: some View {
        List {
            Section {
                Text("CSV is for spreadsheets and other software. It does not round-trip covers, ratings, or Stacked relationships.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
            Section {
                Button("Export CSV") {
                    exportCSV()
                }
            } footer: {
                Text("This path is export-only. To recreate a collection in Stacked, use a Stacked backup instead.")
            }
        }
    }

    private func option(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(StackedTheme.Text.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(StackedTheme.Text.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    #if os(iOS)
    private func openUserManagement() async {
        guard !isOpeningUserManagement, let household else { return }
        isOpeningUserManagement = true
        defer { isOpeningUserManagement = false }

        do {
            let presented = try await sharingService.presentUserManagement(
                for: household,
                isPlus: subscriptions.isPlus
            )
            if !presented {
                showPaywall = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    private func exportStackedBackup() {
        guard let household else { return }
        do {
            let url = try LibraryMigrationService.exportHousehold(household, context: context)
            preparedShare = PreparedShareItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        guard let household else { return }
        do {
            let url = try LibraryMigrationService.portableCSVURL(household, context: context)
            preparedShare = PreparedShareItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportPicker(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                migrationPreview = try LibraryMigrationService.previewImport(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyImport(_ preview: MigrationPreview) {
        guard let household else { return }
        do {
            try LibraryMigrationService.applyImport(preview, into: household, context: context)
            migrationPreview = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
