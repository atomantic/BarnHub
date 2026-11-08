import XCTest
import SwiftData
@testable import BarnHub

final class DataImportServiceTests: XCTestCase {

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
        // Date-only values are interpreted in the user's time zone, not UTC.
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: dob!), 2020)
        XCTAssertEqual(cal.component(.month, from: dob!), 3)
        XCTAssertEqual(cal.component(.day, from: dob!), 15)
    }

    func test_importHorses_dateOfBirth_slashFormat() throws {
        let csv = "Name,Date of Birth\nBlaze,03/20/2019\n"
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)

        let horses = try context.fetch(FetchDescriptor<Horse>())
        let dob = horses.first?.dateOfBirth
        XCTAssertNotNil(dob, "dateOfBirth should be parsed from MM/dd/yyyy string")
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

    func test_importTransactions_camelCaseCategory_matchesIgnoringCase() throws {
        let csv = "Date,Type,Category,Amount\n2026-01-15,expense,vetBill,85\n2026-01-16,Expense,VETBILL,90\n"
        let result = try DataImportService.importTransactions(from: csv, context: context)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).map(\.category), [.vetBill, .vetBill])
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
            for: BarnHubSchema.schema,
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

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        retainedContainers.append(container)
        return ModelContext(container)
    }

    private var retainedContainers: [ModelContainer] = []

    /// UTC+12/+13 with DST, so a UTC-based codec would shift every date by a day.
    private let auckland = CSVOptions(timeZone: TimeZone(identifier: "Pacific/Auckland")!, locale: Locale(identifier: "de_DE"))
    /// UTC-8/-7, where 8 PM local is already the next day in UTC.
    private let losAngeles = CSVOptions(timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: Locale(identifier: "en_US"))

    private func components(_ date: Date, in options: CSVOptions) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = options.timeZone
        return cal.dateComponents([.year, .month, .day], from: date)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, in options: CSVOptions) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = options.timeZone
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: - Dates

    func test_dateCodec_exportsLocalDay_notUTCDay() {
        let codec = CSVDateCodec(options: losAngeles)
        // 8 PM on Jan 15 in Los Angeles is 04:00 Jan 16 UTC.
        XCTAssertEqual(codec.string(from: date(2026, 1, 15, hour: 20, in: losAngeles)), "2026-01-15")
    }

    func test_dateCodec_unambiguousDayFirst_parsesInUSLocale() {
        let codec = CSVDateCodec(options: losAngeles)
        let parsed = codec.date(from: "25/03/2026")
        XCTAssertEqual(parsed.map { components($0, in: losAngeles) }, DateComponents(year: 2026, month: 3, day: 25))
    }

    func test_dateCodec_ambiguousDate_followsRegion() {
        let us = CSVDateCodec(options: losAngeles).date(from: "03/04/2026")
        XCTAssertEqual(us.map { components($0, in: losAngeles) }, DateComponents(year: 2026, month: 3, day: 4))
        let de = CSVDateCodec(options: auckland).date(from: "03.04.2026")
        XCTAssertEqual(de.map { components($0, in: auckland) }, DateComponents(year: 2026, month: 4, day: 3))
    }

    func test_dateCodec_rejectsImpossibleAndGarbageDates() {
        let codec = CSVDateCodec(options: losAngeles)
        XCTAssertNil(codec.date(from: "2026-02-30"))
        XCTAssertNil(codec.date(from: "31/31/2026"))
        XCTAssertNil(codec.date(from: "next Tuesday"))
    }

    // MARK: - Amounts

    func test_amountParser_handlesLocaleAndCurrencyFormats() {
        let us = CSVAmountParser(options: losAngeles)
        XCTAssertEqual(us.parse("12,50"), 12.5)
        XCTAssertEqual(us.parse("1.234,56"), 1234.56)
        XCTAssertEqual(us.parse("€12"), 12)
        XCTAssertEqual(us.parse("$1,234.50"), 1234.5)
        XCTAssertEqual(us.parse("-50"), -50)
        XCTAssertEqual(us.parse("(50.00)"), -50)
        XCTAssertEqual(us.parse("-$1,234.50"), -1234.5)
        XCTAssertEqual(us.parse("150.0"), 150)
        XCTAssertEqual(us.parse("0.125"), 0.125)
        XCTAssertEqual(us.parse("1e-05"), 0.00001)
        XCTAssertEqual(us.parse("1,234"), 1234, "comma is grouping in en_US")
        XCTAssertNil(us.parse("abc"))
        XCTAssertNil(us.parse("1.2.3,4.5"))
    }

    func test_amountParser_ambiguousThousands_followsLocale() {
        let de = CSVAmountParser(options: auckland)
        XCTAssertEqual(de.parse("1,234"), 1.234, "comma is the decimal mark in de_DE")
        XCTAssertEqual(de.parse("1.234"), 1234, "dot is grouping in de_DE")
        XCTAssertEqual(de.parse("12 €"), 12)
    }

    // MARK: - Transactions

    func test_importTransactions_negativeAmount_flipsTypeInsteadOfSkipping() throws {
        let csv = "Date,Type,Amount,Memo\n2026-01-15,income,-50,Refund\n2026-01-16,,(20),Bank fee\n"
        let result = try DataImportService.importTransactions(from: csv, context: context, options: losAngeles)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        let txns = try context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(txns.map(\.amount), [50, 20])
        XCTAssertEqual(txns.map(\.type), [.expense, .expense])
    }

    func test_importTransactions_malformedRows_reportedWithReasons() throws {
        let csv = """
        Date,Type,Amount,Memo
        2026-01-15,income,abc,bad amount
        sometime,income,10,bad date
        2026-01-15,income,,no amount
        2026-01-15,income,10,extra,columns
        2026-01-15,income,25,good
        2026-01-16,income,30,"unterminated
        """
        let result = try DataImportService.importTransactions(from: csv, context: context, options: losAngeles)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipReasons[.invalidAmount], 1)
        XCTAssertEqual(result.skipReasons[.invalidDate], 1)
        XCTAssertEqual(result.skipReasons[.missingAmount], 1)
        XCTAssertEqual(result.skipReasons[.malformedRow], 2)
        XCTAssertEqual(result.skipped, 5)
    }

    func test_importTransactions_matchesClientCaseInsensitively() throws {
        let client = Client(firstName: "Jane", lastName: "Doe")
        context.insert(client)
        try context.save()
        let csv = "Date,Amount,Client\n2026-01-15,100,jane doe\n2026-01-15,100,Nobody\n"
        let result = try DataImportService.importTransactions(from: csv, context: context, options: losAngeles)
        XCTAssertEqual(result.imported, 2)
        let txns = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txns.compactMap { $0.client?.fullName }, ["Jane Doe"])
    }

    func test_importTransactions_batchedSaves_importAllRows() throws {
        var csv = "Date,Amount,Memo\n"
        for i in 1...1_201 { csv += "2026-01-15,\(i),Row \(i)\n" }
        var options = losAngeles
        options.batchSize = 500
        let result = try DataImportService.importTransactions(from: csv, context: context, options: options)
        XCTAssertEqual(result.imported, 1_201)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 1_201)
    }

    // MARK: - Round trips

    func test_exportImportTransactions_roundTrip_nonUTCAndEuropeanLocale() throws {
        let client = Client(firstName: "Jane", lastName: "Doe")
        context.insert(client)
        let late = Transaction(amount: 1234.56, date: date(2026, 1, 15, hour: 23, in: auckland),
                               memo: "Board, January", category: .boarding, type: .income, isPaid: true)
        late.client = client
        let early = Transaction(amount: 12.5, date: date(2026, 3, 1, hour: 0, in: auckland),
                                memo: "=HYPERLINK(\"x\")", category: .feed, type: .expense)
        context.insert(late)
        context.insert(early)
        try context.save()

        let csv = try DataExportService.exportTransactionsCSV(from: context, options: auckland)
        XCTAssertTrue(csv.contains("2026-01-15,income,boarding,1234.56,\"Board, January\",Jane Doe,true"), csv)
        XCTAssertTrue(csv.contains("2026-03-01,expense,feed,12.5,\"'=HYPERLINK(\"\"x\"\")\",,false"), csv)

        let context2 = try makeContext()
        let clientResult = DataImportService.importClients(
            from: try DataExportService.exportClientsCSV(from: context, options: auckland), context: context2, options: auckland)
        XCTAssertEqual(clientResult.imported, 1)
        let result = try DataImportService.importTransactions(from: csv, context: context2, options: auckland)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)

        let txns = try context2.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(txns.map(\.amount), [1234.56, 12.5])
        XCTAssertEqual(txns.map(\.memo), ["Board, January", "=HYPERLINK(\"x\")"])
        XCTAssertEqual(txns.map(\.type), [.income, .expense])
        XCTAssertEqual(txns.map(\.category), [.boarding, .feed])
        XCTAssertEqual(txns.map(\.isPaid), [true, false])
        XCTAssertEqual(txns.first?.client?.fullName, "Jane Doe")
        XCTAssertEqual(components(txns[0].date, in: auckland), DateComponents(year: 2026, month: 1, day: 15))
        XCTAssertEqual(components(txns[1].date, in: auckland), DateComponents(year: 2026, month: 3, day: 1))
    }

    func test_exportImportClients_roundTrip_preservesFieldsNeedingEscapes() throws {
        let client = Client(firstName: "Anne-Marie", lastName: "O\"Neil, Jr.")
        client.email = "anne@example.com"
        client.phone = "+1 555 0100"
        client.emergencyContact = "@mom"
        client.emergencyPhone = "-"
        client.notes = "Line one\r\nLine two, with comma"
        client.isActive = false
        context.insert(client)
        try context.save()

        let csv = try DataExportService.exportClientsCSV(from: context, options: auckland)
        let context2 = try makeContext()
        let result = DataImportService.importClients(from: csv, context: context2, options: auckland)
        XCTAssertEqual(result.imported, 1)

        let imported = try XCTUnwrap(context2.fetch(FetchDescriptor<Client>()).first)
        XCTAssertEqual(imported.firstName, "Anne-Marie")
        XCTAssertEqual(imported.lastName, "O\"Neil, Jr.")
        XCTAssertEqual(imported.email, "anne@example.com")
        XCTAssertEqual(imported.phone, "+1 555 0100")
        XCTAssertEqual(imported.emergencyContact, "@mom")
        XCTAssertEqual(imported.emergencyPhone, "-")
        XCTAssertEqual(imported.notes, "Line one\r\nLine two, with comma")
        XCTAssertFalse(imported.isActive)
    }

    func test_exportImportHorses_roundTrip_keepsBirthDayInNonUTCZone() throws {
        let horse = Horse(name: "Comet", breed: "Arabian")
        horse.dateOfBirth = date(2019, 5, 1, hour: 0, in: auckland)
        horse.weight = 950.5
        context.insert(horse)
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context, options: auckland)
        XCTAssertTrue(csv.contains("Comet,Arabian,2019-05-01,"), csv)
        let context2 = try makeContext()
        XCTAssertEqual(DataImportService.importHorses(from: csv, context: context2, options: auckland).imported, 1)
        let imported = try XCTUnwrap(context2.fetch(FetchDescriptor<Horse>()).first)
        XCTAssertEqual(components(imported.dateOfBirth, in: auckland), DateComponents(year: 2019, month: 5, day: 1))
        XCTAssertEqual(imported.weight, 950.5)
    }

    // MARK: - Gender

    func test_exportImportHorses_roundTrip_keepsGender() throws {
        for (name, gender) in [("Bella", HorseGender.mare), ("Duke", .stallion), ("Pepper", .gelding)] {
            context.insert(Horse(name: name, gender: gender))
        }
        try context.save()

        let csv = try DataExportService.exportHorsesCSV(from: context)
        XCTAssertTrue(csv.hasPrefix("Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active,Gender\n"), csv)
        let context2 = try makeContext()
        XCTAssertEqual(DataImportService.importHorses(from: csv, context: context2).imported, 3)
        let imported = Dictionary(uniqueKeysWithValues: try context2.fetch(FetchDescriptor<Horse>()).map { ($0.name, $0.gender) })
        XCTAssertEqual(imported, ["Bella": .mare, "Duke": .stallion, "Pepper": .gelding])
    }

    func test_importHorses_olderFileWithoutGenderColumn_importsAsBefore() throws {
        let csv = """
        Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active
        Thunder,Thoroughbred,2020-03-15,Bay,1100.0,5000.0,B2,None,Twice daily,false
        """
        let result = DataImportService.importHorses(from: csv, context: context)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)
        let horse = try XCTUnwrap(context.fetch(FetchDescriptor<Horse>()).first)
        XCTAssertEqual(horse.gender, .mare)
        XCTAssertEqual(horse.breed, "Thoroughbred")
        XCTAssertEqual(horse.colorMarkings, "Bay")
        XCTAssertEqual(horse.weight, 1100)
        XCTAssertEqual(horse.purchasePrice, 5000)
        XCTAssertEqual(horse.stallNumber, "B2")
        XCTAssertEqual(horse.feedingSchedule, "Twice daily")
        XCTAssertFalse(horse.isActive)
    }

    func test_importHorses_gender_acceptsRawValuesAndDisplayNames() throws {
        let csv = """
        Name,Gender
        A,STALLION
        B,Gelding
        C,Wallach
        D,Hongre
        E,Caballo castrado
        F,Hengst
        G,
        H,unicorn
        """
        XCTAssertEqual(DataImportService.importHorses(from: csv, context: context).imported, 8)
        let genders = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Horse>()).map { ($0.name, $0.gender) })
        XCTAssertEqual(genders, ["A": .stallion, "B": .gelding, "C": .gelding, "D": .gelding, "E": .gelding,
                                 "F": .stallion, "G": .mare, "H": .mare])
    }

    // MARK: - Duplicates

    func test_reimport_skipsExactDuplicatesForEveryType() throws {
        let client = Client(firstName: "Jane", lastName: "Doe", email: "jane@example.com")
        context.insert(client)
        let horse = Horse(name: "Thunder", breed: "Thoroughbred")
        horse.dateOfBirth = date(2020, 3, 15, in: losAngeles)
        context.insert(horse)
        let txn = Transaction(amount: 250, date: date(2026, 1, 15, hour: 20, in: losAngeles), memo: "Board", category: .boarding, type: .income)
        txn.client = client
        context.insert(txn)
        try context.save()

        let clients = try DataExportService.exportClientsCSV(from: context, options: losAngeles)
        let horses = try DataExportService.exportHorsesCSV(from: context, options: losAngeles)
        let txns = try DataExportService.exportTransactionsCSV(from: context, options: losAngeles)

        let clientResult = DataImportService.importClients(from: clients, context: context, options: losAngeles)
        XCTAssertEqual(clientResult.imported, 0)
        XCTAssertEqual(clientResult.duplicates, 1)

        let horseResult = DataImportService.importHorses(from: horses, context: context, options: losAngeles)
        XCTAssertEqual(horseResult.imported, 0)
        XCTAssertEqual(horseResult.duplicates, 1)

        let txnResult = try DataImportService.importTransactions(from: txns, context: context, options: losAngeles)
        XCTAssertEqual(txnResult.imported, 0)
        XCTAssertEqual(txnResult.duplicates, 1)

        // A row that differs in any key field is not a duplicate.
        let changed = txns.replacingOccurrences(of: "250.0", with: "251.0")
        XCTAssertEqual(try DataImportService.importTransactions(from: changed, context: context, options: losAngeles).imported, 1)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Client>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Horse>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 2)
    }

    // MARK: - Background actor

    func test_actor_importsFromFileAndExportsToFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("in.csv")
        try Data("\u{FEFF}Name,Breed\r\nThunder,Thoroughbred\r\nStardust,\"Quarter\nHorse\"\r\n".utf8).write(to: input)

        let options = losAngeles
        let actorContainer = container!
        let result = try await Task.detached {
            try await CSVDataActor(modelContainer: actorContainer).importCSV(.horses, from: input, options: options, progress: nil)
        }.value
        XCTAssertEqual(result.imported, 2)

        let urls = try await Task.detached {
            try await CSVDataActor(modelContainer: actorContainer).export([.horses], to: dir, filePrefix: "barnhub_", options: options, progress: nil)
        }.value
        XCTAssertEqual(urls.map(\.lastPathComponent), ["barnhub_horses.csv"])
        let exported = try String(contentsOf: urls[0], encoding: .utf8)
        XCTAssertTrue(exported.contains("\"Quarter\nHorse\""), exported)
        XCTAssertTrue(exported.contains("Thunder,Thoroughbred"), exported)
    }

    func test_actor_cancelledImport_savesNothingAndReportsCancelled() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("in.csv")
        try Data("Name\nA\nB\n".utf8).write(to: input)

        let options = losAngeles
        let actorContainer = container!
        let task = Task.detached { () -> DataImportService.ImportResult in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CSVDataActor(modelContainer: actorContainer).importCSV(.horses, from: input, options: options, progress: nil)
        }
        let result = try await task.value
        XCTAssertTrue(result.cancelled)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(try ModelContext(actorContainer).fetchCount(FetchDescriptor<Horse>()), 0)
    }

    // MARK: - Old and new export formats

    /// Files exported before All Data had ID, link-ID and file columns.
    func test_import_oldFormatFilesWithoutIDColumns() throws {
        let horses = DataImportService.importHorses(from: """
        Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active,Gender
        Storm,Arabian,2018-04-02,Grey,950.0,0.0,A1,,,true,gelding
        """, context: context)
        let clients = DataImportService.importClients(from: """
        First Name,Last Name,Email,Phone,Emergency Contact,Emergency Phone,Notes,Active
        Jane,Doe,jane@example.com,,,,,true
        """, context: context)
        let txns = try DataImportService.importTransactions(from: """
        Date,Type,Category,Amount,Memo,Client,Paid
        2026-03-01,income,boarding,50.0,March,Jane Doe,true
        """, context: context)

        XCTAssertEqual([horses.imported, clients.imported, txns.imported], [1, 1, 1])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Horse>()).first?.gender, .gelding)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).first?.client?.fullName, "Jane Doe")
    }

    /// All Data files add ID, link-ID and file-path columns (and a reader may
    /// reorder columns); the importers match by header name and ignore the rest.
    func test_import_newFormatFilesWithIDAndPathColumns() throws {
        let horses = DataImportService.importHorses(from: """
        ID,Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active,Gender,Photo
        horse-1,Storm,Arabian,2018-04-02,Grey,950.0,0.0,A1,,,true,gelding,Photos/Horses/Storm.jpg
        horse-2,Storm,Quarter Horse,2019-05-03,Bay,1000.0,0.0,A2,,,true,mare,Photos/Horses/Storm-2.jpg
        """, context: context)
        let clients = DataImportService.importClients(from: """
        Notes,ID,Last Name,First Name,Email,Phone,Emergency Contact,Emergency Phone,Active
        ,client-1,Doe,Jane,jane@example.com,,,,true
        """, context: context)
        let txns = try DataImportService.importTransactions(from: """
        ID,Date,Type,Category,Amount,Memo,Client,Paid,Client ID
        transaction-1,2026-03-01,income,boarding,50.0,March,Jane Doe,true,client-1
        """, context: context)

        XCTAssertEqual([horses.imported, clients.imported, txns.imported], [2, 1, 1])
        XCTAssertEqual([horses.skipped, clients.skipped, txns.skipped], [0, 0, 0])
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<Horse>()).map(\.breed)), ["Arabian", "Quarter Horse"])
        let client = try XCTUnwrap(context.fetch(FetchDescriptor<Client>()).first)
        XCTAssertEqual([client.firstName, client.lastName, client.email], ["Jane", "Doe", "jane@example.com"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).first?.client?.fullName, "Jane Doe")
    }
}
