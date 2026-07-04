//
//  ProxyBookSearchService.swift
//  Stacked
//
//  Routes searches through our rate-limiting backend. The backend returns
//  ISBNdb-shaped JSON, so decoding is shared with ISBNdbService. Built now but
//  not active until Backend.current is switched to .proxy(...).
//

import Foundation

struct ProxyBookSearchService: BookSearchProvider {
    let baseURL: URL
    /// Optional shared secret matching the backend's PROXY_API_KEY.
    var proxyAPIKey: String?
    private let session: URLSession

    init(baseURL: URL, proxyAPIKey: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.proxyAPIKey = proxyAPIKey
        self.session = session
    }

    func search(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let url = Self.booksSearchURL(baseURL: baseURL, query: trimmed) else {
            throw BookSearchError.invalidResponse
        }
        do {
            let data = try await perform(url)
            let decoded = try JSONDecoder().decode(ISBNdbBooksResponse.self, from: data)
            return (decoded.books ?? []).map { $0.toResult() }.filter { !$0.isbn.isEmpty }
        } catch BookSearchError.http(404) {
            return []
        }
    }

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
        let url = baseURL.appendingPathComponent("book").appendingPathComponent(trimmed)
        do {
            let data = try await perform(url)
            let decoded = try JSONDecoder().decode(ISBNdbBookResponse.self, from: data)
            return decoded.book.toResult()
        } catch BookSearchError.http(404) {
            return nil
        }
    }

    private func perform(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if let proxyAPIKey, !proxyAPIKey.isEmpty {
            request.setValue(proxyAPIKey, forHTTPHeaderField: "x-api-key")
        }
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
