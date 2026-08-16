//
//  CSVEscaping.swift
//  Stacked
//

import Foundation

enum CSVEscaping {
    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }
}
