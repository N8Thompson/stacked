//
//  BookFormContent.swift
//  Stacked
//
//  Shared form sections for book detail edit and manual add.
//

import SwiftUI
import SwiftData
import PhotosUI

struct BookFormContent: View {
    @Bindable var book: Book
    @Binding var location: StorageLocation?
    @Binding var format: ItemFormat?
    @Binding var bindingOption: ItemBinding?

    @Environment(AppSettings.self) private var appSettings

    let isEditing: Bool
    let isISBNEditable: Bool
    let listPriceEditable: Bool
    let showDelete: Bool
    var validationError: String?
    var onDelete: (() -> Void)?

    @State private var coverItem: PhotosPickerItem?
    @Binding var taxonomyPicker: TaxonomyKind?

    var body: some View {
        Group {
            coverSection
            detailsSection
            if hasReviewContent {
                reviewSection
            }
            organizationSection
            if appSettings.showCostTracking {
                pricingSection
            }
            if !book.synopsis.isEmpty || isEditing {
                synopsisSection
            }
            if showDelete, let onDelete {
                deleteSection(onDelete: onDelete)
            }
            if let validationError, !validationError.isEmpty {
                Section {
                    Text(validationError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: coverItem) { _, newValue in loadCover(newValue) }
    }

    // MARK: Cover

    private var coverSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    CoverImageView(book: book, cornerRadius: 8, maxWidth: 130, maxHeight: 190)
                    if isEditing {
                        PhotosPicker(selection: $coverItem, matching: .images) {
                            Label("Change cover", systemImage: "photo")
                                .font(.footnote)
                        }
                        if book.coverOverride != nil {
                            Button("Remove custom cover", role: .destructive) {
                                book.coverOverride = nil
                            }
                            .font(.footnote)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        Section("Details") {
            field("Title", text: $book.title)
            field("Authors", text: $book.authors)
            field("Publisher", text: $book.publisher)
            TaxonomyPickerRow(
                label: "Binding",
                value: bindingOption?.name ?? "",
                placeholder: "Select",
                isEditing: isEditing
            ) {
                taxonomyPicker = .binding
            }
            row("Year") {
                if isEditing {
                    TextField("Year", text: yearBinding)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(book.publishedYear.map(String.init) ?? "—").foregroundStyle(.secondary)
                }
            }
            row("ISBN") {
                if isEditing && isISBNEditable {
                    TextField("Optional", text: $book.isbn)
                        #if os(iOS)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(book.isbn.isEmpty ? "—" : book.isbn)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var hasReviewContent: Bool {
        isEditing || book.rating > 0 || !book.reviewNotes.isEmpty
    }

    // MARK: Review

    private var reviewSection: some View {
        Section {
            LabeledContent("Rating") {
                StarRatingView(rating: $book.rating, isEditable: isEditing)
            }
            if isEditing || !book.reviewNotes.isEmpty {
                if isEditing {
                    TextField("Notes", text: $book.reviewNotes, axis: .vertical)
                        .lineLimit(3...12)
                } else {
                    Text(book.reviewNotes)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } header: {
            Text("Review")
        } footer: {
            if isEditing {
                Text("Personal rating and notes — only visible to you in this app.")
            }
        }
    }

    // MARK: Organization

    private var organizationSection: some View {
        Section("Organization") {
            TaxonomyPickerRow(
                label: "Location",
                value: location?.name ?? "",
                placeholder: "Select",
                isEditing: isEditing
            ) {
                taxonomyPicker = .location
            }
            TaxonomyPickerRow(
                label: "Format",
                value: format?.name ?? "",
                placeholder: "Select",
                isEditing: isEditing
            ) {
                taxonomyPicker = .format
            }
            row("Copies") {
                if isEditing {
                    CountStepper(count: $book.copies)
                } else {
                    Text("\(book.copies)").foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Pricing

    private var pricingSection: some View {
        Section {
            row("List price") {
                if isEditing && listPriceEditable {
                    TextField("0.00", text: listPriceBinding)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(Formatters.money(book.listPrice) ?? "$0.00").foregroundStyle(.secondary)
                }
            }
            row("Amount you paid") {
                if isEditing {
                    TextField("Optional", text: actualCostBinding)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(Formatters.money(book.actualCost) ?? "Not set").foregroundStyle(.secondary)
                }
            }
            if book.copies > 1, book.totalValue > 0 {
                row("Total value") {
                    Text(Formatters.money(book.totalValue) ?? "—").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Value")
        } footer: {
            if isEditing && !listPriceEditable {
                Text("List price comes from the search service and can't be edited. Enter what you paid to override it for cost reports.")
            }
        }
    }

    // MARK: Synopsis

    private var synopsisSection: some View {
        Section("Synopsis") {
            if isEditing {
                TextField("Synopsis", text: $book.synopsis, axis: .vertical)
                    .lineLimit(3...10)
            } else {
                Text(book.synopsis).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Delete

    private func deleteSection(onDelete: @escaping () -> Void) -> some View {
        Section {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>) -> some View {
        row(label) {
            if isEditing {
                TextField(label, text: text).multilineTextAlignment(.trailing)
            } else {
                Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue).foregroundStyle(.secondary)
            }
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent(label) { content() }
    }

    private var yearBinding: Binding<String> {
        Binding(
            get: { book.publishedYear.map(String.init) ?? "" },
            set: { book.publishedYear = Int($0.filter(\.isNumber)) }
        )
    }

    private var actualCostBinding: Binding<String> {
        Binding(
            get: { book.actualCost.map { String(format: "%.2f", $0) } ?? "" },
            set: { book.actualCost = Double($0.filter { $0.isNumber || $0 == "." }) }
        )
    }

    private var listPriceBinding: Binding<String> {
        Binding(
            get: {
                book.listPrice == 0 ? "" : String(format: "%.2f", book.listPrice)
            },
            set: {
                let parsed = Double($0.filter { $0.isNumber || $0 == "." })
                book.listPrice = parsed ?? 0
            }
        )
    }

    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { book.coverOverride = data }
            }
        }
    }
}
