//
//  BookDetailView.swift
//  Stacked
//
//  Single item view. Read-only by default; the Edit toggle unlocks every
//  field except ISBN and the list price. Supports copy inc/decrement, cover
//  override, and delete-with-count.
//

import SwiftUI
import SwiftData
import PhotosUI

struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var isEditing = false
    @State private var showDeleteSheet = false
    @State private var coverItem: PhotosPickerItem?

    var body: some View {
        Form {
            coverSection
            detailsSection
            organizationSection
            pricingSection
            if !book.synopsis.isEmpty || isEditing {
                synopsisSection
            }
            deleteSection
        }
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { try? modelContext.save() }
                    isEditing.toggle()
                }
            }
        }
        .onChange(of: coverItem) { _, newValue in loadCover(newValue) }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteCopiesSheet(book: book) { dismiss() }
                .presentationDetents([.medium])
        }
    }

    // MARK: Cover

    private var coverSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    CoverImageView(book: book, cornerRadius: 8)
                        .frame(width: 130, height: 190)
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
            if !book.binding.isEmpty || isEditing {
                field("Binding", text: $book.binding)
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
                Text(book.isbn.isEmpty ? "—" : book.isbn)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Organization

    private var organizationSection: some View {
        Section("Organization") {
            row("Location") {
                if isEditing {
                    Menu(book.location?.name ?? "Select") {
                        ForEach(locations) { location in
                            Button(location.name) { book.location = location }
                        }
                    }
                } else {
                    Text(book.location?.name ?? "—").foregroundStyle(.secondary)
                }
            }
            row("Format") {
                if isEditing {
                    Menu(book.format?.name ?? "Select") {
                        ForEach(formats) { format in
                            Button(format.name) { book.format = format }
                        }
                    }
                } else {
                    Text(book.format?.name ?? "—").foregroundStyle(.secondary)
                }
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
            // List price shown when there's no actual cost (or always while editing, read-only).
            if book.actualCost == nil || isEditing {
                row("List price") {
                    Text(Formatters.money(book.listPrice) ?? "—").foregroundStyle(.secondary)
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
            if isEditing {
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

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteSheet = true
            } label: {
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

    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { book.coverOverride = data }
            }
        }
    }
}
