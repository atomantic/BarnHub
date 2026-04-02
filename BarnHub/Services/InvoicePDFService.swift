import Foundation
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

struct InvoicePDFService {
    private static let headerColor = UIColor(red: 74/255, green: 124/255, blue: 63/255, alpha: 1)

    struct LineItem {
        let date: Date
        let description: String
        let category: String
        let amount: Double
    }

    static func generatePDF(
        clientName: String,
        startDate: Date,
        endDate: Date,
        lineItems: [LineItem],
        total: Double
    ) -> Data {
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
            let title = "BarnHub Invoice" as NSString
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
            yOffset += 36

            // Client & date range
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            let info = "Client: \(clientName)\nPeriod: \(startDate.shortFormatted) – \(endDate.shortFormatted)\nGenerated: \(Date.now.shortFormatted)" as NSString
            let infoRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: 60)
            info.draw(in: infoRect, withAttributes: infoAttrs)
            yOffset += 70

            // Divider
            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 10

            // Column headers
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            ("Date" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            ("Description" as NSString).draw(at: CGPoint(x: margin + 80, y: yOffset), withAttributes: headerAttrs)
            ("Category" as NSString).draw(at: CGPoint(x: margin + 340, y: yOffset), withAttributes: headerAttrs)
            ("Amount" as NSString).draw(at: CGPoint(x: margin + 450, y: yOffset), withAttributes: headerAttrs)
            yOffset += 20

            drawLine(context: context.cgContext, y: yOffset, margin: margin, width: contentWidth)
            yOffset += 8

            // Line items
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]

            for item in lineItems {
                if yOffset > pageHeight - 100 {
                    context.beginPage()
                    yOffset = margin
                }

                (item.date.shortFormatted as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: rowAttrs)

                let descRect = CGRect(x: margin + 80, y: yOffset, width: 250, height: 30)
                (item.description as NSString).draw(in: descRect, withAttributes: rowAttrs)

                (item.category as NSString).draw(at: CGPoint(x: margin + 340, y: yOffset), withAttributes: rowAttrs)

                let amountStr = item.amount.asCurrency as NSString
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
            ("Total Due:" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: totalAttrs)
            let totalStr = total.asCurrency as NSString
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

struct InvoicePDFService {
    struct LineItem {
        let date: Date
        let description: String
        let category: String
        let amount: Double
    }

    static func generatePDF(
        clientName: String,
        startDate: Date,
        endDate: Date,
        lineItems: [LineItem],
        total: Double
    ) -> Data { Data() }
}

#endif
