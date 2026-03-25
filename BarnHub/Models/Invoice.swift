import Foundation
import SwiftData

@Model
final class Invoice {
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var totalAmount: Double = 0
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var pdfData: Data? = nil

    @Relationship(deleteRule: .nullify)
    var client: Client? = nil

    init(
        startDate: Date = .now,
        endDate: Date = .now,
        totalAmount: Double = 0,
        createdAt: Date = .now,
        pdfData: Data? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalAmount = totalAmount
        self.createdAt = createdAt
        self.pdfData = pdfData
    }

    static func fileName(clientName: String, startDate: Date, endDate: Date) -> String {
        let safeName = clientName.replacingOccurrences(of: " ", with: "_")
        return "Invoice_\(safeName)_\(startDate.compactFormatted)_\(endDate.compactFormatted).pdf"
    }
}
