//
//  SearchSource.swift
//  Stacked
//

import SwiftUI

enum SearchSource: String, CaseIterable, Identifiable {
    case text
    case scanBarcode
    case scanText
    case manual

    var id: String { rawValue }

    /// Short label for the mode picker at the top of the add sheet.
    var segmentTitle: String {
        switch self {
        case .text: return "Text"
        case .scanBarcode: return "Barcode"
        case .scanText: return "Cover"
        case .manual: return "Manual"
        }
    }

    static var addSheetSources: [SearchSource] {
        #if os(macOS)
        [.text, .manual]
        #else
        allCases
        #endif
    }
}
