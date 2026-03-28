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
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self,
            BarnNote.self, Lesson.self,
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
}
