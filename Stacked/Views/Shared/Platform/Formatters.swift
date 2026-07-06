//
//  Formatters.swift
//  Stacked
//

import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    static func money(_ value: Double?) -> String? {
        guard let value else { return nil }
        return currency.string(from: NSNumber(value: value))
    }

    static func editableDecimalString(from value: Double?) -> String {
        guard let value else { return "" }
        return editableDecimal.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func parseOptionalDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "." else { return nil }
        return Double(trimmed)
    }

    static func sanitizeDecimalInput(_ raw: String, maxFractionDigits: Int = 2) -> String {
        var result = ""
        var seenDecimal = false
        var fractionDigits = 0

        for character in raw {
            if character.isNumber {
                if seenDecimal {
                    guard fractionDigits < maxFractionDigits else { continue }
                    fractionDigits += 1
                }
                result.append(character)
            } else if character == "." && !seenDecimal {
                seenDecimal = true
                result.append(character)
            }
        }

        return result
    }

    private static let editableDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}
