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

    /// Live results for the Bluetooth scanner session, newest first.
    var scannerItems: [ScannerSessionItem] = []
    private var lastScannerISBN = ""
    private var lastScannerAt = Date.distantPast

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
        Dictionary(
            books.compactMap { book in
                (BookIdentity.canonicalISBN(book.isbn) ?? BookIdentity.normalizedISBN(book.isbn))
                    .map { ($0, Int(book.copies)) }
            },
            uniquingKeysWith: +
        )
    }

    func initTargetsIfNeeded(locations: [StorageLocation]) {
        guard !didInitTargets else { return }
        didInitTargets = true
        targetLocationID = preselection.location?.id ?? defaultLocation(from: locations)?.id
    }

    func handleSourceChange(_ newSource: SearchSource) {
        guard SearchSource.supportedSources.contains(newSource), isSourceEnabled(newSource) else {
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

    var showPaywall = false
    var paywallReason = "Stacked + unlocks more of your library."

    func isSourceEnabled(_ source: SearchSource) -> Bool {
        switch source {
        case .text, .manual, .scanner:
            return true
        case .scanText, .scanBarcode:
            #if os(iOS)
            return ScannerView.isSupported
            #else
            return false
            #endif
        }
    }

    func requestSourceChange(to option: SearchSource, isPlus: Bool) {
        if option == .scanner && !isPlus {
            presentPaywall("Bluetooth batch scanning is included with Stacked +.")
            return
        }
        guard option != source else { return }
        if source == .manual && manualHasUnsavedChanges {
            pendingSourceChange = option
            showDiscardManualAlert = true
        } else {
            source = option
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

    func presentPaywall(_ reason: String) {
        paywallReason = reason
        showPaywall = true
    }

    func uniqueTitleLimitReason() -> String {
        "The free library includes \(EntitlementPolicy.freeUniqueTitleLimit) unique titles. Upgrade to Stacked + to add more. Your existing titles stay."
    }

    @discardableResult
    func add(
        result: BookSearchResult,
        count: Int,
        books: [Book],
        locations: [StorageLocation],
        formats: [ItemFormat],
        orgManager: OrgManager,
        context: NSManagedObjectContext,
        isPlus: Bool,
        canContribute: Bool
    ) -> AddOutcome? {
        guard canContribute else {
            errorMessage = "The collection owner's Stacked + access must be active before participants can add books."
            return nil
        }
        let outcome: AddOutcome
        let resultKey = BookIdentity.key(
            isbn: result.isbn,
            title: result.title,
            authors: result.authorsText,
            publishedYear: result.publishedYear
        )
        if let existing = books.first(where: {
            BookIdentity.key(
                isbn: $0.isbn,
                title: $0.title,
                authors: $0.authors,
                publishedYear: $0.publishedYearValue
            ) == resultKey
        }) {
            existing.copies += Int32(count)
            outcome = AddOutcome(isNewTitle: false, totalCopies: Int(existing.copies))
        } else {
            guard EntitlementPolicy.canAddUniqueTitle(isPlus: isPlus, currentUniqueTitles: books.count) else {
                presentPaywall(uniqueTitleLimitReason())
                return nil
            }
            guard let collection = orgManager.defaultCollection(in: context) else { return nil }
            let bindingOption: ItemBinding? = {
                guard let name = result.binding, !name.isEmpty,
                      let org = orgManager.activeOrg else { return nil }
                return TaxonomyService.findOrCreateBinding(name: name, org: org, in: context)
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
            outcome = AddOutcome(isNewTitle: true, totalCopies: count)
        }
        PersistenceController.shared.save()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        return outcome
    }

    // MARK: Bluetooth scanner session

    /// Handles one raw HID scan: normalize, look up, add (or increment copies),
    /// and record a session item. Errors surface as a single replaceable card.
    func processScannerInput(
        _ raw: String,
        locations: [StorageLocation],
        formats: [ItemFormat],
        orgManager: OrgManager,
        context: NSManagedObjectContext,
        provider: BookSearchProvider,
        isPlus: Bool,
        canContribute: Bool
    ) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let isbn = normalizedISBN(trimmed), isValidISBN(isbn) else {
            recordScannerError(message: "That doesn't look like a book barcode.", scanned: trimmed)
            return
        }

        // Guard against a single physical scan firing twice in quick succession,
        // while still allowing an intentional re-scan to add another copy.
        let now = Date()
        if isbn == lastScannerISBN, now.timeIntervalSince(lastScannerAt) < 0.4 { return }
        lastScannerISBN = isbn
        lastScannerAt = now

        do {
            guard let result = try await provider.lookup(isbn: isbn) else {
                recordScannerError(message: "No book found for \(isbn).", scanned: isbn)
                return
            }
            let books = orgManager.allBooks(in: context)
            guard let outcome = add(
                result: result,
                count: 1,
                books: books,
                locations: locations,
                formats: formats,
                orgManager: orgManager,
                context: context,
                isPlus: isPlus,
                canContribute: canContribute
            ) else {
                if showPaywall {
                    recordScannerError(message: uniqueTitleLimitReason(), scanned: isbn)
                } else if !canContribute {
                    recordScannerError(
                        message: "The collection owner's Stacked + access must be active before participants can add books.",
                        scanned: isbn
                    )
                } else {
                    recordScannerError(message: "Couldn't add this book.", scanned: isbn)
                }
                return
            }
            let info = AddedBookInfo(
                isbn: result.isbn,
                title: result.title,
                authors: result.authorsText,
                coverURL: result.coverURL,
                totalCopies: outcome.totalCopies,
                isNewTitle: outcome.isNewTitle
            )
            removeScannerErrorCards()
            scannerItems.insert(.added(info), at: 0)
            ScannerFeedback.success()
        } catch {
            let message = (error as? BookSearchError)?.errorDescription
                ?? "Lookup failed. Check your connection and try again."
            recordScannerError(message: message, scanned: isbn)
        }
    }

    /// Removes a session row. For an added book this also undoes one copy in the
    /// library (deleting the title if it was the last copy).
    func removeScannerItem(
        _ item: ScannerSessionItem,
        orgManager: OrgManager,
        context: NSManagedObjectContext
    ) {
        if case .added(let info) = item {
            let books = orgManager.allBooks(in: context)
            if let book = books.first(where: { $0.isbn == info.isbn }) {
                if book.copies > 1 {
                    book.copies -= 1
                } else {
                    context.delete(book)
                }
                PersistenceController.shared.save()
            }
        }
        scannerItems.removeAll { $0.id == item.id }
    }

    private func recordScannerError(message: String, scanned: String) {
        removeScannerErrorCards()
        scannerItems.insert(.failure(ScanErrorInfo(message: message, scannedText: scanned)), at: 0)
        ScannerFeedback.failure()
    }

    private func removeScannerErrorCards() {
        scannerItems.removeAll {
            if case .failure = $0 { return true }
            return false
        }
    }

    func targetLocationName(locations: [StorageLocation]) -> String {
        locations.first { $0.id == targetLocationID }?.name ?? "Home Library"
    }

    var emptyStateMessage: String {
        switch source {
        case .text:
            return "Search by title, author, or keyword to add books."
        case .scanBarcode:
            return "Use the camera to scan the ISBN barcode on the back cover."
        case .scanText:
            return "Use the camera to recognize title or author text on the cover."
        case .scanner:
            return "Connect a Bluetooth barcode scanner to add books continuously."
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
            return BookIdentity.canonicalISBN(String(upper[range]))
        }
        return BookIdentity.canonicalISBN(upper)
    }

    private func isValidISBN(_ isbn: String) -> Bool {
        BookIdentity.canonicalISBN(isbn) != nil
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
