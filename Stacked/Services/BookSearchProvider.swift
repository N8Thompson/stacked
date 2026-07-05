//
//  BookSearchProvider.swift
//  Stacked
//
//  Abstraction over the book metadata source. Two implementations exist:
//  ISBNdbService (direct) and ProxyBookSearchService (our backend). The active
//  provider is chosen by `Backend.current`.
//

import Foundation

/// A simplified, provider-agnostic search result used across the UI.
struct BookSearchResult: Identifiable, Hashable {
    var id: String { isbn.isEmpty ? UUID().uuidString : isbn }

    var isbn: String
    var title: String
    var authors: [String]
    var publisher: String
    var publishedYear: Int?
    var coverURL: String
    var synopsis: String
    var listPrice: Double
    /// Physical edition from the catalog (e.g. Paperback, Hardcover).
    var binding: String?

    var authorsText: String {
        authors.joined(separator: ", ")
    }
}

enum BookSearchError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case http(Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Book search isn't configured yet. Add the ISBNdb key in AppSecrets.swift."
        case .invalidResponse:
            return "The search service returned an unexpected response."
        case .http(let code):
            return "The search service returned an error (HTTP \(code))."
        case .transport(let message):
            return message
        }
    }
}

protocol BookSearchProvider {
    /// Free-text search (title / author / keyword). May return many results.
    func search(query: String) async throws -> [BookSearchResult]
    /// Single lookup by ISBN. Returns at most one result.
    func lookup(isbn: String) async throws -> BookSearchResult?
}

enum BookSearchProviderFactory {
    /// Returns the provider for the currently configured backend.
    static func make() -> BookSearchProvider {
        switch Backend.current {
        case .directISBNdb:
            return ISBNdbService()
        case .proxy(let baseURL):
            return ProxyBookSearchService(baseURL: baseURL)
        }
    }
}
