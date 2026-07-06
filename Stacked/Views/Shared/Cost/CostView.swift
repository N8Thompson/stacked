//
//  CostView.swift
//  Stacked
//
//  Aggregate value of the collection with a per-location breakdown and
//  PDF / CSV export suitable for renter's or homeowner's insurance.
//

import SwiftUI

struct CostView: View {
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context

    @State private var pdfURL: URL?
    @State private var csvURL: URL?
    @State private var exportError: String?

    private var books: [Book] { householdManager.allBooks(in: context) }
    private var locations: [StorageLocation] { householdManager.locations }

    var body: some View {
        NavigationStack {
            List {
                totalsSection
                breakdownSection
                exportSection
                if let exportError {
                    Section { Text(exportError).foregroundStyle(StackedTheme.Semantic.destructive).font(.footnote) }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Cost")
            .task(id: signature) { regenerateExports() }
        }
    }

    // MARK: Totals

    private var estimatedTotal: Double { books.totalEstimatedValue }
    private var costTotal: Double { books.totalCost }
    private var totalCopies: Int { books.reduce(0) { $0 + Int($1.copies) } }
    private var showsSplitTotals: Bool { books.hasAnyActualCost }

    private var totalsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if showsSplitTotals {
                    HStack(alignment: .top, spacing: 24) {
                        totalColumn(amount: estimatedTotal, label: "Estimated value")
                        totalColumn(amount: costTotal, label: "Cost")
                    }
                } else {
                    totalColumn(amount: estimatedTotal, label: "Estimated value", large: true)
                }

                Text("\(books.count) unique \(books.count == 1 ? "title" : "titles") · \(totalCopies) total \(totalCopies == 1 ? "copy" : "copies")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private func totalColumn(amount: Double, label: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Formatters.money(amount) ?? "$0.00")
                .font(.system(size: large ? 40 : 32, weight: .bold, design: .rounded))
            Text(label)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Breakdown

    private var breakdownSection: some View {
        Section("By location") {
            ForEach(locations) { location in
                let subset = books.filter { $0.location?.id == location.id }
                if !subset.isEmpty {
                    breakdownRow(
                        name: location.name,
                        copies: subset.reduce(0) { $0 + Int($1.copies) },
                        value: subset.totalCost
                    )
                }
            }
            let unassigned = books.filter { $0.location == nil }
            if !unassigned.isEmpty {
                breakdownRow(
                    name: "Unassigned",
                    copies: unassigned.reduce(0) { $0 + Int($1.copies) },
                    value: unassigned.totalCost
                )
            }
        }
    }

    private func breakdownRow(name: String, copies: Int, value: Double) -> some View {
        LabeledContent {
            Text(Formatters.money(value) ?? "$0.00")
        } label: {
            VStack(alignment: .leading) {
                Text(name)
                Text("\(copies) \(copies == 1 ? "copy" : "copies")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Export

    private var exportSection: some View {
        Section {
            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("Export PDF report", systemImage: "doc.richtext")
                }
            }
            if let csvURL {
                ShareLink(item: csvURL) {
                    Label("Export CSV spreadsheet", systemImage: "tablecells")
                }
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Share a full inventory with values — useful for renter's or homeowner's insurance.")
        }
        .disabled(books.isEmpty)
    }

    // MARK: Regeneration

    private var signature: String {
        "\(books.count)-\(totalCopies)-\(estimatedTotal)-\(costTotal)"
    }

    private func regenerateExports() {
        guard !books.isEmpty else {
            pdfURL = nil; csvURL = nil
            return
        }
        do {
            pdfURL = try ExportService.writePDF(books)
            csvURL = try ExportService.writeCSV(books)
            exportError = nil
        } catch {
            exportError = "Couldn't generate export: \(error.localizedDescription)"
        }
    }
}
