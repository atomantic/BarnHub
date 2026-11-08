import XCTest
import SwiftData
import PDFKit
@testable import BarnHub

final class InvoiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: BarnHubSchema.schema,
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

    @MainActor
    func testPDFGeneration() {
        let lineItems = [
            InvoicePDFService.LineItem(date: .now, description: "Lesson", category: "Lesson", amount: 75.0),
            InvoicePDFService.LineItem(date: .now, description: "Boarding", category: "Boarding", amount: 850.0),
        ]

        let document = InvoicePDFService.document(
            clientName: "Jane Doe",
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
            endDate: .now,
            lineItems: lineItems,
            total: 925.0
        )
        XCTAssertEqual(document.rows.count, 2)
        XCTAssertEqual(document.total, 925.0.asCurrency)

        assertValidPDF(InvoicePDFService.render(document), containing: "Jane Doe")
    }

    func testInvoiceFileName() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let fileName = Invoice.fileName(clientName: "Jane Doe", startDate: start, endDate: end)
        XCTAssertEqual(fileName, "Invoice_Jane_Doe_20260115_20260215.pdf")
    }

    @MainActor
    func testPDFGenerationEmptyItems() {
        let document = InvoicePDFService.document(
            clientName: "Empty Client",
            startDate: .now,
            endDate: .now,
            lineItems: [],
            total: 0
        )

        assertValidPDF(InvoicePDFService.render(document), containing: "Empty Client")
    }

    // MARK: - Rendering off the main actor (#41)

    /// Renders on a background thread while the main thread is blocked, so a
    /// renderer that reached back to the main thread (or the main actor) would
    /// hang and time out instead of passing.
    @MainActor
    func testInvoicePDFRendersWhileMainThreadIsBlocked() {
        let lineItems = (1...60).map {
            InvoicePDFService.LineItem(date: .now, description: "Lesson \($0)", category: "Lesson", amount: 75.0)
        }
        let document = InvoicePDFService.document(
            clientName: "Jane Doe",
            startDate: .now,
            endDate: .now,
            lineItems: lineItems,
            total: 4500
        )

        let data = renderBlockingMainThread { InvoicePDFService.render(document) }

        assertValidPDF(data, containing: "Lesson 60")
        XCTAssertGreaterThan(PDFDocument(data: data ?? Data())?.pageCount ?? 0, 1, "60 rows spill onto a second page")
    }

    @MainActor
    func testContractPDFsRenderWhileMainThreadIsBlocked() {
        for type in ContractType.allCases {
            let document = ContractPDFService.document(
                type: type,
                clientName: "Jane Doe",
                clientPhone: "",
                clientEmail: "jane@example.com",
                emergencyContact: "",
                emergencyPhone: "",
                horseName: "Biscuit",
                horseBreed: "",
                stallNumber: "4",
                startDate: .now,
                monthlyRate: 650
            )
            XCTAssertFalse(document.terms.isEmpty, "\(type)")

            let data = renderBlockingMainThread { ContractPDFService.render(document) }

            assertValidPDF(data, containing: "Biscuit", "\(type)")
        }
    }

    // MARK: - Label lines in the app language (#58)

    /// Sets the in-app language for the rest of the test, the way Settings →
    /// Language does, and restores the previous choice afterwards.
    private func useAppLanguage(_ id: String) {
        let key = "net.shadowpuppet.BarnBook.appLocale"
        let saved = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(id, forKey: key)
        Bundle.resetAppBundleCache()
        addTeardownBlock {
            if let saved { UserDefaults.standard.set(saved, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
            Bundle.resetAppBundleCache()
        }
    }

    private let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    private let end = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 14))!

    @MainActor
    func testFrenchInvoiceLabelsPutASpaceBeforeTheColon() {
        useAppLanguage("fr")
        let document = InvoicePDFService.document(
            clientName: "Jeanne Dupont",
            startDate: start,
            endDate: end,
            lineItems: [],
            total: 0,
            generatedAt: end
        )

        XCTAssertEqual(document.info.components(separatedBy: "\n"), [
            "Client : Jeanne Dupont",
            "Période : 15/01/2026 – 14/02/2026",
            "Généré le : 14/02/2026",
        ])
        assertValidPDF(InvoicePDFService.render(document), containing: "Client : Jeanne Dupont")
    }

    @MainActor
    func testFrenchContractLabelsPutASpaceBeforeTheColon() {
        useAppLanguage("fr")
        let document = ContractPDFService.document(
            type: .boardingAgreement,
            clientName: "Jeanne Dupont",
            clientPhone: "",
            clientEmail: "",
            emergencyContact: "",
            emergencyPhone: "",
            horseName: "Biscuit",
            horseBreed: "",
            stallNumber: "",
            startDate: start,
            monthlyRate: 650,
            generatedAt: end
        )

        XCTAssertEqual(document.partyRows.map(\.label), [
            "Client :", "Téléphone :", "E-mail :", "Contact d'urgence :", "Cheval :", "Box :",
        ])
        XCTAssertEqual(document.generatedLine, "Généré le : 14/02/2026")
        XCTAssertEqual(document.ownerSignatureLabel, "Propriétaire / Client : Jeanne Dupont")
        XCTAssertEqual(document.dateLine, "Date : _______________")
        assertValidPDF(ContractPDFService.render(document), containing: "Propriétaire / Client : Jeanne Dupont")
    }

    @MainActor
    func testGermanInvoiceAndContractLabels() {
        useAppLanguage("de")
        let clientName = "Erika Muster"
        XCTAssertEqual(appLocalized("Client: \(clientName)"), "Kunde: Erika Muster")
        XCTAssertEqual(appLocalized("Period: \("01.02.2026") – \("28.02.2026")"), "Zeitraum: 01.02.2026 – 28.02.2026")

        let contract = ContractPDFService.document(
            type: .liabilityWaiver,
            clientName: clientName,
            clientPhone: "",
            clientEmail: "",
            emergencyContact: "",
            emergencyPhone: "",
            horseName: "Biscuit",
            horseBreed: "",
            stallNumber: "",
            startDate: start,
            monthlyRate: 0,
            generatedAt: end
        )
        XCTAssertEqual(contract.generatedLine, "Erstellt: 14.02.2026")
        XCTAssertEqual(contract.ownerSignatureLabel, "Eigentümer / Kunde: Erika Muster")
        XCTAssertEqual(contract.partyRows.first?.label, "Kunde:")
    }

    /// `appLocalized` resolves `Bundle.app` from whatever thread renders a PDF
    /// while the UI resolves it on main, and the language picker resets it.
    func testBundleAppIsSafeToCallConcurrently() {
        let expected = Bundle.app.bundlePath
        DispatchQueue.concurrentPerform(iterations: 500) { i in
            if i.isMultiple(of: 25) { Bundle.resetAppBundleCache() }
            XCTAssertEqual(Bundle.app.bundlePath, expected)
            XCTAssertFalse(appLocalized("Client", comment: "Invoice PDF label").isEmpty)
        }
    }

    // MARK: - Helpers

    /// Runs `render` on a background thread and blocks the main thread until it
    /// finishes (or 30 seconds pass, which fails the test).
    @MainActor
    private func renderBlockingMainThread(
        _ render: @escaping @Sendable () -> Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Data? {
        let done = DispatchSemaphore(value: 0)
        let box = RenderedData()
        Thread.detachNewThread {
            XCTAssertFalse(Thread.isMainThread)
            box.data = render()
            done.signal()
        }
        guard done.wait(timeout: .now() + 30) == .success else {
            XCTFail("Rendering didn't finish while the main thread was blocked", file: file, line: line)
            return nil
        }
        return box.data
    }

    private func assertValidPDF(
        _ data: Data?,
        containing text: String,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let data else { return XCTFail("No PDF data \(message)", file: file, line: line) }
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF", message, file: file, line: line)
        guard let pdf = PDFDocument(data: data) else {
            return XCTFail("PDFKit can't open the data \(message)", file: file, line: line)
        }
        XCTAssertGreaterThan(pdf.pageCount, 0, message, file: file, line: line)
        XCTAssertTrue(pdf.string?.contains(text) == true, "PDF text is missing \(text) \(message)", file: file, line: line)
    }
}

/// Hands the rendered bytes from the background thread back to the test; the
/// semaphore orders the write before the read.
private final class RenderedData: @unchecked Sendable {
    var data: Data?
}
