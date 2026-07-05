//
//  SearchResultRow.swift
//  Stacked
//
//  A single search result with cover, details, a count stepper, and an
//  add / add-another-copy action. Mirrors the reference "− 1 + ADD n COPY".
//

import SwiftUI

struct SearchResultRow: View {
    let result: BookSearchResult
    /// Number of copies of this ISBN already owned (0 if new).
    let ownedCopies: Int
    let onAdd: (Int) -> Void

    @Environment(AppSettings.self) private var appSettings
    @State private var count = 1
    @State private var justAdded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                CoverImageView(urlString: result.coverURL, maxWidth: 60, maxHeight: 88)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title).font(.headline).lineLimit(3)
                    if !result.authorsText.isEmpty {
                        Text(result.authorsText)
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if !detailLine.isEmpty {
                        Text(detailLine)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if appSettings.showCostTracking,
                       result.listPrice > 0,
                       let price = Formatters.money(result.listPrice) {
                        Text(price).font(.caption).foregroundStyle(.secondary)
                    }
                    if ownedCopies > 0 {
                        Label("In your library (×\(ownedCopies))", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack {
                CountStepper(count: $count)
                Spacer()
                Button {
                    onAdd(count)
                    justAdded = true
                } label: {
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(result.isbn.isEmpty)
            }
        }
        .padding(.vertical, 6)
    }

    private var detailLine: String {
        [result.publisher, result.publishedYear.map(String.init), result.binding]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var buttonTitle: String {
        if justAdded { return "Added" }
        if ownedCopies > 0 {
            return count == 1 ? "Add another copy" : "Add \(count) copies"
        }
        return count == 1 ? "Add 1 copy" : "Add \(count) copies"
    }
}
