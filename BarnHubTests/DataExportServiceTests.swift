import XCTest
import SwiftData
@testable import BarnHub

final class DataExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Horses CSV

    func test_exportHorsesCSV_emptyContext_returnsHeaderOnly() throws {
        let csv = try DataExportService.exportHorsesCSV(from: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("Name,Breed,"))
    }

    func test_exportHorsesCSV_singleHorse_containsHorseName() throws {
        let horse = Horse(name: "Thunder", breed: "Thoroughbred")
        context.insert(horse)
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("Thunder"))
        XCTAssertTrue(lines[1].contains("Thoroughbred"))
    }

    func test_exportHorsesCSV_horseWithCommaInName_isQuoted() throws {
        let horse = Horse(name: "Thunder, Jr.")
        context.insert(horse)
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context)
        XCTAssertTrue(csv.contains("\"Thunder, Jr.\""),
                      "Field with comma should be quoted. Got:\n\(csv)")
    }

    func test_exportHorsesCSV_horseWithQuoteInName_escapesDoubleQuote() throws {
        let horse = Horse(name: "Thunder \"The Great\"")
        context.insert(horse)
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context)
        // CSV escaping: " → ""
        XCTAssertTrue(csv.contains("\"Thunder \"\"The Great\"\"\""),
                      "Embedded quotes should be doubled. Got:\n\(csv)")
    }

    func test_exportHorsesCSV_headerMatchesImportExpectation() throws {
        let csv = try DataExportService.exportHorsesCSV(from: context)
        let header = csv.components(separatedBy: "\n")[0]
        XCTAssertEqual(header, "Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active")
    }

    // MARK: - Clients CSV

    func test_exportClientsCSV_emptyContext_returnsHeaderOnly() throws {
        let csv = try DataExportService.exportClientsCSV(from: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("First Name,Last Name,"))
    }

    func test_exportClientsCSV_clientWithCommaInNote_isQuoted() throws {
        let client = Client(firstName: "Jane", lastName: "Doe")
        client.notes = "Allergic to dust, mold"
        context.insert(client)
        try context.save()

        let csv = try DataExportService.exportClientsCSV(from: context)
        XCTAssertTrue(csv.contains("\"Allergic to dust, mold\""),
                      "Note with comma should be quoted. Got:\n\(csv)")
    }

    // MARK: - Transactions CSV

    func test_exportTransactionsCSV_emptyContext_returnsHeaderOnly() throws {
        let csv = try DataExportService.exportTransactionsCSV(from: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("Date,Type,Category,Amount,"))
    }

    func test_exportTransactionsCSV_singleTransaction_containsCorrectValues() throws {
        let txn = Transaction(amount: 150.0, memo: "Boarding", category: .boarding, type: .income)
        context.insert(txn)
        try context.save()

        let csv = try DataExportService.exportTransactionsCSV(from: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2)
        let dataLine = lines[1]
        XCTAssertTrue(dataLine.contains("income"), "Expected 'income' in: \(dataLine)")
        XCTAssertTrue(dataLine.contains("boarding"), "Expected 'boarding' in: \(dataLine)")
        XCTAssertTrue(dataLine.contains("150.0"), "Expected '150.0' in: \(dataLine)")
    }

    // MARK: - Escaping

    func test_field_formulaLeadingCells_arePrefixedWithQuote() {
        XCTAssertEqual(CSVWriter.field("=SUM(A1:A2)"), "'=SUM(A1:A2)")
        XCTAssertEqual(CSVWriter.field("+1 555 0100"), "'+1 555 0100")
        XCTAssertEqual(CSVWriter.field("-2+3"), "'-2+3")
        XCTAssertEqual(CSVWriter.field("@cmd"), "'@cmd")
        XCTAssertEqual(CSVWriter.field("\tTab"), "'\tTab")
        XCTAssertEqual(CSVWriter.field("Plain"), "Plain")
        XCTAssertEqual(CSVWriter.field("a=b"), "a=b")
    }

    func test_field_quotesCommaQuoteNewlineAndCarriageReturn() {
        XCTAssertEqual(CSVWriter.field("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVWriter.field("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVWriter.field("a\nb"), "\"a\nb\"")
        XCTAssertEqual(CSVWriter.field("a\rb"), "\"a\rb\"")
        XCTAssertEqual(CSVWriter.field("=1,2"), "\"'=1,2\"")
    }

    func test_exportClientsCSV_formulaInNotes_isNeutralized() throws {
        let client = Client(firstName: "Eve", lastName: "Mallory")
        client.notes = "=HYPERLINK(\"http://example.com\",\"click\")"
        context.insert(client)
        try context.save()

        let csv = try DataExportService.exportClientsCSV(from: context)
        XCTAssertTrue(csv.contains("\"'=HYPERLINK("), "Formula cell should be prefixed and quoted. Got:\n\(csv)")
        XCTAssertFalse(csv.contains(",=HYPERLINK"), csv)
    }

    func test_exportTransactionsCSV_dateUsesGivenTimeZone() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let evening = cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 20))!
        context.insert(Transaction(amount: 10, date: evening, category: .feed, type: .expense))
        try context.save()

        let options = CSVOptions(timeZone: cal.timeZone, locale: Locale(identifier: "en_US"))
        let csv = try DataExportService.exportTransactionsCSV(from: context, options: options)
        XCTAssertTrue(csv.contains("\n2026-01-15,expense,feed,10.0,"), csv)
    }

    func test_number_threeFractionDigits_isWrittenUnambiguously() {
        XCTAssertEqual(CSVWriter.number(150), "150.0")
        XCTAssertEqual(CSVWriter.number(123.456), "123.4560")
        XCTAssertEqual(CSVWriter.number(1234.567), "1234.567")
        let de = CSVAmountParser(options: CSVOptions(locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(de.parse(CSVWriter.number(123.456)), 123.456)
    }
}
