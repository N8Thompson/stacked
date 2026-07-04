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

    var id: String { rawValue }

    /// Short label for the mode picker at the top of the add sheet.
    var segmentTitle: String {
        switch self {
        case .text: return "Text"
        case .scanBarcode: return "Barcode"
        case .scanText: return "Cover"
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

    private var provider: BookSearchProvider { BookSearchProviderFactory.make() }

    private var ownedByISBN: [String: Int] {
        Dictionary(books.map { ($0.isbn, $0.copies) }, uniquingKeysWith: +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sourcePicker
                    .padding([.horizontal, .top])

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: initTargetsIfNeeded)
        }
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
            results = []
            errorMessage = nil
            hasSearched = false
        }
    }

    private func sourceSegment(_ option: SearchSource) -> some View {
        let enabled = isSourceEnabled(option)
        let selected = source == option
        return Button {
            source = option
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
        case .text:
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
            if source == .scanBarcode {
                runBarcodeLookup(isbn: scanned.filter(\.isNumber))
            } else {
                query = scanned
                runTextSearch()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottom) {
            Text(source == .scanBarcode ? "Point at a barcode" : "Tap recognized text to search")
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
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "books.vertical")
        } description: {
            Text("Nothing came back for that search. Try different words or a shorter phrase.")
        }
    }

    // MARK: Actions

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
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let found = try await operation()
                await MainActor.run {
                    hasSearched = true
                    results = found
                    isLoading = false
                }
            } catch {
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
            let book = Book(
                isbn: result.isbn,
                title: result.title,
                authors: result.authorsText,
                publisher: result.publisher,
                publishedYear: result.publishedYear,
                binding: result.binding ?? "",
                synopsis: result.synopsis,
                coverURL: result.coverURL,
                listPrice: result.listPrice,
                copies: count,
                location: resolvedLocation,
                format: bookFormat
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

    /// ISBNdb results always use the Book format tag; users can change it on the detail screen.
    private var bookFormat: ItemFormat? {
        formats.first { $0.name.lowercased() == "book" } ?? defaultFormat
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
}
