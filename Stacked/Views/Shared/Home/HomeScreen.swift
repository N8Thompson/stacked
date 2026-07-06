//
//  HomeScreen.swift
//  Stacked
//
//  Shared home scroll content: collection summary and location/format tiles.
//

import SwiftUI

struct HomeScreen<Banner: View>: View {
    @ViewBuilder var banner: () -> Banner

    @Environment(AppRouter.self) private var router
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context

    private var books: [Book] { householdManager.allBooks(in: context) }
    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner()
                #if os(iOS)
                summaryHeader
                #endif

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
        .scrollContentBackground(.hidden)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Collection")
                .font(.title2.bold())
                .foregroundStyle(StackedTheme.Text.primary)
            CollectionSummaryStats()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(StackedTheme.Text.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func count(for location: StorageLocation) -> Int {
        books.filter { $0.location?.id == location.id }
            .reduce(0) { $0 + Int($1.copies) }
    }

    private func value(for location: StorageLocation) -> Double {
        books.filter { $0.location?.id == location.id }
            .reduce(0) { $0 + $1.totalValue }
    }

    private func count(for format: ItemFormat) -> Int {
        books.filter { $0.format?.id == format.id }
            .reduce(0) { $0 + Int($1.copies) }
    }

    private func value(for format: ItemFormat) -> Double {
        books.filter { $0.format?.id == format.id }
            .reduce(0) { $0 + $1.totalValue }
    }
}

struct SummaryTile: View {
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
                    .foregroundStyle(StackedTheme.accent)
                Spacer(minLength: 4)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(StackedTheme.Text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(count) \(count == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
                if appSettings.showCostTracking, value > 0, let money = Formatters.money(value) {
                    Text(money)
                        .font(.caption)
                        .foregroundStyle(StackedTheme.Text.tertiary)
                }
            }
            .frame(width: 150, height: 140, alignment: .leading)
            .padding()
            .stackedCardStyle(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

extension HomeScreen where Banner == EmptyView {
    init() {
        self.banner = { EmptyView() }
    }
}

struct CollectionSummaryStats: View {
    enum Style {
        case inline
        case sidebar
    }

    var style: Style = .inline

    @Environment(AppSettings.self) private var appSettings
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context

    private var books: [Book] { householdManager.allBooks(in: context) }

    var body: some View {
        let totalCopies = books.reduce(0) { $0 + Int($1.copies) }
        let estimatedTotal = books.totalEstimatedValue
        let costTotal = books.totalCost

        switch style {
        case .inline:
            inlineBody(totalCopies: totalCopies, estimatedTotal: estimatedTotal, costTotal: costTotal)
        case .sidebar:
            sidebarBody(totalCopies: totalCopies, estimatedTotal: estimatedTotal, costTotal: costTotal)
        }
    }

    private func inlineBody(totalCopies: Int, estimatedTotal: Double, costTotal: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(books.count) unique \(books.count == 1 ? "title" : "titles") · \(totalCopies) total \(totalCopies == 1 ? "copy" : "copies")")
                .foregroundStyle(StackedTheme.Text.secondary)
            if appSettings.showCostTracking {
                Text("Estimated value \(Formatters.money(estimatedTotal) ?? "$0.00") · Cost \(Formatters.money(costTotal) ?? "$0.00")")
                    .foregroundStyle(StackedTheme.Text.secondary)
            }
        }
    }

    private func sidebarBody(totalCopies: Int, estimatedTotal: Double, costTotal: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                sidebarStat(value: "\(books.count)", label: books.count == 1 ? "Title" : "Titles")
                sidebarStat(value: "\(totalCopies)", label: totalCopies == 1 ? "Copy" : "Copies")
            }

            if appSettings.showCostTracking {
                Divider()
                    .overlay(StackedTheme.Border.subtle)

                sidebarMoneyRow(label: "Est. value", value: Formatters.money(estimatedTotal) ?? "$0.00")
                sidebarMoneyRow(label: "Cost", value: Formatters.money(costTotal) ?? "$0.00")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StackedTheme.Surface.muted.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
        }
    }

    private func sidebarStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(StackedTheme.Text.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(StackedTheme.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sidebarMoneyRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(StackedTheme.Text.tertiary)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(StackedTheme.Text.secondary)
        }
    }
}
