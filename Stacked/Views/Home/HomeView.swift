//
//  HomeView.swift
//  Stacked
//
//  Landing screen: horizontal Location tiles over horizontal Format tiles.
//  Tapping a tile jumps to the Library tab pre-filtered to that chip.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var appSettings

    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var showAddSheet = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summaryHeader

                    section(title: "Locations", systemImage: "mappin.and.ellipse") {
                        ForEach(locations) { location in
                            SummaryTile(
                                title: location.name,
                                count: count(for: location),
                                value: value(for: location),
                                systemImage: "books.vertical.fill"
                            ) {
                                router.openManage(location: location)
                            }
                        }
                    }

                    section(title: "Formats", systemImage: "tag") {
                        ForEach(formats) { format in
                            SummaryTile(
                                title: format.name,
                                count: count(for: format),
                                value: value(for: format),
                                systemImage: "square.stack.3d.up.fill"
                            ) {
                                router.openManage(format: format)
                            }
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddBookSheet(preselection: AddPreselection())
            }
        }
    }

    private var summaryHeader: some View {
        let totalCopies = books.reduce(0) { $0 + $1.copies }
        let estimatedTotal = books.totalEstimatedValue
        let costTotal = books.totalCost
        return VStack(alignment: .leading, spacing: 4) {
            Text("Your Collection").font(.title2.bold())
            Text("\(books.count) unique \(books.count == 1 ? "title" : "titles") · \(totalCopies) total \(totalCopies == 1 ? "copy" : "copies")")
                .foregroundStyle(.secondary)
            if appSettings.showCostTracking {
                Text("Estimated value \(Formatters.money(estimatedTotal) ?? "$0.00") · Cost \(Formatters.money(costTotal) ?? "$0.00")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Aggregates

    private func count(for location: StorageLocation) -> Int {
        books.filter { $0.location?.persistentModelID == location.persistentModelID }
            .reduce(0) { $0 + $1.copies }
    }

    private func value(for location: StorageLocation) -> Double {
        books.filter { $0.location?.persistentModelID == location.persistentModelID }
            .reduce(0) { $0 + $1.totalValue }
    }

    private func count(for format: ItemFormat) -> Int {
        books.filter { $0.format?.persistentModelID == format.persistentModelID }
            .reduce(0) { $0 + $1.copies }
    }

    private func value(for format: ItemFormat) -> Double {
        books.filter { $0.format?.persistentModelID == format.persistentModelID }
            .reduce(0) { $0 + $1.totalValue }
    }
}

private struct SummaryTile: View {
    let title: String
    let count: Int
    let value: Double
    let systemImage: String
    let action: () -> Void

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 4)
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(count) \(count == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if appSettings.showCostTracking, value > 0, let money = Formatters.money(value) {
                    Text(money)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 140, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}
