//
//  CostView.swift
//  Stacked
//
//  Aggregate value of the collection with a per-location breakdown and
//  PDF / CSV export suitable for renter's or homeowner's insurance.
//

import SwiftUI
import SwiftData

struct CostView: View {
    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]

    @State private var pdfURL: URL?
    @State private var csvURL: URL?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            List {
                totalsSection
                breakdownSection
                exportSection
                if let exportError {
                    Section { Text(exportError).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Cost")
            .task(id: signature) { regenerateExports() }
        }
    }

    // MARK: Totals

    private var grandTotal: Double { books.reduce(0) { $0 + $1.totalValue } }
    private var totalCopies: Int { books.reduce(0) { $0 + $1.copies } }
    private var actualCount: Int { books.filter { $0.actualCost != nil }.count }

    private var totalsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(Formatters.money(grandTotal) ?? "$0.00")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Estimated total value")
                    .foregroundStyle(.secondary)
                Text("\(books.count) titles · \(totalCopies) copies · \(actualCount) with actual cost")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Breakdown

    private var breakdownSection: some View {
        Section("By location") {
            ForEach(locations) { location in
                let subset = books.filter { $0.location?.persistentModelID == location.persistentModelID }
                if !subset.isEmpty {
                    breakdownRow(
                        name: location.name,
                        copies: subset.reduce(0) { $0 + $1.copies },
                        value: subset.reduce(0) { $0 + $1.totalValue }
                    )
                }
            }
            let unassigned = books.filter { $0.location == nil }
            if !unassigned.isEmpty {
                breakdownRow(
                    name: "Unassigned",
                    copies: unassigned.reduce(0) { $0 + $1.copies },
                    value: unassigned.reduce(0) { $0 + $1.totalValue }
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

    /// Changes whenever the collection's value-relevant state changes.
    private var signature: String {
        "\(books.count)-\(totalCopies)-\(grandTotal)"
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
