import Foundation

/// Builds the client invoice PDF in two steps, so the slow part can run off the
/// main actor (#41): `document(…)` resolves every localized and formatted string
/// on the main actor, then `render(_:)` draws those plain values on any thread.
struct InvoicePDFService {
    struct LineItem {
        let date: Date
        let description: String
        let category: String
        let amount: Double
    }

    /// Everything the invoice prints, already localized and formatted.
    struct Document: Sendable {
        struct Row: Sendable {
            let date: String
            let description: String
            let category: String
            let amount: String
        }

        let title: String
        /// Client, period and generated date, one per line.
        let info: String
        let dateHeader: String
        let descriptionHeader: String
        let categoryHeader: String
        let amountHeader: String
        let rows: [Row]
        let totalLabel: String
        let total: String
    }

    /// Resolves the invoice's text. Main actor because currency formatting uses a
    /// shared formatter.
    @MainActor
    static func document(
        clientName: String,
        startDate: Date,
        endDate: Date,
        lineItems: [LineItem],
        total: Double,
        generatedAt: Date = .now
    ) -> Document {
        let info = [
            "\(appLocalized("Client", comment: "Invoice PDF label")): \(clientName)",
            "\(appLocalized("Period", comment: "Invoice PDF label")): \(startDate.shortFormatted) – \(endDate.shortFormatted)",
            "\(appLocalized("Generated", comment: "Invoice PDF label")): \(generatedAt.shortFormatted)",
        ].joined(separator: "\n")
        return Document(
            title: appLocalized("BarnHub Invoice", comment: "Invoice PDF title"),
            info: info,
            dateHeader: appLocalized("Date", comment: "Invoice PDF column header"),
            descriptionHeader: appLocalized("Description", comment: "Invoice PDF column header"),
            categoryHeader: appLocalized("Category", comment: "Invoice PDF column header"),
            amountHeader: appLocalized("Amount", comment: "Invoice PDF column header"),
            rows: lineItems.map {
                Document.Row(
                    date: $0.date.shortFormatted,
                    description: $0.description,
                    category: $0.category,
                    amount: $0.amount.asCurrency
                )
            },
            totalLabel: appLocalized("Total Due:", comment: "Invoice PDF total label"),
            total: total.asCurrency
        )
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

extension InvoicePDFService {
    private static let headerColor = UIColor(red: 74/255, green: 124/255, blue: 63/255, alpha: 1)

    /// Draws `document` as PDF data. Reads nothing but its argument, so it's safe
    /// to call from a background task.
    static func render(_ document: Document) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: headerColor
            ]
            (document.title as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
            yOffset += 36

            // Client & date range
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            let infoRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: 60)
            (document.info as NSString).draw(in: infoRect, withAttributes: infoAttrs)
            yOffset += 70

            // Divider
            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 10

            // Column headers
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            (document.dateHeader as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            (document.descriptionHeader as NSString).draw(at: CGPoint(x: margin + 80, y: yOffset), withAttributes: headerAttrs)
            (document.categoryHeader as NSString).draw(at: CGPoint(x: margin + 340, y: yOffset), withAttributes: headerAttrs)
            (document.amountHeader as NSString).draw(at: CGPoint(x: margin + 450, y: yOffset), withAttributes: headerAttrs)
            yOffset += 20

            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 8

            // Line items
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]

            for row in document.rows {
                if yOffset > pageHeight - 100 {
                    context.beginPage()
                    yOffset = margin
                }

                (row.date as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: rowAttrs)

                let descRect = CGRect(x: margin + 80, y: yOffset, width: 250, height: 30)
                (row.description as NSString).draw(in: descRect, withAttributes: rowAttrs)

                (row.category as NSString).draw(at: CGPoint(x: margin + 340, y: yOffset), withAttributes: rowAttrs)

                let amountStr = row.amount as NSString
                let amountSize = amountStr.size(withAttributes: rowAttrs)
                amountStr.draw(at: CGPoint(x: margin + contentWidth - amountSize.width, y: yOffset), withAttributes: rowAttrs)

                yOffset += 22
            }

            // Total
            yOffset += 10
            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 10

            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            (document.totalLabel as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: totalAttrs)
            let totalStr = document.total as NSString
            let totalSize = totalStr.size(withAttributes: totalAttrs)
            totalStr.draw(at: CGPoint(x: margin + contentWidth - totalSize.width, y: yOffset), withAttributes: totalAttrs)
        }
    }

    private static func drawLine(context: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + width, y: y))
        context.strokePath()
    }
}

#else

extension InvoicePDFService {
    static func render(_ document: Document) -> Data { Data() }
}

#endif
