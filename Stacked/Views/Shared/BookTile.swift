//
//  BookTile.swift
//  Stacked
//
//  Simplified row used in the library list. Shows cover + key details.
//

import SwiftUI

struct BookTile: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoverImageView(book: book)
                .frame(width: 54, height: 80)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                if !book.authors.isEmpty {
                    Text(book.authors)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let format = book.format?.name {
                        Label(format, systemImage: "tag")
                    }
                    if let year = book.publishedYear {
                        Text(String(year))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if book.copies > 1 {
                        Text("×\(book.copies)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.15)))
                    }
                    if let price = Formatters.money(book.effectiveUnitPrice > 0 ? book.effectiveUnitPrice : nil) {
                        Text(price)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
