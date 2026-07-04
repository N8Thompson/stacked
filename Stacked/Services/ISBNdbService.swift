//
//  ISBNdbService.swift
//  Stacked
//
//  Direct ISBNdb client. Sends the Keychain-stored API key in the
//  Authorization header.
//

import Foundation

struct ISBNdbService: BookSearchProvider {
    private let baseURL = URL(string: "https://api2.isbndb.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var apiKey: String? {
        AppSecrets.isbndbAPIKey.isEmpty ? nil : AppSecrets.isbndbAPIKey
    }

    func search(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let key = apiKey, !key.isEmpty else { throw BookSearchError.missingAPIKey }

        guard let url = Self.booksSearchURL(baseURL: baseURL, query: trimmed) else {
            throw BookSearchError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Authorization")

        do {
            let data = try await perform(request)
            let decoded = try JSONDecoder().decode(ISBNdbBooksResponse.self, from: data)
            return (decoded.books ?? []).map { $0.toResult() }.filter { !$0.isbn.isEmpty }
        } catch BookSearchError.http(404) {
            // ISBNdb returns 404 when nothing matches (including multi-word queries).
            return []
        }
    }

    /// Builds `/books/{query}` with the query encoded as a single path segment
    /// (e.g. "harry potter" -> …/books/harry%20potter).
    private static func booksSearchURL(baseURL: URL, query: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        let path = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/books/" + encoded
        return URL(string: path)
    }

    func lookup(isbn: String) async throws -> BookSearchResult? {
        let trimmed = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let key = apiKey, !key.isEmpty else { throw BookSearchError.missingAPIKey }

        let url = baseURL.appendingPathComponent("book").appendingPathComponent(trimmed)
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Authorization")

        do {
            let data = try await perform(request)
            let decoded = try JSONDecoder().decode(ISBNdbBookResponse.self, from: data)
            return decoded.book.toResult()
        } catch BookSearchError.http(404) {
            return nil
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BookSearchError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                throw BookSearchError.http(http.statusCode)
            }
            return data
        } catch let error as BookSearchError {
            throw error
        } catch {
            throw BookSearchError.transport(error.localizedDescription)
        }
    }
}
