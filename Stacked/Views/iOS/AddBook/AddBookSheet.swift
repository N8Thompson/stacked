//
//  AddBookSheet.swift
//  Stacked
//
//  iOS search-and-add flow with text search, camera scan, and barcode scan.
//

import SwiftUI

#if os(iOS)
struct AddBookSheet: View {
    let preselection: AddPreselection
    var onDismiss: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(HouseholdManager.self) private var householdManager

    @FocusState private var searchFieldFocused: Bool
    @State private var actions: AddBookActions

    init(preselection: AddPreselection, onDismiss: (() -> Void)? = nil) {
        self.preselection = preselection
        self.onDismiss = onDismiss
        _actions = State(initialValue: AddBookActions(preselection: preselection))
    }

    private var books: [Book] { householdManager.allBooks(in: context) }
    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }
    private var provider: BookSearchProvider { BookSearchProviderFactory.make() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sourcePicker

                if actions.source == .manual {
                    ManualBookFormView(
                        preselection: actions.manualPreselection(locations: locations),
                        hasUnsavedChanges: $actions.manualHasUnsavedChanges
                    ) {
                        actions.close(dismiss: dismiss)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    searchContent
                        .frame(maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { actions.requestDone(dismiss: dismiss) }
                }
            }
        }
        .interactiveDismissDisabled(actions.source == .manual && actions.manualHasUnsavedChanges)
        .alert("Discard unsaved entry?", isPresented: $actions.showDiscardManualAlert) {
            Button("Stay", role: .cancel) {
                actions.cancelDiscardPrompt()
            }
            Button("Discard", role: .destructive) {
                actions.confirmDiscardManualNavigation(dismiss: dismiss)
            }
        } message: {
            Text("You have unsaved changes to this manual entry.")
        }
        .onAppear {
            actions.onDismiss = onDismiss
            actions.initTargetsIfNeeded(locations: locations)
        }
        .onChange(of: actions.source) { _, newSource in
            actions.handleSourceChange(newSource)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack(spacing: 0) {
            if actions.source != .text {
                scannerArea
                    .frame(height: actions.source == .scanBarcode ? 200 : 260)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if actions.source == .text {
                searchField
            }

            targetBar

            resultsList
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var sourcePicker: some View {
        HStack(spacing: 4) {
            ForEach(SearchSource.addSheetSources) { option in
                sourceSegment(option)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(StackedTheme.Surface.track))
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sourceSegment(_ option: SearchSource) -> some View {
        let enabled = actions.isSourceEnabled(option)
        let selected = actions.source == option
        return Button {
            actions.requestSourceChange(to: option)
        } label: {
            Text(option.segmentTitle)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(
                    selected && enabled
                        ? StackedTheme.Text.onAccent
                        : (enabled ? StackedTheme.Text.primary : StackedTheme.Text.tertiary)
                )
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected && enabled ? AnyShapeStyle(StackedTheme.Gradient.accent) : AnyShapeStyle(Color.clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Title, author, or keyword", text: $actions.query)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onSubmit { actions.runTextSearch(provider: provider) }
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !actions.query.isEmpty {
                    Button { actions.clearTextSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(StackedTheme.Surface.track))
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var scannerArea: some View {
        ScannerView(mode: actions.source == .scanBarcode ? .barcode : .text) { scanned in
            actions.handleScannedInput(
                scanned,
                isBarcode: actions.source == .scanBarcode,
                provider: provider
            )
        }
        .id(actions.source)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottom) {
            Text(actions.source == .scanBarcode
                 ? "Point at a barcode — scan another anytime"
                 : "Tap recognized text to search")
                .font(.caption).padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
    }

    @ViewBuilder
    private var targetBar: some View {
        HStack {
            if locations.count > 1 {
                Menu {
                    ForEach(locations) { location in
                        Button {
                            actions.targetLocationID = location.id
                        } label: {
                            Label(
                                location.name,
                                systemImage: actions.targetLocationID == location.id ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    Text("Adding to \(actions.targetLocationName(locations: locations))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let name = locations.first?.name {
                Text("Adding to \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var resultsList: some View {
        Group {
            if actions.isLoading {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            } else if let errorMessage = actions.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't search", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
            } else if actions.results.isEmpty {
                if actions.hasSearched {
                    ContentUnavailableView {
                        Label("No matches", systemImage: "books.vertical")
                    } description: {
                        Text("Nothing came back for that search. Try different words or a shorter phrase.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
                } else {
                    ContentUnavailableView {
                        Label("Find a book", systemImage: "magnifyingglass")
                    } description: {
                        Text(actions.emptyStateMessage)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
                }
            } else {
                List(actions.results) { result in
                    SearchResultRow(
                        result: result,
                        ownedCopies: actions.ownedByISBN(books: books)[result.isbn] ?? 0
                    ) { count in
                        actions.add(
                            result: result,
                            count: count,
                            books: books,
                            locations: locations,
                            formats: formats,
                            householdManager: householdManager,
                            context: context
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }
}
#endif
