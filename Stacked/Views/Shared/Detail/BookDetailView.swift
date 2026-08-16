//
//  BookDetailView.swift
//  Stacked
//
//  Single item view. Read-only by default; the Edit toggle unlocks fields.
//  Manual entries allow ISBN editing; catalog items keep ISBN read-only.
//

import SwiftUI

struct BookDetailView: View {
    @ObservedObject var book: Book

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteSheet = false
    @State private var validationError: String?
    @State private var taxonomyPicker: TaxonomyKind?

    private var locationBinding: Binding<StorageLocation?> {
        Binding(get: { book.location }, set: { book.location = $0 })
    }

    private var formatBinding: Binding<ItemFormat?> {
        Binding(get: { book.format }, set: { book.format = $0 })
    }

    private var bindingOptionBinding: Binding<ItemBinding?> {
        Binding(get: { book.bindingOption }, set: { book.bindingOption = $0 })
    }

    var body: some View {
        detailForm
            .navigationDestination(item: $taxonomyPicker) { kind in
                TaxonomyPickerView(
                    kind: kind,
                    selectedLocation: locationBinding,
                    selectedFormat: formatBinding,
                    selectedBinding: bindingOptionBinding
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
                    #if os(iOS)
                    .presentationDetents([.medium])
                    #endif
            }
    }

    @ViewBuilder
    private var detailForm: some View {
        #if os(macOS)
        // Grouped List scrolls reliably on Mac; Form often clips in NavigationSplitView.
        List {
            formContent
        }
        .formStyle(.grouped)
        #else
        Form {
            formContent
        }
        #endif
    }

    private var formContent: some View {
        BookFormContent(
            book: book,
            location: locationBinding,
            format: formatBinding,
            bindingOption: bindingOptionBinding,
            isEditing: isEditing,
            isISBNEditable: book.isManualEntry,
            listPriceEditable: book.isManualEntry,
            showDelete: true,
            validationError: validationError,
            onDelete: { showDeleteSheet = true },
            taxonomyPicker: $taxonomyPicker
        )
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
        PersistenceController.shared.save()
        return true
    }
}
