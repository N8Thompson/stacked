//
//  ManageView.swift
//  Stacked
//
//  Paginated, filterable list of the whole collection with search, location /
//  format chips, and an Add action.
//

import SwiftUI

struct ManageView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context

    @State private var searchText = ""
    @State private var selectedLocationIDs: Set<UUID> = []
    @State private var selectedFormatIDs: Set<UUID> = []
    @State private var visibleLimit = 20
    @State private var showAddSheet = false

    private let pageSize = 20

    private var books: [Book] { householdManager.allBooks(in: context) }
    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsFilterChips {
                    filterChips
                        .background(StackedTheme.Background.primary)

                    Divider()
                }

                #if os(macOS)
                if filteredBooks.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookList
                }
                #else
                bookList
                #endif
            }
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
            .addBookSheet(isPresented: $showAddSheet, preselection: addPreselection)
            .onAppear(perform: applyPendingFilter)
            .onChange(of: router.pendingFilter?.locationID) { _, _ in applyPendingFilter() }
            .onChange(of: router.pendingFilter?.formatID) { _, _ in applyPendingFilter() }
            .onChange(of: searchText) { _, _ in visibleLimit = pageSize }
        }
    }

    private var bookList: some View {
        List {
            #if os(iOS)
            if filteredBooks.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
            } else {
                bookRows
            }
            #else
            bookRows
            #endif
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var bookRows: some View {
        ForEach(visibleBooks) { book in
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                BookTile(
                    book: book,
                    showFormatChip: shouldShowFormatChipOnItems,
                    showLocationChip: shouldShowLocationChipOnItems
                )
            }
            .onAppear { loadMoreIfNeeded(currentItem: book) }
        }
    }

    // MARK: Chips

    private var showsFilterChips: Bool {
        locations.count > 1 || formats.count > 1
    }

    private var filterChips: some View {
        VStack(spacing: 8) {
            if locations.count > 1 {
                locationChips
            }
            if formats.count > 1 {
                formatChips
            }
        }
        .padding(.vertical, 6)
    }

    private var shouldShowLocationChipOnItems: Bool {
        locations.count > 1 && selectedLocationIDs.count != 1
    }

    private var shouldShowFormatChipOnItems: Bool {
        formats.count > 1 && selectedFormatIDs.count != 1
    }

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
                        isSelected: selectedLocationIDs.contains(location.id)
                    ) {
                        toggleLocation(location.id)
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
                        isSelected: selectedFormatIDs.contains(format.id)
                    ) {
                        toggleFormat(format.id)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleLocation(_ id: UUID) {
        toggle(id, in: &selectedLocationIDs, allIDs: Set(locations.map(\.id)))
    }

    private func toggleFormat(_ id: UUID) {
        toggle(id, in: &selectedFormatIDs, allIDs: Set(formats.map(\.id)))
    }

    private func toggle(_ id: UUID, in set: inout Set<UUID>, allIDs: Set<UUID>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
            if set == allIDs {
                set.removeAll()
            }
        }
        visibleLimit = pageSize
    }

    // MARK: Filtering & pagination

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return books.filter { book in
            let matchesLocation = selectedLocationIDs.isEmpty
                || (book.location.map { selectedLocationIDs.contains($0.id) } ?? false)
            let matchesFormat = selectedFormatIDs.isEmpty
                || (book.format.map { selectedFormatIDs.contains($0.id) } ?? false)
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
        guard let last = visibleBooks.last, last.id == currentItem.id else { return }
        guard visibleLimit < filteredBooks.count else { return }
        visibleLimit += pageSize
    }

    private var addPreselection: AddPreselection {
        if selectedLocationIDs.count == 1 && selectedFormatIDs.isEmpty {
            let location = locations.first { selectedLocationIDs.contains($0.id) }
            return AddPreselection(location: location, format: nil)
        }
        if selectedFormatIDs.count == 1 && selectedLocationIDs.isEmpty {
            let format = formats.first { selectedFormatIDs.contains($0.id) }
            return AddPreselection(location: nil, format: format)
        }
        return AddPreselection(location: nil, format: nil)
    }

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
