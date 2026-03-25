import XCTest
import SwiftData
@testable import BarnHub

final class InvoiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    func testInvoiceCreation() {
        let invoice = Invoice(
            startDate: .now,
            endDate: .now,
            totalAmount: 500.0,
            createdAt: .now,
            pdfData: Data([0x25, 0x50, 0x44, 0x46]) // %PDF header
        )
        context.insert(invoice)
        try! context.save()

        let descriptor = FetchDescriptor<Invoice>()
        let invoices = try! context.fetch(descriptor)
        XCTAssertEqual(invoices.count, 1)
        XCTAssertEqual(invoices.first?.totalAmount, 500.0)
        XCTAssertNotNil(invoices.first?.pdfData)
    }

    func testInvoiceClientRelationship() {
        let client = Client(firstName: "Jane", lastName: "Doe")
        let invoice = Invoice(totalAmount: 250.0)
        invoice.client = client
        context.insert(client)
        context.insert(invoice)
        try! context.save()

        XCTAssertEqual(invoice.client?.fullName, "Jane Doe")
        XCTAssertEqual(client.invoices?.count, 1)
    }

    func testInvoiceCascadeDelete() {
        let client = Client(firstName: "Mike", lastName: "Smith")
        context.insert(client)
        let invoice1 = Invoice(totalAmount: 100.0)
        invoice1.client = client
        let invoice2 = Invoice(totalAmount: 200.0)
        invoice2.client = client
        context.insert(invoice1)
        context.insert(invoice2)
        try! context.save()

        XCTAssertEqual(client.invoices?.count, 2)

        context.delete(client)
        try! context.save()

        let descriptor = FetchDescriptor<Invoice>()
        let invoices = try! context.fetch(descriptor)
        XCTAssertEqual(invoices.count, 0)
    }

    func testFeatureGateInvoices() {
        XCTAssertFalse(FeatureGate.canGenerateInvoices(false))
        XCTAssertTrue(FeatureGate.canGenerateInvoices(true))
    }

    func testPDFGeneration() {
        let lineItems = [
            InvoicePDFService.LineItem(date: .now, description: "Lesson", category: "Lesson", amount: 75.0),
            InvoicePDFService.LineItem(date: .now, description: "Boarding", category: "Boarding", amount: 850.0),
        ]

        let pdfData = InvoicePDFService.generatePDF(
            clientName: "Jane Doe",
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
            endDate: .now,
            lineItems: lineItems,
            total: 925.0
        )

        // PDF should start with %PDF header
        XCTAssertGreaterThan(pdfData.count, 0)
        let header = String(data: pdfData.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    func testInvoiceFileName() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let fileName = Invoice.fileName(clientName: "Jane Doe", startDate: start, endDate: end)
        XCTAssertEqual(fileName, "Invoice_Jane_Doe_20260115_20260215.pdf")
    }

    func testPDFGenerationEmptyItems() {
        let pdfData = InvoicePDFService.generatePDF(
            clientName: "Empty Client",
            startDate: .now,
            endDate: .now,
            lineItems: [],
            total: 0
        )

        XCTAssertGreaterThan(pdfData.count, 0)
        let header = String(data: pdfData.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }
}
