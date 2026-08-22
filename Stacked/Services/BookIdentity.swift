//
//  BookIdentity.swift
//  Stacked
//
//  Stable matching for ISBN and manual records across add, import, and merge flows.
//

import Foundation

enum BookIdentity {
    static func key(isbn: String, title: String, authors: String, publishedYear: Int?) -> String {
        if let isbn = canonicalISBN(isbn) ?? normalizedISBN(isbn) {
            return "isbn:\(isbn)"
        }
        return "manual:\(normalizedText(title))|\(normalizedText(authors))|\(publishedYear.map(String.init) ?? "")"
    }

    static func normalizedISBN(_ raw: String) -> String? {
        let compact = raw.uppercased().filter { $0.isNumber || $0 == "X" }
        return compact.count == 10 || compact.count == 13 ? compact : nil
    }

    static func canonicalISBN(_ raw: String) -> String? {
        guard let compact = normalizedISBN(raw) else { return nil }
        if compact.count == 13 {
            return isValidISBN13(compact) ? compact : nil
        }
        guard isValidISBN10(compact) else { return nil }
        let stem = "978" + compact.dropLast()
        return stem + String(isbn13CheckDigit(String(stem)))
    }

    static func normalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func isValidISBN10(_ isbn: String) -> Bool {
        guard isbn.count == 10 else { return false }
        let characters = Array(isbn)
        var sum = 0
        for index in 0..<10 {
            let value: Int
            if index == 9, characters[index] == "X" {
                value = 10
            } else if let digit = characters[index].wholeNumberValue {
                value = digit
            } else {
                return false
            }
            sum += (10 - index) * value
        }
        return sum % 11 == 0
    }

    private static func isValidISBN13(_ isbn: String) -> Bool {
        guard isbn.count == 13, isbn.allSatisfy(\.isNumber) else { return false }
        let digits = isbn.compactMap(\.wholeNumberValue)
        let weighted = digits.enumerated().reduce(0) { result, pair in
            result + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return weighted % 10 == 0
    }

    private static func isbn13CheckDigit(_ stem: String) -> Int {
        let weighted = stem.compactMap(\.wholeNumberValue).enumerated().reduce(0) { result, pair in
            result + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return (10 - weighted % 10) % 10
    }
}
