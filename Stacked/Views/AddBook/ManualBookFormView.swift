//
//  ManualBookFormView.swift
//  Stacked
//
//  Manual item entry for journal articles and other non-catalog items.
//

import SwiftUI
import SwiftData

private struct ManualDraftSnapshot: Equatable {
    let title: String
    let authors: String
    let publisher: String
    let isbn: String
    let synopsis: String
    let rating: Double
    let reviewNotes: String
    let listPrice: Double
    let actualCost: Double?
    let publishedYear: Int?
    let copies: Int
    let hasCoverOverride: Bool
    let locationID: PersistentIdentifier?
    let formatID: PersistentIdentifier?
    let bindingID: PersistentIdentifier?

    init(
        draft: Book,
        location: StorageLocation?,
        format: ItemFormat?,
        binding: ItemBinding?
    ) {
        title = draft.title
        authors = draft.authors
        publisher = draft.publisher
        isbn = draft.isbn
        synopsis = draft.synopsis
        rating = draft.rating
        reviewNotes = draft.reviewNotes
        listPrice = draft.listPrice
        actualCost = draft.actualCost
        publishedYear = draft.publishedYear
        copies = draft.copies
        hasCoverOverride = draft.coverOverride != nil
        locationID = location?.persistentModelID
        formatID = format?.persistentModelID
        bindingID = binding?.persistentModelID
    }
}

struct ManualBookFormView: View {
    let preselection: AddPreselection
    @Binding var hasUnsavedChanges: Bool
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var draft: Book
    @State private var selectedLocation: StorageLocation?
    @State private var selectedFormat: ItemFormat?
    @State private var selectedBinding: ItemBinding?
    @State private var taxonomyPicker: TaxonomyKind?
    @State private var validationError: String?
    @State private var didInitDraft = false
    @State private var initialSnapshot: ManualDraftSnapshot?

    init(preselection: AddPreselection, hasUnsavedChanges: Binding<Bool>, onSaved: @escaping () -> Void) {
        self.preselection = preselection
        _hasUnsavedChanges = hasUnsavedChanges
        self.onSaved = onSaved
        _draft = State(initialValue: Book(isbn: "", title: "", listPrice: 0, isManualEntry: true))
    }

    private var isValid: Bool {
        BookFormValidation.isValid(
            title: draft.title,
            authors: draft.authors,
            location: selectedLocation,
            format: selectedFormat
        )
    }

    private var currentSnapshot: ManualDraftSnapshot {
        ManualDraftSnapshot(
            draft: draft,
            location: selectedLocation,
            format: selectedFormat,
            binding: selectedBinding
        )
    }

    var body: some View {
        Form {
            BookFormContent(
                book: draft,
                location: $selectedLocation,
                format: $selectedFormat,
                bindingOption: $selectedBinding,
                isEditing: true,
                isISBNEditable: true,
                listPriceEditable: true,
                showDelete: false,
                validationError: validationError,
                taxonomyPicker: $taxonomyPicker
            )
        }
        .navigationDestination(item: $taxonomyPicker) { kind in
            TaxonomyPickerView(
                kind: kind,
                selectedLocation: $selectedLocation,
                selectedFormat: $selectedFormat,
                selectedBinding: $selectedBinding
            )
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!isValid)
            }
        }
        .onAppear(perform: initDraftIfNeeded)
        .onChange(of: currentSnapshot) { _, newSnapshot in
            guard let initial = initialSnapshot else { return }
            hasUnsavedChanges = newSnapshot != initial
        }
    }

    private func initDraftIfNeeded() {
        guard !didInitDraft else { return }
        didInitDraft = true

        if let location = preselection.location {
            selectedLocation = location
        } else if locations.count == 1 {
            selectedLocation = locations.first
        }

        if let format = preselection.format {
            selectedFormat = format
        } else {
            selectedFormat = formats.first { $0.isDefault } ?? formats.first
        }

        initialSnapshot = currentSnapshot
        hasUnsavedChanges = false
    }

    private func save() {
        guard isValid else {
            validationError = "Title, authors, location, and format are required."
            return
        }
        validationError = nil

        let trimmedISBN = draft.isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.isbn = trimmedISBN
        draft.isManualEntry = true
        draft.location = selectedLocation
        draft.format = selectedFormat
        draft.bindingOption = selectedBinding

        if !trimmedISBN.isEmpty, let existing = books.first(where: { $0.isbn == trimmedISBN }) {
            existing.copies += draft.copies
        } else {
            modelContext.insert(draft)
        }

        try? modelContext.save()
        hasUnsavedChanges = false
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        onSaved()
    }
}
