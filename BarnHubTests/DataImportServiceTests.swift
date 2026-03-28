import XCTest
import SwiftData
@testable import BarnHub

final class DataImportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            container = try ModelContainer(
                for: Horse.self, Client.self, Transaction.self,
                VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
                Invoice.self, WeightEntry.self, ClientDocument.self,
                BarnNote.self, Lesson.self,
                configurations: config
            )
            context = ModelContext(container)
        } catch {
            XCTFail("Failed to create ModelContainer: \(error)")
        }
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - importHorses

    func test_importHorses_emptyString_returnsEmptyFileError() {
        let result = DataImportService.importHorses(from: "", context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.errors, ["Empty file"])
    }

    func test_importHorses_headerOnly_importsZeroRows() {
        let csv = "Name,Breed,Date of Birth\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 0)
    }

    func test_importHorses_missingNameColumn_returnsError() {
        let csv = "Breed,Color\nThoroughbred,Bay\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(result.errors[0].contains("Name"),
                      "Error should mention 'Name', got: \(result.errors[0])")
    }

    func test_importHorses_validRow_importsSingleHorse() throws {
        let csv = "Name,Breed\nThunder,Thoroughbred\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(horses.count, 1)
        XCTAssertEqual(horses.first?.name, "Thunder")
        XCTAssertEqual(horses.first?.breed, "Thoroughbred")
    }

    func test_importHorses_quotedFieldWithComma_parsedCorrectly() throws {
        let csv = "Name,Breed\n\"Thunder, Jr.\",Thoroughbred\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(horses.first?.name, "Thunder, Jr.")
    }

    func test_importHorses_multipleRows_allImported() throws {
        let csv = "Name,Breed\nThunder,Thoroughbred\nStardust,Quarter Horse\nBlaze,Appaloosa\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 3)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(horses.count, 3)
    }

    func test_importHorses_emptyNameRow_skipsRow() throws {
        let csv = "Name,Breed\n,Thoroughbred\nStardust,Quarter Horse\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
    }

    func test_importHorses_dateOfBirth_ISO8601Format() throws {
        let csv = "Name,Date of Birth\nThunder,2020-03-15\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        let dob = horses.first?.dateOfBirth
        XCTAssertNotNil(dob, "dateOfBirth should be parsed from ISO8601 string")
        // Use UTC calendar to match ISO8601DateFormatter's UTC output
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utcCal.component(.year, from: dob!), 2020)
        XCTAssertEqual(utcCal.component(.month, from: dob!), 3)
        XCTAssertEqual(utcCal.component(.day, from: dob!), 15)
    }

    func test_importHorses_dateOfBirth_slashFormat() throws {
        let csv = "Name,Date of Birth\nBlaze,03/20/2019\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        let dob = horses.first?.dateOfBirth
        XCTAssertNotNil(dob, "dateOfBirth should be parsed from MM/dd/yyyy string")
        // The fallback DateFormatter uses the system locale/timezone — use Calendar.current
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: dob!), 2019)
        XCTAssertEqual(cal.component(.month, from: dob!), 3)
        XCTAssertEqual(cal.component(.day, from: dob!), 20)
    }

    // MARK: - importClients

    func test_importClients_emptyString_returnsEmptyFileError() {
        let result = DataImportService.importClients(from: "", context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.errors, ["Empty file"])
    }

    func test_importClients_headerOnly_importsZeroRows() {
        let csv = "First Name,Last Name,Email\n"
        let result = DataImportService.importClients(from: csv, context: context)
        XCTAssertEqual(result.imported, 0)
    }

    func test_importClients_validRow_importsSingleClient() throws {
        let csv = "First Name,Last Name,Email\nJane,Doe,jane@example.com\n"
        let result = DataImportService.importClients(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let clients = try context.fetch(FetchDescriptor<Client>())
        XCTAssertEqual(clients.count, 1)
        XCTAssertEqual(clients.first?.firstName, "Jane")
        XCTAssertEqual(clients.first?.lastName, "Doe")
        XCTAssertEqual(clients.first?.email, "jane@example.com")
    }

    // MARK: - importTransactions

    func test_importTransactions_emptyString_returnsEmptyFileError() throws {
        let result = try DataImportService.importTransactions(from: "", context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.errors, ["Empty file"])
    }

    func test_importTransactions_missingAmountColumn_returnsError() throws {
        let csv = "Date,Type,Memo\n2026-01-01,income,test\n"
        let result = try DataImportService.importTransactions(from: csv, context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(result.errors[0].contains("Amount"))
    }

    func test_importTransactions_validRow_importsSingleTransaction() throws {
        let csv = "Date,Type,Category,Amount,Memo\n2026-01-15,income,boarding,250.0,Monthly boarding\n"
        let result = try DataImportService.importTransactions(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let txns = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txns.count, 1)
        XCTAssertEqual(txns.first?.amount, 250.0)
        XCTAssertEqual(txns.first?.type, .income)
        XCTAssertEqual(txns.first?.category, .boarding)
        XCTAssertEqual(txns.first?.memo, "Monthly boarding")
    }

    func test_importTransactions_zeroAmount_skipsRow() throws {
        let csv = "Amount,Type,Category\n0,income,boarding\n"
        let result = try DataImportService.importTransactions(from: csv, context: context)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
    }

    // MARK: - Export then Import round-trip

    func test_exportImportHorses_roundTrip() throws {
        let horse = Horse(name: "Stardust", breed: "Quarter Horse")
        horse.stallNumber = "A1"
        horse.weight = 1100.0
        context.insert(horse)
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context)
        XCTAssertTrue(csv.contains("Stardust"), "Exported CSV should contain horse name")
        XCTAssertTrue(csv.contains("Quarter Horse"))

        // Import into fresh context
        let config2 = ModelConfiguration(isStoredInMemoryOnly: true)
        let container2 = try ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self,
            BarnNote.self, Lesson.self,
            configurations: config2
        )
        let context2 = ModelContext(container2)

        let result = DataImportService.importHorses(from: csv, context: context2)
        XCTAssertEqual(result.imported, 1)

        let horses = try context2.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(horses.first?.name, "Stardust")
        XCTAssertEqual(horses.first?.breed, "Quarter Horse")
        XCTAssertEqual(horses.first?.stallNumber, "A1")
    }
}
