//
//  BookTile.swift
//  Stacked
//
//  Simplified row used in the library list. Shows cover + key details.
//

import SwiftUI

struct BookTile: View {
    let book: Book
    var showFormatChip = false
    var showLocationChip = false

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoverImageView(book: book, maxWidth: 54, maxHeight: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                if !book.authors.isEmpty {
                    Text(book.authors)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let year = book.publishedYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if book.copies > 1 {
                        Text("×\(book.copies)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.15)))
                    }
                    if appSettings.showCostTracking,
                       let price = Formatters.money(book.effectiveUnitPrice > 0 ? book.effectiveUnitPrice : nil) {
                        Text(price)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showFormatChip || showLocationChip {
                    HStack(spacing: 6) {
                        if showFormatChip, let format = book.format?.name {
                            metadataChip(format)
                        }
                        if showLocationChip, let location = book.location?.name {
                            metadataChip(location)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func metadataChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
    }
}
