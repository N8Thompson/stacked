//
//  ISBNdbResponse.swift
//  Stacked
//
//  Decodable models for ISBNdb responses, shared by the direct service and the
//  proxy service (which returns ISBNdb-shaped JSON).
//

import Foundation

struct ISBNdbBookResponse: Decodable {
    let book: ISBNdbBook
}

struct ISBNdbBooksResponse: Decodable {
    let total: Int?
    let books: [ISBNdbBook]?
}

struct ISBNdbBook: Decodable {
    let isbn13: String?
    let isbn: String?
    let title: String?
    let titleLong: String?
    let authors: [String]?
    let publisher: String?
    let datePublished: String?
    let image: String?
    let synopsis: String?
    let overview: String?
    let msrp: FlexibleDouble?
    let format: String?
    let binding: String?

    enum CodingKeys: String, CodingKey {
        case isbn13, isbn, title, authors, publisher, image, synopsis, overview, msrp, format, binding
        case titleLong = "title_long"
        case datePublished = "date_published"
    }

    func toResult() -> BookSearchResult {
        BookSearchResult(
            isbn: isbn13 ?? isbn ?? "",
            title: title ?? titleLong ?? "Untitled",
            authors: authors ?? [],
            publisher: publisher ?? "",
            publishedYear: Self.year(from: datePublished),
            coverURL: image ?? "",
            synopsis: (synopsis ?? overview ?? "").strippingHTML(),
            listPrice: msrp?.value.flatMap { $0 > 0 ? $0 : nil } ?? 0,
            binding: binding?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    private static func year(from raw: String?) -> Int? {
        guard let raw else { return nil }
        // Grab the first run of 4 digits, e.g. "2007", "2007-01-01", "January 2007".
        var digits = ""
        for character in raw where character.isNumber {
            digits.append(character)
            if digits.count == 4 { return Int(digits) }
        }
        return nil
    }
}

/// Decodes a value that ISBNdb may return as either a JSON number or string.
struct FlexibleDouble: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string.trimmingCharacters(in: CharacterSet(charactersIn: "$ ")))
        } else {
            value = nil
        }
    }
}

extension String {
    /// Removes basic HTML tags that ISBNdb sometimes embeds in synopses.
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
