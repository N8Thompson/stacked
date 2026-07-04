//
//  PlatformSupport.swift
//  Stacked
//
//  Small cross-platform helpers for images and formatting.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    /// Builds a SwiftUI Image from raw image data, or nil if it can't be decoded.
    init?(data: Data) {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #endif
    }
}

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
}
