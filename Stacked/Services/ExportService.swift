//
//  ExportService.swift
//  Stacked
//
//  Builds insurance-ready CSV and PDF inventory files.
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ExportService {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 40
    private static let contentWidth: CGFloat = pageWidth - 80

    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    private static func money(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static func bookPricingLines(for book: Book) -> (listLine: String, actualLine: String) {
        let listLine = "List price: Unit \(money(book.listPrice)) · Total \(money(book.totalListValue))"
        let actualLine: String
        if let actual = book.actualCostValue {
            let actualTotal = actual * Double(book.copies)
            actualLine = "Actual cost: Unit \(money(actual)) · Total \(money(actualTotal))"
        } else {
            actualLine = "Actual cost: Not reported"
        }
        return (listLine, actualLine)
    }

    private static let logoSize: CGFloat = 56
    private static let logoTitleGap: CGFloat = 12

    private static let pricingExplanation = """
    List Price is obtained from the book catalog and cannot be modified by Stacked users. It represents the publisher's suggested retail price (MSRP) and serves as an estimated value when the owner has not provided the amount paid for the item.

    Actual Cost is the amount the owner reports having paid for their specific copy of the book. This value may differ from the List Price due to discounts, sales, collector premiums, or market conditions.
    """

    // Semantic UI colors resolve poorly in PDFs; use fixed print-friendly values.
    #if canImport(UIKit)
    private static let pdfPrimaryText = UIColor.black
    private static let pdfSecondaryText = UIColor(white: 0.25, alpha: 1)
    #elseif canImport(AppKit)
    private static let pdfPrimaryText = NSColor.black
    private static let pdfSecondaryText = NSColor(white: 0.25, alpha: 1)
    #endif

    // MARK: CSV

    static func csvData(from books: [Book]) -> Data {
        var rows = ["Title,Authors,ISBN,Format,Location,Copies,Unit Value,Total Value,Cost Basis"]
        for book in books.sorted(by: { $0.title < $1.title }) {
            let basis = book.actualCostValue != nil ? "Actual" : (book.listPrice > 0 ? "List" : "None")
            let fields = [
                book.title,
                book.authors,
                book.isbn,
                book.format?.name ?? "",
                book.location?.name ?? "",
                String(Int(book.copies)),
                String(format: "%.2f", book.effectiveUnitPrice),
                String(format: "%.2f", book.totalValue),
                basis,
            ]
            rows.append(fields.map(escapeCSV).joined(separator: ","))
        }
        let total = books.totalCost
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
        #if canImport(UIKit)
        let data = pdfDataUIKit(from: books)
        #elseif canImport(AppKit)
        let data = try pdfDataAppKit(from: books)
        #else
        throw BookSearchError.transport("PDF export is not supported on this platform.")
        #endif
        try data.write(to: url)
        return url
    }

    // MARK: iOS PDF

    #if canImport(UIKit)
    private static func pdfDataUIKit(from books: [Book]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var cursorY = margin
            context.beginPage()
            cursorY = drawLogoAndTitleUIKit(at: cursorY)
            drawTextUIKit(
                pricingExplanation,
                cursorY: &cursorY,
                font: .systemFont(ofSize: 10),
                color: pdfPrimaryText,
                spacingAfter: 24,
                context: context
            )
            drawInventoryHeaderUIKit(books: books, cursorY: &cursorY, context: context)
            drawBookEntriesUIKit(books: books, cursorY: &cursorY, context: context)
        }
    }

    private static func drawLogoAndTitleUIKit(at y: CGFloat) -> CGFloat {
        let title = "Stacked — Library Inventory"
        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let titleX = margin + logoSize + logoTitleGap
        let titleWidth = pageWidth - margin - titleX
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: pdfPrimaryText]
        let titleHeight = textHeightUIKit(title, width: titleWidth, attributes: titleAttrs)
        let rowHeight = max(logoSize, titleHeight)

        if let image = UIImage(named: "ExportLogo") {
            let logoY = y + (rowHeight - logoSize) / 2
            image.draw(in: CGRect(x: margin, y: logoY, width: logoSize, height: logoSize))
        }
        let titleY = y + (rowHeight - titleHeight) / 2
        (title as NSString).draw(
            in: CGRect(x: titleX, y: titleY, width: titleWidth, height: titleHeight),
            withAttributes: titleAttrs
        )
        return y + rowHeight + 16
    }

    private static func drawTextUIKit(
        _ text: String,
        cursorY: inout CGFloat,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let height = textHeightUIKit(text, width: contentWidth, attributes: attrs)
        if cursorY + height + spacingAfter > pageHeight - margin {
            context.beginPage()
            cursorY = margin
        }
        (text as NSString).draw(
            in: CGRect(x: margin, y: cursorY, width: contentWidth, height: height),
            withAttributes: attrs
        )
        cursorY += height + spacingAfter
    }

    private static func drawInventoryHeaderUIKit(
        books: [Book],
        cursorY: inout CGFloat,
        context: UIGraphicsPDFRendererContext
    ) {
        let dateText = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)
        let estimated = books.totalEstimatedValue
        let cost = books.totalCost
        let totalCopies = books.reduce(0) { $0 + Int($1.copies) }
        drawTextUIKit(
            "Generated \(dateText)",
            cursorY: &cursorY,
            font: .systemFont(ofSize: 10),
            color: pdfSecondaryText,
            spacingAfter: 2,
            context: context
        )
        let summary = books.hasAnyActualCost
            ? "\(books.count) unique titles · \(totalCopies) total copies · Estimated value \(money(estimated)) · Cost \(money(cost))"
            : "\(books.count) unique titles · \(totalCopies) total copies · Estimated value \(money(estimated))"
        drawTextUIKit(
            summary,
            cursorY: &cursorY,
            font: .systemFont(ofSize: 10),
            color: pdfSecondaryText,
            spacingAfter: 18,
            context: context
        )
    }

    private static func drawBookEntriesUIKit(
        books: [Book],
        cursorY: inout CGFloat,
        context: UIGraphicsPDFRendererContext
    ) {
        for book in books.sorted(by: { $0.title < $1.title }) {
            drawTextUIKit(
                book.title,
                cursorY: &cursorY,
                font: .boldSystemFont(ofSize: 13),
                color: pdfPrimaryText,
                spacingAfter: 2,
                context: context
            )
            if !book.authors.isEmpty {
                drawTextUIKit(
                    "by \(book.authors)",
                    cursorY: &cursorY,
                    font: .systemFont(ofSize: 10),
                    color: pdfSecondaryText,
                    spacingAfter: 2,
                    context: context
                )
            }
            var meta: [String] = []
            if let format = book.format?.name { meta.append(format) }
            if let location = book.location?.name { meta.append(location) }
            meta.append("Copies: \(Int(book.copies))")
            if !book.isbn.isEmpty { meta.append("ISBN \(book.isbn)") }
            drawTextUIKit(
                meta.joined(separator: "  ·  "),
                cursorY: &cursorY,
                font: .systemFont(ofSize: 11),
                color: pdfPrimaryText,
                spacingAfter: 2,
                context: context
            )
            let pricing = bookPricingLines(for: book)
            drawTextUIKit(
                pricing.listLine,
                cursorY: &cursorY,
                font: .systemFont(ofSize: 11),
                color: pdfPrimaryText,
                spacingAfter: 2,
                context: context
            )
            drawTextUIKit(
                pricing.actualLine,
                cursorY: &cursorY,
                font: .systemFont(ofSize: 11),
                color: pdfPrimaryText,
                spacingAfter: 14,
                context: context
            )
        }
    }

    private static func textHeightUIKit(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height.rounded(.up)
    }
    #endif

    // MARK: macOS PDF

    #if canImport(AppKit)
    private final class AppKitPDFLayout {
        private let pdfContext: CGContext
        private var pageOpen = false
        var cursorY: CGFloat = margin

        init(pdfContext: CGContext) {
            self.pdfContext = pdfContext
        }

        func beginPage() {
            if pageOpen {
                pdfContext.restoreGState()
                pdfContext.endPDFPage()
            }
            pdfContext.beginPDFPage(nil)
            pdfContext.saveGState()
            pdfContext.translateBy(x: 0, y: pageHeight)
            pdfContext.scaleBy(x: 1, y: -1)
            cursorY = margin
            pageOpen = true
        }

        func ensureSpace(_ needed: CGFloat) {
            if !pageOpen || cursorY + needed > pageHeight - margin {
                beginPage()
            }
        }

        func finish() {
            if pageOpen {
                pdfContext.restoreGState()
                pdfContext.endPDFPage()
            }
            pdfContext.closePDF()
        }

        func drawText(
            _ text: String,
            fontSize: CGFloat,
            bold: Bool,
            color: NSColor,
            spacingAfter: CGFloat
        ) {
            let font = NSFont.systemFont(ofSize: fontSize, weight: bold ? .bold : .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let height = ExportService.textHeightAppKit(text, width: contentWidth, attributes: attrs)
            ensureSpace(height + spacingAfter)
            let rect = CGRect(x: margin, y: cursorY, width: contentWidth, height: height)
            NSAttributedString(string: text, attributes: attrs).draw(with: rect)
            cursorY += height + spacingAfter
        }

        func drawLogoAndTitle() {
            cursorY = ExportService.drawLogoAndTitleAppKit(at: cursorY, in: pdfContext)
        }
    }

    private static func pdfDataAppKit(from books: [Book]) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw BookSearchError.transport("Could not create PDF context.")
        }

        let layout = AppKitPDFLayout(pdfContext: pdfContext)
        layout.beginPage()
        layout.drawLogoAndTitle()
        layout.drawText(
            pricingExplanation,
            fontSize: 10,
            bold: false,
            color: pdfPrimaryText,
            spacingAfter: 24
        )

        let dateText = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)
        let estimated = books.totalEstimatedValue
        let cost = books.totalCost
        let totalCopies = books.reduce(0) { $0 + Int($1.copies) }
        layout.drawText(
            "Generated \(dateText)",
            fontSize: 10,
            bold: false,
            color: pdfSecondaryText,
            spacingAfter: 2
        )
        let summary = books.hasAnyActualCost
            ? "\(books.count) unique titles · \(totalCopies) total copies · Estimated value \(money(estimated)) · Cost \(money(cost))"
            : "\(books.count) unique titles · \(totalCopies) total copies · Estimated value \(money(estimated))"
        layout.drawText(
            summary,
            fontSize: 10,
            bold: false,
            color: pdfSecondaryText,
            spacingAfter: 18
        )

        for book in books.sorted(by: { $0.title < $1.title }) {
            layout.drawText(book.title, fontSize: 13, bold: true, color: pdfPrimaryText, spacingAfter: 2)
            if !book.authors.isEmpty {
                layout.drawText(
                    "by \(book.authors)",
                    fontSize: 10,
                    bold: false,
                    color: pdfSecondaryText,
                    spacingAfter: 2
                )
            }
            var meta: [String] = []
            if let format = book.format?.name { meta.append(format) }
            if let location = book.location?.name { meta.append(location) }
            meta.append("Copies: \(Int(book.copies))")
            if !book.isbn.isEmpty { meta.append("ISBN \(book.isbn)") }
            layout.drawText(
                meta.joined(separator: "  ·  "),
                fontSize: 11,
                bold: false,
                color: pdfPrimaryText,
                spacingAfter: 2
            )
            let pricing = bookPricingLines(for: book)
            layout.drawText(pricing.listLine, fontSize: 11, bold: false, color: pdfPrimaryText, spacingAfter: 2)
            layout.drawText(pricing.actualLine, fontSize: 11, bold: false, color: pdfPrimaryText, spacingAfter: 14)
        }

        layout.finish()
        return data as Data
    }

    private static func drawLogoAndTitleAppKit(at y: CGFloat, in context: CGContext) -> CGFloat {
        let title = "Stacked — Library Inventory"
        let titleFont = NSFont.boldSystemFont(ofSize: 22)
        let titleX = margin + logoSize + logoTitleGap
        let titleWidth = pageWidth - margin - titleX
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: pdfPrimaryText]
        let titleHeight = textHeightAppKit(title, width: titleWidth, attributes: titleAttrs)
        let rowHeight = max(logoSize, titleHeight)

        if let image = NSImage(named: "ExportLogo"),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let logoY = y + (rowHeight - logoSize) / 2
            context.draw(cgImage, in: CGRect(x: margin, y: logoY, width: logoSize, height: logoSize))
        }
        let titleY = y + (rowHeight - titleHeight) / 2
        NSAttributedString(string: title, attributes: titleAttrs).draw(
            with: CGRect(x: titleX, y: titleY, width: titleWidth, height: titleHeight)
        )
        return y + rowHeight + 16
    }

    private static func textHeightAppKit(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        ).height.rounded(.up)
    }
    #endif

    private static func tempURL(name: String, ext: String) -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(stamp).\(ext)")
    }
}

#if canImport(AppKit)
private extension NSAttributedString {
    func draw(with rect: CGRect) {
        draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}
#endif
