//
//  ExportService.swift
//  Stacked
//
//  Builds insurance-ready CSV and PDF inventory files. Uses CoreText +
//  CoreGraphics so it works identically on iOS and macOS.
//

import Foundation
import CoreText
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ExportService {
    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    private static func money(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    // MARK: CSV

    static func csvData(from books: [Book]) -> Data {
        var rows = ["Title,Authors,ISBN,Format,Location,Copies,Unit Value,Total Value,Cost Basis"]
        for book in books.sorted(by: { $0.title < $1.title }) {
            let basis = book.actualCost != nil ? "Actual" : (book.listPrice != nil ? "List" : "None")
            let fields = [
                book.title,
                book.authors,
                book.isbn,
                book.format?.name ?? "",
                book.location?.name ?? "",
                String(book.copies),
                String(format: "%.2f", book.effectiveUnitPrice),
                String(format: "%.2f", book.totalValue),
                basis,
            ]
            rows.append(fields.map(escapeCSV).joined(separator: ","))
        }
        let total = books.reduce(0) { $0 + $1.totalValue }
        rows.append("")
        rows.append("Grand Total,,,,,,,\(String(format: "%.2f", total)),")
        return Data(rows.joined(separator: "\n").utf8)
    }

    private static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func writeCSV(_ books: [Book]) throws -> URL {
        let url = tempURL(name: "Stacked-Inventory", ext: "csv")
        try csvData(from: books).write(to: url)
        return url
    }

    // MARK: PDF

    static func writePDF(_ books: [Book]) throws -> URL {
        let url = tempURL(name: "Stacked-Inventory", ext: "pdf")
        let attributed = pdfAttributedString(from: books)

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw BookSearchError.transport("Could not create PDF context.")
        }

        let margin: CGFloat = 40
        let textRect = mediaBox.insetBy(dx: margin, dy: margin)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

        var currentRange = CFRange(location: 0, length: 0)
        let total = attributed.length

        repeat {
            context.beginPDFPage(nil)
            // Flip coordinates so text renders top-down.
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGPath(rect: CGRect(
                x: textRect.minX,
                y: mediaBox.height - textRect.maxY,
                width: textRect.width,
                height: textRect.height
            ), transform: nil)

            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length
            context.endPDFPage()
        } while currentRange.location < total

        context.closePDF()
        return url
    }

    private static func pdfAttributedString(from books: [Book]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 22, nil)
        let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 13, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let smallFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)

        func append(_ text: String, font: CTFont, spacingAfter: CGFloat = 4) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = spacingAfter
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                .paragraphStyle: style,
            ]
            result.append(NSAttributedString(string: text + "\n", attributes: attrs))
        }

        let dateText = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)
        let totalValue = books.reduce(0) { $0 + $1.totalValue }
        let totalCopies = books.reduce(0) { $0 + $1.copies }

        append("Stacked — Library Inventory", font: titleFont, spacingAfter: 6)
        append("Generated \(dateText)", font: smallFont, spacingAfter: 2)
        append("\(books.count) titles · \(totalCopies) copies · Estimated value \(money(totalValue))",
               font: smallFont, spacingAfter: 14)

        for book in books.sorted(by: { $0.title < $1.title }) {
            append(book.title, font: headerFont, spacingAfter: 1)
            if !book.authors.isEmpty {
                append("by \(book.authors)", font: smallFont, spacingAfter: 1)
            }
            var meta: [String] = []
            if let format = book.format?.name { meta.append(format) }
            if let location = book.location?.name { meta.append(location) }
            meta.append("Copies: \(book.copies)")
            if !book.isbn.isEmpty { meta.append("ISBN \(book.isbn)") }
            append(meta.joined(separator: "  ·  "), font: bodyFont, spacingAfter: 1)

            let basis = book.actualCost != nil ? "actual" : "list"
            append("Unit \(money(book.effectiveUnitPrice)) (\(basis))  ·  Total \(money(book.totalValue))",
                   font: bodyFont, spacingAfter: 12)
        }

        return result
    }

    private static func tempURL(name: String, ext: String) -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(stamp).\(ext)")
    }
}
