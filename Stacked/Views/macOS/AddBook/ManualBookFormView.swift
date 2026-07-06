//
//  ManualBookFormView.swift
//  Stacked
//
//  Manual item entry for journal articles and other non-catalog items.
//

import SwiftUI

#if os(macOS)
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
    let locationID: UUID?
    let formatID: UUID?
    let bindingID: UUID?

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
        actualCost = draft.actualCostValue
        publishedYear = draft.publishedYearValue
        copies = Int(draft.copies)
        hasCoverOverride = draft.coverOverride != nil
        locationID = location?.id
        formatID = format?.id
        bindingID = binding?.id
    }
}

struct ManualBookFormView: View {
    let preselection: AddPreselection
    @Binding var hasUnsavedChanges: Bool
    var onSaved: () -> Void

    @Environment(\.managedObjectContext) private var context
    @Environment(HouseholdManager.self) private var householdManager

    @State private var draft: Book?
    @State private var selectedLocation: StorageLocation?
    @State private var selectedFormat: ItemFormat?
    @State private var selectedBinding: ItemBinding?
    @State private var taxonomyPicker: TaxonomyKind?
    @State private var validationError: String?
    @State private var didInitDraft = false
    @State private var initialSnapshot: ManualDraftSnapshot?
    @State private var draftWasSaved = false

    private var books: [Book] { householdManager.allBooks(in: context) }
    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }

    private var isValid: Bool {
        guard let draft else { return false }
        return BookFormValidation.isValid(
            title: draft.title,
            authors: draft.authors,
            location: selectedLocation,
            format: selectedFormat
        )
    }

    private var currentSnapshot: ManualDraftSnapshot? {
        guard let draft else { return nil }
        return ManualDraftSnapshot(
            draft: draft,
            location: selectedLocation,
            format: selectedFormat,
            binding: selectedBinding
        )
    }

    var body: some View {
        Group {
            if let draft {
                List {
                    BookFormContent(
                        book: draft,
                        location: locationBinding,
                        format: formatBinding,
                        bindingOption: bindingBinding,
                        isEditing: true,
                        isISBNEditable: true,
                        listPriceEditable: true,
                        showDelete: false,
                        validationError: validationError,
                        taxonomyPicker: $taxonomyPicker
                    )
                }
                .formStyle(.grouped)
                .navigationDestination(item: $taxonomyPicker) { kind in
                    TaxonomyPickerView(
                        kind: kind,
                        selectedLocation: locationBinding,
                        selectedFormat: formatBinding,
                        selectedBinding: bindingBinding
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!isValid)
                    }
                }
            } else {
                ContentUnavailableView("Can't add item", systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear(perform: initDraftIfNeeded)
        .onDisappear(perform: cleanupUnsavedDraft)
        .onChange(of: currentSnapshot) { _, newSnapshot in
            guard let initial = initialSnapshot, let newSnapshot else { return }
            hasUnsavedChanges = newSnapshot != initial
        }
    }

    private var locationBinding: Binding<StorageLocation?> {
        Binding(get: { selectedLocation }, set: { selectedLocation = $0 })
    }

    private var formatBinding: Binding<ItemFormat?> {
        Binding(get: { selectedFormat }, set: { selectedFormat = $0 })
    }

    private var bindingBinding: Binding<ItemBinding?> {
        Binding(get: { selectedBinding }, set: { selectedBinding = $0 })
    }

    private func initDraftIfNeeded() {
        guard !didInitDraft else { return }
        didInitDraft = true

        guard let collection = householdManager.defaultCollection(in: context) else { return }
        draft = Book.create(in: context, collection: collection, isbn: "", title: "", isManualEntry: true)

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

    private func cleanupUnsavedDraft() {
        guard let draft, !draftWasSaved else { return }
        context.delete(draft)
    }

    private func save() {
        guard let draft else { return }
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
            context.delete(draft)
        }

        draftWasSaved = true
        PersistenceController.shared.save()
        hasUnsavedChanges = false
        onSaved()
    }
}
#endif
