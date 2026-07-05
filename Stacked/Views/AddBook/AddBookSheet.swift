//
//  AddBookSheet.swift
//  Stacked
//
//  Search-and-add flow. Offers text search, camera text scan, and barcode
//  scan (camera modes on iOS/iPadOS only). Detects already-owned titles and
//  supports quick-add of multiple copies to a chosen location/format.
//

import SwiftUI
import SwiftData

enum SearchSource: String, CaseIterable, Identifiable {
    case text
    case scanBarcode
    case scanText
    case manual

    var id: String { rawValue }

    /// Short label for the mode picker at the top of the add sheet.
    var segmentTitle: String {
        switch self {
        case .text: return "Text"
        case .scanBarcode: return "Barcode"
        case .scanText: return "Cover"
        case .manual: return "Manual"
        }
    }
}

struct AddBookSheet: View {
    let preselection: AddPreselection

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var source: SearchSource = .text
    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    @State private var targetLocationID: PersistentIdentifier?
    @State private var didInitTargets = false

    /// Skips repeat API calls for the same scanned ISBN or tapped text.
    @State private var lastAPIQueryKey = ""
    @State private var activeSearchTask: Task<Void, Never>?

    @State private var manualHasUnsavedChanges = false
    @State private var showDiscardManualAlert = false
    @State private var pendingSourceChange: SearchSource?
    @State private var pendingSheetDismiss = false

    private var provider: BookSearchProvider { BookSearchProviderFactory.make() }

    private var ownedByISBN: [String: Int] {
        Dictionary(books.map { ($0.isbn, $0.copies) }, uniquingKeysWith: +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sourcePicker
                    .padding([.horizontal, .top])

                if source == .manual {
                    ManualBookFormView(
                        preselection: manualPreselection,
                        hasUnsavedChanges: $manualHasUnsavedChanges
                    ) {
                        dismiss()
                    }
                } else {
                    searchContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { requestDone() }
                }
            }
            .interactiveDismissDisabled(source == .manual && manualHasUnsavedChanges)
            .alert("Discard unsaved entry?", isPresented: $showDiscardManualAlert) {
                Button("Stay", role: .cancel) {
                    pendingSourceChange = nil
                    pendingSheetDismiss = false
                }
                Button("Discard", role: .destructive) {
                    confirmDiscardManualNavigation()
                }
            } message: {
                Text("You have unsaved changes to this manual entry.")
            }
            .onAppear(perform: initTargetsIfNeeded)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        #if os(iOS)
        if source != .text {
            scannerArea
                .frame(height: source == .scanBarcode ? 200 : 260)
                .padding(.horizontal)
                .padding(.top, 8)
        }
        #endif

        if source == .text {
            searchField.padding()
        }

        targetBar

        Divider()

        resultsList
    }

    private var manualPreselection: AddPreselection {
        AddPreselection(
            location: preselection.location ?? resolvedLocation,
            format: preselection.format
        )
    }

    // MARK: Source picker

    private var sourcePicker: some View {
        HStack(spacing: 4) {
            ForEach(SearchSource.allCases) { option in
                sourceSegment(option)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.6)))
        .onChange(of: source) { _, newSource in
            guard isSourceEnabled(newSource) else {
                source = .text
                return
            }
            activeSearchTask?.cancel()
            activeSearchTask = nil
            isLoading = false
            results = []
            errorMessage = nil
            hasSearched = false
            lastAPIQueryKey = ""
        }
    }

    private func sourceSegment(_ option: SearchSource) -> some View {
        let enabled = isSourceEnabled(option)
        let selected = source == option
        return Button {
            requestSourceChange(to: option)
        } label: {
            Text(option.segmentTitle)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected && enabled ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(selected && enabled ? Color.white : (enabled ? Color.primary : Color.secondary))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func isSourceEnabled(_ source: SearchSource) -> Bool {
        switch source {
        case .text, .manual:
            return true
        case .scanText, .scanBarcode:
            #if os(iOS)
            return ScannerView.isSupported
            #else
            return false
            #endif
        }
    }

    // MARK: Text search

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Title, author, or keyword", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { runTextSearch() }
                #if os(iOS)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                #endif
            if !query.isEmpty {
                Button { query = ""; results = []; hasSearched = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    // MARK: Scanner (iOS)

    #if os(iOS)
    @ViewBuilder
    private var scannerArea: some View {
        ScannerView(mode: source == .scanBarcode ? .barcode : .text) { scanned in
            handleScannedInput(scanned, isBarcode: source == .scanBarcode)
        }
        .id(source)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottom) {
            Text(source == .scanBarcode
                 ? "Point at a barcode — scan another anytime"
                 : "Tap recognized text to search")
                .font(.caption).padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
    }
    #endif

    // MARK: Location target

    @ViewBuilder
    private var targetBar: some View {
        HStack {
            if locations.count > 1 {
                Menu {
                    ForEach(locations) { location in
                        Button {
                            targetLocationID = location.persistentModelID
                        } label: {
                            Label(
                                location.name,
                                systemImage: targetLocationID == location.persistentModelID ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    Text("Adding to \(targetLocationName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let name = locations.first?.name {
                Text("Adding to \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var targetLocationName: String {
        locations.first { $0.persistentModelID == targetLocationID }?.name ?? "Home Library"
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        if isLoading {
            Spacer(); ProgressView("Searching…"); Spacer()
        } else if let errorMessage {
            errorState(errorMessage)
        } else if results.isEmpty {
            if hasSearched {
                noResultsState
            } else {
                emptyState
            }
        } else {
            List(results) { result in
                SearchResultRow(
                    result: result,
                    ownedCopies: ownedByISBN[result.isbn] ?? 0
                ) { count in
                    add(result: result, count: count)
                }
            }
            .listStyle(.plain)
        }
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't search", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Find a book", systemImage: "magnifyingglass")
        } description: {
            Text(emptyStateMessage)
        }
    }

    private var emptyStateMessage: String {
        switch source {
        case .text:
            return "Search by title, author, or keyword to add books."
        case .scanBarcode:
            return "Point the camera at a barcode on the back cover."
        case .scanText:
            return "Point the camera at the cover and tap recognized text to search."
        case .manual:
            return ""
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "books.vertical")
        } description: {
            Text("Nothing came back for that search. Try different words or a shorter phrase.")
        }
    }

    // MARK: Camera scan handling

    private func handleScannedInput(_ raw: String, isBarcode: Bool) {
        if isBarcode {
            guard let isbn = normalizedISBN(raw), isValidISBN(isbn) else { return }
            guard !shouldSkipScanQuery(isbn) else { return }
            lastAPIQueryKey = isbn
            runBarcodeLookup(isbn: isbn)
            return
        }

        let key = normalizedScanQuery(raw)
        guard key.count >= 4 else { return }
        guard !shouldSkipScanQuery(key) else { return }

        lastAPIQueryKey = key
        query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        runTextSearch()
    }

    private func normalizedISBN(_ raw: String) -> String? {
        let upper = raw.uppercased()
        if let regex = try? NSRegularExpression(pattern: #"(978|979)[0-9]{10}"#),
           let match = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
           let range = Range(match.range, in: upper) {
            return String(upper[range])
        }
        let compact = upper.filter { $0.isNumber || $0 == "X" }
        guard compact.count == 10 || compact.count == 13 else { return nil }
        return compact
    }

    private func isValidISBN(_ isbn: String) -> Bool {
        isbn.count == 10 || isbn.count == 13
    }

    private func normalizedScanQuery(_ raw: String) -> String {
        raw.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func shouldSkipScanQuery(_ key: String) -> Bool {
        key == lastAPIQueryKey
    }

    // MARK: Search actions

    private func runTextSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        performSearch { try await provider.search(query: text) }
    }

    private func runBarcodeLookup(isbn: String) {
        guard !isbn.isEmpty else { return }
        performSearch {
            if let result = try await provider.lookup(isbn: isbn) { return [result] }
            return []
        }
    }

    private func performSearch(_ operation: @escaping () async throws -> [BookSearchResult]) {
        activeSearchTask?.cancel()
        isLoading = true
        errorMessage = nil
        activeSearchTask = Task {
            do {
                let found = try await operation()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    hasSearched = true
                    results = found
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isLoading = false
                    errorMessage = (error as? BookSearchError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func add(result: BookSearchResult, count: Int) {
        if let existing = books.first(where: { $0.isbn == result.isbn }) {
            existing.copies += count
        } else {
            let bindingOption: ItemBinding? = {
                guard let name = result.binding, !name.isEmpty else { return nil }
                return TaxonomyService.findOrCreateBinding(name: name, in: modelContext)
            }()
            let book = Book(
                isbn: result.isbn,
                title: result.title,
                authors: result.authorsText,
                publisher: result.publisher,
                publishedYear: result.publishedYear,
                synopsis: result.synopsis,
                coverURL: result.coverURL,
                listPrice: result.listPrice,
                copies: count,
                isManualEntry: false,
                location: resolvedLocation,
                format: bookFormat,
                bindingOption: bindingOption
            )
            modelContext.insert(book)
        }
        try? modelContext.save()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private var resolvedLocation: StorageLocation? {
        locations.first { $0.persistentModelID == targetLocationID }
            ?? defaultLocation
    }

    /// ISBNdb results always use the Books format tag; users can change it on the detail screen.
    private var bookFormat: ItemFormat? {
        formats.first { $0.name.lowercased() == "books" } ?? defaultFormat
    }

    private var defaultLocation: StorageLocation? {
        locations.first { $0.isDefault } ?? locations.first
    }
    private var defaultFormat: ItemFormat? {
        formats.first { $0.isDefault } ?? formats.first
    }

    private func initTargetsIfNeeded() {
        guard !didInitTargets else { return }
        didInitTargets = true
        targetLocationID = preselection.location?.persistentModelID ?? defaultLocation?.persistentModelID
    }

    // MARK: Manual discard prompts

    private func requestDone() {
        if source == .manual && manualHasUnsavedChanges {
            pendingSheetDismiss = true
            showDiscardManualAlert = true
        } else {
            dismiss()
        }
    }

    private func requestSourceChange(to option: SearchSource) {
        guard option != source else { return }
        if source == .manual && manualHasUnsavedChanges {
            pendingSourceChange = option
            showDiscardManualAlert = true
        } else {
            source = option
        }
    }

    private func confirmDiscardManualNavigation() {
        manualHasUnsavedChanges = false
        if pendingSheetDismiss {
            pendingSheetDismiss = false
            dismiss()
        } else if let next = pendingSourceChange {
            pendingSourceChange = nil
            source = next
        }
    }
}
