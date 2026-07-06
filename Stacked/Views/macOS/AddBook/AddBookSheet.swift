//
//  AddBookSheet.swift
//  Stacked
//
//  macOS search-and-add panel with text search and manual entry.
//

import SwiftUI

#if os(macOS)
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
        VStack(spacing: 4) {
            HStack {
                Spacer()
                Button("Done") { actions.requestDone(dismiss: dismiss) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            headerRow

            if actions.source == .manual {
                NavigationStack {
                    ManualBookFormView(
                        preselection: actions.manualPreselection(locations: locations),
                        hasUnsavedChanges: $actions.manualHasUnsavedChanges
                    ) {
                        actions.close(dismiss: dismiss)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                resultsList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
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
        .frame(width: 540, height: 520)
        .background(StackedTheme.Background.primary)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            if actions.source == .text {
                targetLocationLabel
            }

            Spacer(minLength: 8)

            segmentedPicker
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var targetLocationLabel: some View {
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
            .menuStyle(.borderlessButton)
        } else if let name = locations.first?.name {
            Text("Adding to \(name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var segmentedPicker: some View {
        Picker("Add method", selection: Binding(
            get: { actions.source },
            set: { actions.requestSourceChange(to: $0) }
        )) {
            ForEach(SearchSource.addSheetSources) { option in
                Text(option.segmentTitle).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Title, author, or keyword", text: $actions.query)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onSubmit { actions.runTextSearch(provider: provider) }
                if !actions.query.isEmpty {
                    Button { actions.clearTextSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(StackedTheme.Surface.track))

            Button("Search") { actions.runTextSearch(provider: provider) }
                .disabled(actions.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        Group {
            if actions.isLoading {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = actions.errorMessage {
                resultsUnavailable(
                    icon: "exclamationmark.triangle",
                    title: "Couldn't search",
                    description: errorMessage
                )
            } else if actions.results.isEmpty {
                if actions.hasSearched {
                    resultsUnavailable(
                        icon: "books.vertical",
                        title: "No matches",
                        description: "Nothing came back for that search. Try different words or a shorter phrase."
                    )
                } else {
                    searchPrompt
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
                    .listRowBackground(StackedTheme.Surface.primary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StackedTheme.Surface.muted)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(StackedTheme.Text.tertiary.opacity(0.85))
            Text("Search for a book to get started")
                .font(.subheadline)
                .foregroundStyle(StackedTheme.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func resultsUnavailable(icon: String, title: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
