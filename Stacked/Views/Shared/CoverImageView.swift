//
//  CoverImageView.swift
//  Stacked
//
//  Renders a book cover from user-supplied override data, a remote URL, or a
//  placeholder, in that order of preference.
//

import SwiftUI

struct CoverImageView: View {
    let overrideData: Data?
    let urlString: String?
    var cornerRadius: CGFloat = 6

    init(overrideData: Data? = nil, urlString: String? = nil, cornerRadius: CGFloat = 6) {
        self.overrideData = overrideData
        self.urlString = urlString
        self.cornerRadius = cornerRadius
    }

    init(book: Book, cornerRadius: CGFloat = 6) {
        self.overrideData = book.coverOverride
        self.urlString = book.coverURL
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let overrideData, let image = Image(data: overrideData) {
                image.resizable().scaledToFill()
            } else if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack { placeholder; ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
