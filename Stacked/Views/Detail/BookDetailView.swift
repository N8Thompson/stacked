//
//  BookDetailView.swift
//  Stacked
//
//  Single item view. Read-only by default; the Edit toggle unlocks fields.
//  Manual entries allow ISBN editing; catalog items keep ISBN read-only.
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteSheet = false
    @State private var validationError: String?
    @State private var taxonomyPicker: TaxonomyKind?

    var body: some View {
        Form {
            BookFormContent(
                book: book,
                location: $book.location,
                format: $book.format,
                bindingOption: $book.bindingOption,
                isEditing: isEditing,
                isISBNEditable: book.isManualEntry,
                listPriceEditable: book.isManualEntry,
                showDelete: true,
                validationError: validationError,
                onDelete: { showDeleteSheet = true },
                taxonomyPicker: $taxonomyPicker
            )
        }
        .navigationDestination(item: $taxonomyPicker) { kind in
            TaxonomyPickerView(
                kind: kind,
                selectedLocation: $book.location,
                selectedFormat: $book.format,
                selectedBinding: $book.bindingOption
            )
        }
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        guard saveEdits() else { return }
                    } else {
                        validationError = nil
                    }
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteCopiesSheet(book: book) { dismiss() }
                .presentationDetents([.medium])
        }
    }

    private func saveEdits() -> Bool {
        guard BookFormValidation.isValid(
            title: book.title,
            authors: book.authors,
            location: book.location,
            format: book.format
        ) else {
            validationError = "Title, authors, location, and format are required."
            return false
        }
        validationError = nil
        book.isbn = book.isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        return true
    }
}
