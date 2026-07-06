//
//  AddBookActions.swift
//  Stacked
//
//  Shared search, ISBN handling, and add-to-library logic for both platforms.
//

import SwiftUI
import CoreData

@MainActor
@Observable
final class AddBookActions {
    let preselection: AddPreselection
    var onDismiss: (() -> Void)?

    var source: SearchSource = .text
    var query = ""
    var results: [BookSearchResult] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false

    var targetLocationID: UUID?
    private(set) var didInitTargets = false

    private var lastAPIQueryKey = ""
    private var activeSearchTask: Task<Void, Never>?

    var manualHasUnsavedChanges = false
    var showDiscardManualAlert = false
    var pendingSourceChange: SearchSource?
    var pendingSheetDismiss = false

    init(preselection: AddPreselection) {
        self.preselection = preselection
    }

    func manualPreselection(locations: [StorageLocation]) -> AddPreselection {
        AddPreselection(
            location: preselection.location ?? resolvedLocation(from: locations),
            format: preselection.format
        )
    }

    func ownedByISBN(books: [Book]) -> [String: Int] {
        Dictionary(books.map { ($0.isbn, Int($0.copies)) }, uniquingKeysWith: +)
    }

    func initTargetsIfNeeded(locations: [StorageLocation]) {
        guard !didInitTargets else { return }
        didInitTargets = true
        targetLocationID = preselection.location?.id ?? defaultLocation(from: locations)?.id
    }

    func handleSourceChange(_ newSource: SearchSource) {
        guard SearchSource.addSheetSources.contains(newSource), isSourceEnabled(newSource) else {
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

    func isSourceEnabled(_ source: SearchSource) -> Bool {
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

    func handleScannedInput(_ raw: String, isBarcode: Bool, provider: BookSearchProvider) {
        if isBarcode {
            guard let isbn = normalizedISBN(raw), isValidISBN(isbn) else { return }
            guard !shouldSkipScanQuery(isbn) else { return }
            lastAPIQueryKey = isbn
            runBarcodeLookup(isbn: isbn, provider: provider)
            return
        }

        let key = normalizedScanQuery(raw)
        guard key.count >= 4 else { return }
        guard !shouldSkipScanQuery(key) else { return }

        lastAPIQueryKey = key
        query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        runTextSearch(provider: provider)
    }

    func runTextSearch(provider: BookSearchProvider) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        performSearch(provider: provider) { try await provider.search(query: text) }
    }

    func runBarcodeLookup(isbn: String, provider: BookSearchProvider) {
        guard !isbn.isEmpty else { return }
        performSearch(provider: provider) {
            if let result = try await provider.lookup(isbn: isbn) { return [result] }
            return []
        }
    }

    func add(
        result: BookSearchResult,
        count: Int,
        books: [Book],
        locations: [StorageLocation],
        formats: [ItemFormat],
        householdManager: HouseholdManager,
        context: NSManagedObjectContext
    ) {
        if let existing = books.first(where: { $0.isbn == result.isbn }) {
            existing.copies += Int32(count)
        } else {
            guard let collection = householdManager.defaultCollection(in: context) else { return }
            let bindingOption: ItemBinding? = {
                guard let name = result.binding, !name.isEmpty,
                      let household = householdManager.activeHousehold else { return nil }
                return TaxonomyService.findOrCreateBinding(name: name, household: household, in: context)
            }()
            _ = Book.create(
                in: context,
                collection: collection,
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
                location: resolvedLocation(from: locations),
                format: bookFormat(from: formats),
                bindingOption: bindingOption
            )
        }
        PersistenceController.shared.save()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    func targetLocationName(locations: [StorageLocation]) -> String {
        locations.first { $0.id == targetLocationID }?.name ?? "Home Library"
    }

    var emptyStateMessage: String {
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

    func requestDone(dismiss: DismissAction) {
        if source == .manual && manualHasUnsavedChanges {
            pendingSheetDismiss = true
            showDiscardManualAlert = true
        } else {
            close(dismiss: dismiss)
        }
    }

    func requestSourceChange(to option: SearchSource) {
        guard option != source else { return }
        if source == .manual && manualHasUnsavedChanges {
            pendingSourceChange = option
            showDiscardManualAlert = true
        } else {
            source = option
        }
    }

    func confirmDiscardManualNavigation(dismiss: DismissAction) {
        manualHasUnsavedChanges = false
        if pendingSheetDismiss {
            pendingSheetDismiss = false
            close(dismiss: dismiss)
        } else if let next = pendingSourceChange {
            pendingSourceChange = nil
            source = next
        }
    }

    func cancelDiscardPrompt() {
        pendingSourceChange = nil
        pendingSheetDismiss = false
    }

    func close(dismiss: DismissAction) {
        onDismiss?()
        #if os(iOS)
        dismiss()
        #endif
    }

    func clearTextSearch() {
        query = ""
        results = []
        hasSearched = false
    }

    // MARK: Private

    private func performSearch(provider: BookSearchProvider, _ operation: @escaping () async throws -> [BookSearchResult]) {
        activeSearchTask?.cancel()
        isLoading = true
        errorMessage = nil
        hasSearched = true
        activeSearchTask = Task {
            do {
                let found = try await operation()
                guard !Task.isCancelled else { return }
                await MainActor.run {
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

    private func resolvedLocation(from locations: [StorageLocation]) -> StorageLocation? {
        locations.first { $0.id == targetLocationID }
            ?? defaultLocation(from: locations)
    }

    private func bookFormat(from formats: [ItemFormat]) -> ItemFormat? {
        formats.first { $0.name.lowercased() == "books" } ?? defaultFormat(from: formats)
    }

    private func defaultLocation(from locations: [StorageLocation]) -> StorageLocation? {
        locations.first { $0.isDefault } ?? locations.first
    }

    private func defaultFormat(from formats: [ItemFormat]) -> ItemFormat? {
        formats.first { $0.isDefault } ?? formats.first
    }
}
