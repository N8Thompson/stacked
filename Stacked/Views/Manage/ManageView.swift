//
//  ManageView.swift
//  Stacked
//
//  Paginated, filterable list of the whole collection with search, location /
//  format chips, and an Add action.
//

import SwiftUI
import SwiftData

struct ManageView: View {
    @Environment(AppRouter.self) private var router

    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var searchText = ""
    @State private var selectedLocationIDs: Set<PersistentIdentifier> = []
    @State private var selectedFormatIDs: Set<PersistentIdentifier> = []
    @State private var visibleLimit = 20
    @State private var showAddSheet = false

    private let pageSize = 20

    var body: some View {
        NavigationStack {
            List {
                Section {
                    locationChips
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                Section {
                    formatChips
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if filteredBooks.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookTile(book: book)
                        }
                        .onAppear { loadMoreIfNeeded(currentItem: book) }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search title, author, ISBN")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showAddSheet) {
                AddBookSheet(preselection: addPreselection)
            }
            .onAppear(perform: applyPendingFilter)
            .onChange(of: router.pendingFilter?.locationID) { _, _ in applyPendingFilter() }
            .onChange(of: router.pendingFilter?.formatID) { _, _ in applyPendingFilter() }
            .onChange(of: searchText) { _, _ in visibleLimit = pageSize }
        }
    }

    // MARK: Chips

    private var locationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All Locations", isSelected: selectedLocationIDs.isEmpty, systemImage: "mappin.and.ellipse") {
                    selectedLocationIDs.removeAll()
                    visibleLimit = pageSize
                }
                ForEach(locations) { location in
                    Chip(
                        title: location.name,
                        isSelected: selectedLocationIDs.contains(location.persistentModelID)
                    ) {
                        toggle(location.persistentModelID, in: &selectedLocationIDs)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var formatChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All Formats", isSelected: selectedFormatIDs.isEmpty, systemImage: "tag") {
                    selectedFormatIDs.removeAll()
                    visibleLimit = pageSize
                }
                ForEach(formats) { format in
                    Chip(
                        title: format.name,
                        isSelected: selectedFormatIDs.contains(format.persistentModelID)
                    ) {
                        toggle(format.persistentModelID, in: &selectedFormatIDs)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggle(_ id: PersistentIdentifier, in set: inout Set<PersistentIdentifier>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        visibleLimit = pageSize
    }

    // MARK: Filtering & pagination

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return books.filter { book in
            let matchesLocation = selectedLocationIDs.isEmpty
                || (book.location.map { selectedLocationIDs.contains($0.persistentModelID) } ?? false)
            let matchesFormat = selectedFormatIDs.isEmpty
                || (book.format.map { selectedFormatIDs.contains($0.persistentModelID) } ?? false)
            let matchesSearch = query.isEmpty
                || book.title.lowercased().contains(query)
                || book.authors.lowercased().contains(query)
                || book.isbn.lowercased().contains(query)
            return matchesLocation && matchesFormat && matchesSearch
        }
    }

    private var visibleBooks: [Book] {
        Array(filteredBooks.prefix(visibleLimit))
    }

    private func loadMoreIfNeeded(currentItem: Book) {
        guard let last = visibleBooks.last, last.persistentModelID == currentItem.persistentModelID else { return }
        guard visibleLimit < filteredBooks.count else { return }
        visibleLimit += pageSize
    }

    // MARK: Add preselection

    /// When exactly one non-"All" chip is active, adding pre-selects it.
    private var addPreselection: AddPreselection {
        if selectedLocationIDs.count == 1 && selectedFormatIDs.isEmpty {
            let location = locations.first { selectedLocationIDs.contains($0.persistentModelID) }
            return AddPreselection(location: location, format: nil)
        }
        if selectedFormatIDs.count == 1 && selectedLocationIDs.isEmpty {
            let format = formats.first { selectedFormatIDs.contains($0.persistentModelID) }
            return AddPreselection(location: nil, format: format)
        }
        return AddPreselection(location: nil, format: nil)
    }

    // MARK: Router filter

    private func applyPendingFilter() {
        guard let pending = router.pendingFilter else { return }
        selectedLocationIDs = []
        selectedFormatIDs = []
        if let locationID = pending.locationID { selectedLocationIDs = [locationID] }
        if let formatID = pending.formatID { selectedFormatIDs = [formatID] }
        visibleLimit = pageSize
        router.pendingFilter = nil
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(books.isEmpty ? "No items yet" : "No matches", systemImage: "books.vertical")
        } description: {
            Text(books.isEmpty
                 ? "Tap + to search for a book and add it to your library."
                 : "Try adjusting your search or filters.")
        }
    }
}

/// Passed into the Add sheet so a single active chip pre-selects a target.
struct AddPreselection {
    var location: StorageLocation?
    var format: ItemFormat?
}
