import XCTest
import SwiftData
@testable import BarnHub

/// "All Data" export: one CSV per record type, related records named by their
/// horse or client and linked by export-scoped IDs, with photos, documents and
/// invoice PDFs copied next to the CSVs, written into a per-share temp folder.
final class AllDataExportTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let options = CSVOptions(timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: Locale(identifier: "en_US"))

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(for: BarnHubSchema.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = options.timeZone
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Two horses, two clients, and a known number of every other record.
    private func seed() throws {
        let storm = Horse(name: "Storm")
        let daisy = Horse(name: "Daisy")
        let jane = Client(firstName: "Jane", lastName: "Doe")
        let sam = Client(firstName: "Sam", lastName: "Lee")
        [storm, daisy].forEach(context.insert)
        [jane, sam].forEach(context.insert)
        storm.clients = [jane, sam]
        daisy.clients = [jane]

        let txn = Transaction(amount: 50, date: date(2026, 3, 1), category: .boarding, type: .income)
        txn.client = jane
        context.insert(txn)

        let vet = VetRecord(date: date(2026, 3, 2), vetName: "Dr. Hart", descriptionText: "Coggins", cost: 85,
                            nextDueDate: date(2027, 3, 2), reminderFrequency: .annually)
        vet.horse = storm
        context.insert(vet)
        let vet2 = VetRecord(date: date(2026, 4, 2), vetName: "Dr. Hart", descriptionText: "Vaccines")
        vet2.horse = daisy
        context.insert(vet2)

        let farrier = FarrierVisit(date: date(2026, 3, 3), farrierName: "Ben", serviceDescription: "Trim", cost: 60)
        farrier.horse = storm
        context.insert(farrier)

        let dentist = DentistVisit(date: date(2026, 3, 4), dentistName: "Ana", serviceDescription: "Float", cost: 120)
        dentist.horse = daisy
        context.insert(dentist)

        for (i, lbs) in [1100.0, 1112.5, 1120].enumerated() {
            let entry = WeightEntry(date: date(2026, 1, 1 + i), weight: lbs)
            entry.horse = storm
            context.insert(entry)
        }

        let grain = FeedProduct(name: "Senior Feed", brand: "Acme", defaultUnit: .lbs)
        context.insert(grain)
        let plan = FeedPlanEntry(amount: 2.5, unit: .lbs, feedTime: .evening, assignedPerson: "Kim")
        plan.horse = storm
        plan.product = grain
        context.insert(plan)

        let reminder = Reminder(title: "Deworm", dueDate: date(2026, 5, 1, hour: 7, minute: 30), frequency: .monthly)
        reminder.horse = daisy
        context.insert(reminder)

        let lesson = Lesson(date: date(2026, 5, 2, hour: 16, minute: 15), duration: 45, cost: 70, isPaid: true)
        lesson.client = jane
        lesson.horse = storm
        context.insert(lesson)

        context.insert(BarnNote(content: "Fence fixed", date: date(2026, 5, 3), category: .general, horse: storm))
        context.insert(SupplyItem(name: "Shavings", categoryRaw: "Bedding", quantity: 12, unit: "bags", reorderThreshold: 4))

        let invoice = Invoice(startDate: date(2026, 4, 1), endDate: date(2026, 4, 30), totalAmount: 700, createdAt: date(2026, 5, 1))
        invoice.client = jane
        context.insert(invoice)

        let coggins = HorseDocument(title: "Coggins", documentType: .pdf, fileData: Data([1, 2, 3]))
        coggins.horse = storm
        context.insert(coggins)
        let contract = ClientDocument(title: "Boarding contract", documentType: .pdf, fileData: Data([4, 5]))
        contract.client = sam
        context.insert(contract)

        try context.save()
    }

    /// Expected data rows (header excluded) for the seeded store.
    private let expectedRows: [CSVExportKind: Int] = [
        .horses: 2, .clients: 2, .transactions: 1, .horseClients: 3, .vetRecords: 2, .farrierVisits: 1,
        .dentistVisits: 1, .weightEntries: 3, .feedProducts: 1, .feedPlan: 1, .reminders: 1, .lessons: 1,
        .barnNotes: 1, .supplies: 1, .invoices: 1, .horseDocuments: 1, .clientDocuments: 1,
    ]

    private func parse(_ csv: String) -> [[String]] {
        let reader = CSVReader(string: csv)
        var rows: [[String]] = []
        while let row = reader.nextRow() { rows.append(row) }
        return rows
    }

    private func rows(_ kind: CSVExportKind) throws -> [[String]] {
        let csv = try DataExportService.exportCSV(kind, from: context, options: options)
        return parse(csv)
    }

    func test_everyKind_hasExpectedRowCount() {
        XCTAssertEqual(Set(expectedRows.keys), Set(CSVExportKind.allCases), "Add expected rows for every new export kind")
    }

    func test_allDataExport_writesOneFilePerKindWithHeaderAndRows() async throws {
        try seed()
        let folder = try ShareTempFiles.makeShareFolder()
        defer { ShareTempFiles.discardShareFolder(folder) }

        let options = self.options
        let container = self.container!
        let urls = try await Task.detached {
            try await CSVDataActor(modelContainer: container).export(CSVExportKind.allCases, to: folder, options: options, progress: nil)
        }.value

        XCTAssertEqual(urls.map(\.lastPathComponent), CSVExportKind.allCases.map { "\($0.rawValue).csv" })
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(files.count, CSVExportKind.allCases.count)

        for (kind, url) in zip(CSVExportKind.allCases, urls) {
            let parsed = parse(try String(contentsOf: url, encoding: .utf8))
            XCTAssertEqual(parsed.first, DataExportService.header(for: kind), "\(kind) header")
            XCTAssertEqual(parsed.count - 1, expectedRows[kind], "\(kind) rows")
            for row in parsed.dropFirst() {
                XCTAssertEqual(row.count, parsed[0].count, "\(kind) column count")
            }
        }
    }

    func test_emptyStore_everyKindWritesHeaderOnly() throws {
        for kind in CSVExportKind.allCases {
            XCTAssertEqual(try rows(kind), [DataExportService.header(for: kind)], "\(kind)")
        }
    }

    func test_existingHeaders_areUnchangedForReimport() {
        XCTAssertEqual(DataExportService.horsesHeader.joined(separator: ","),
                       "Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active,Gender")
        XCTAssertEqual(DataExportService.clientsHeader.joined(separator: ","),
                       "First Name,Last Name,Email,Phone,Emergency Contact,Emergency Phone,Notes,Active")
        XCTAssertEqual(DataExportService.transactionsHeader.joined(separator: ","), "Date,Type,Category,Amount,Memo,Client,Paid")
    }

    func test_relatedRecords_nameTheirHorseAndClient() throws {
        try seed()
        XCTAssertEqual(try rows(.horseClients).dropFirst().map { $0 },
                       [["Daisy", "Jane Doe"], ["Storm", "Jane Doe"], ["Storm", "Sam Lee"]])
        XCTAssertEqual(try rows(.vetRecords)[2], ["2026-03-02", "Storm", "Dr. Hart", "Coggins", "85.0", "2027-03-02", "annually"])
        XCTAssertEqual(try rows(.farrierVisits)[1], ["2026-03-03", "Storm", "Ben", "Trim", "60.0", ""])
        XCTAssertEqual(try rows(.dentistVisits)[1], ["2026-03-04", "Daisy", "Ana", "Float", "120.0", ""])
        XCTAssertEqual(try rows(.weightEntries)[2], ["2026-01-02", "Storm", "1112.5"])
        XCTAssertEqual(try rows(.feedProducts)[1], ["Senior Feed", "Acme", FeedUnit.lbs.rawValue, ""])
        XCTAssertEqual(try rows(.feedPlan)[1], ["Storm", FeedTime.evening.rawValue, "Senior Feed", "Acme", "2.5",
                                                FeedUnit.lbs.rawValue, "Kim", ""])
        XCTAssertEqual(try rows(.barnNotes)[1], ["2026-05-03", BarnNoteCategory.general.rawValue, "Storm", "Fence fixed"])
        XCTAssertEqual(try rows(.supplies)[1], ["Shavings", "Bedding", "12.0", "bags", "4.0", ""])
        XCTAssertEqual(try rows(.invoices)[1], ["2026-05-01", "Jane Doe", "2026-04-01", "2026-04-30", "700.0"])
        XCTAssertEqual(try rows(.horseDocuments)[1].dropFirst().map { $0 }, ["Storm", "Coggins", DocumentType.pdf.rawValue])
        XCTAssertEqual(try rows(.clientDocuments)[1].dropFirst().map { $0 }, ["Sam Lee", "Boarding contract", DocumentType.pdf.rawValue])
    }

    func test_lessonsAndReminders_includeLocalTime() throws {
        try seed()
        XCTAssertEqual(try rows(.reminders)[1], ["2026-05-01", "07:30", "Deworm", "Daisy", ReminderFrequency.monthly.rawValue, "false", ""])
        XCTAssertEqual(try rows(.lessons)[1], ["2026-05-02", "16:15", "45", LessonType.privateLesson.rawValue, "Jane Doe", "Storm",
                                               "70.0", "true", ReminderFrequency.once.rawValue, "", ""])
    }

    // MARK: - All Data bundle (IDs and files)

    private func exportAllData(step: CSVStepHandler? = nil) async throws -> URL {
        let options = self.options
        let container = self.container!
        return try await Task.detached {
            try await CSVDataActor(modelContainer: container).exportAllData(options: options, progress: nil, step: step)
        }.value
    }

    /// Parsed rows of `kind`'s bundle file as header-name dictionaries.
    private func records(_ kind: CSVExportKind, in folder: URL) throws -> [[String: String]] {
        let parsed = parse(try String(contentsOf: folder.appendingPathComponent("\(kind.rawValue).csv"), encoding: .utf8))
        guard let header = parsed.first else { return [] }
        return parsed.dropFirst().map { Dictionary(uniqueKeysWithValues: zip(header, $0)) }
    }

    private func shareFolders() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: ShareTempFiles.rootDirectory.path)) ?? [])
    }

    func test_exportAllData_everyFileHasBundleHeaderAndUniqueIDs() async throws {
        try seed()
        let folder = try await exportAllData()
        defer { ShareTempFiles.discardShareFolder(folder.deletingLastPathComponent()) }
        XCTAssertEqual(folder.lastPathComponent, "BarnHub Export")

        for kind in CSVExportKind.allCases {
            let parsed = parse(try String(contentsOf: folder.appendingPathComponent("\(kind.rawValue).csv"), encoding: .utf8))
            XCTAssertEqual(parsed.first, DataExportService.bundleHeader(for: kind), "\(kind) header")
            XCTAssertEqual(parsed.first?.first, "ID", "\(kind) starts with ID")
            XCTAssertEqual(parsed.count - 1, expectedRows[kind], "\(kind) rows")
            let ids = parsed.dropFirst().map { $0[0] }
            XCTAssertEqual(Set(ids).count, ids.count, "\(kind) IDs are unique")
            XCTAssertFalse(ids.contains(""), "\(kind) every row has an ID")
            for row in parsed.dropFirst() {
                XCTAssertEqual(row.count, parsed[0].count, "\(kind) column count")
            }
        }
    }

    func test_exportAllData_copiesFilesIntoSubfoldersAndRowsPointAtThem() async throws {
        try seed()
        let storm = try context.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Storm" })).first!
        storm.photoData = Data("storm photo".utf8)
        try context.fetch(FetchDescriptor<FeedProduct>()).first!.photoData = Data("feed photo".utf8)
        try context.fetch(FetchDescriptor<Invoice>()).first!.pdfData = Data("%PDF invoice".utf8)
        try context.save()

        let folder = try await exportAllData()
        defer { ShareTempFiles.discardShareFolder(folder.deletingLastPathComponent()) }

        func file(_ path: String?) throws -> Data {
            let path = try XCTUnwrap(path)
            XCTAssertFalse(path.hasPrefix("/"), "paths are relative")
            return try Data(contentsOf: folder.appendingPathComponent(path))
        }

        let horses = try records(.horses, in: folder)
        let stormRow = try XCTUnwrap(horses.first { $0["Name"] == "Storm" })
        XCTAssertEqual(stormRow["Photo"], "Photos/Horses/Storm.jpg")
        XCTAssertEqual(try file(stormRow["Photo"]), Data("storm photo".utf8))
        XCTAssertEqual(horses.first { $0["Name"] == "Daisy" }?["Photo"], "", "no photo, no path")

        let feed = try records(.feedProducts, in: folder)
        XCTAssertEqual(feed.first?["Photo"], "Photos/Feed/Senior_Feed.jpg")
        XCTAssertEqual(try file(feed.first?["Photo"]), Data("feed photo".utf8))

        let horseDocs = try records(.horseDocuments, in: folder)
        XCTAssertEqual(horseDocs.first?["File"], "Documents/Horses/Storm/Coggins.pdf")
        XCTAssertEqual(try file(horseDocs.first?["File"]), Data([1, 2, 3]))

        let clientDocs = try records(.clientDocuments, in: folder)
        XCTAssertEqual(clientDocs.first?["File"], "Documents/Clients/Sam_Lee/Boarding_contract.pdf")
        XCTAssertEqual(try file(clientDocs.first?["File"]), Data([4, 5]))

        let invoices = try records(.invoices, in: folder)
        XCTAssertEqual(invoices.first?["File"], "Invoices/Invoice_Jane_Doe_2026-04-01_2026-04-30.pdf")
        XCTAssertEqual(try file(invoices.first?["File"]), Data("%PDF invoice".utf8))
    }

    func test_exportAllData_sameNamedRecordsGetDistinctIDsFoldersAndFiles() async throws {
        let first = Horse(name: "Storm")
        let second = Horse(name: "Storm")
        first.photoData = Data("first".utf8)
        second.photoData = Data("second".utf8)
        let janeA = Client(firstName: "Jane", lastName: "Doe")
        let janeB = Client(firstName: "Jane", lastName: "Doe")
        [first, second].forEach(context.insert)
        [janeA, janeB].forEach(context.insert)
        first.clients = [janeA]
        second.clients = [janeB]
        // Newest first is the export order, so "Coggins" is written before "coggins".
        for (i, (horse, title)) in [(first, "Coggins"), (second, "Coggins"), (first, "coggins"), (first, "a/b:c?.pdf")].enumerated() {
            let doc = HorseDocument(title: title, documentType: .pdf, fileData: Data(title.utf8))
            doc.createdAt = date(2026, 1, 10 - i)
            doc.horse = horse
            context.insert(doc)
        }
        let vet = VetRecord(date: date(2026, 3, 2), vetName: "Dr. Hart", descriptionText: "Second Storm")
        vet.horse = second
        context.insert(vet)
        try context.save()

        let folder = try await exportAllData()
        defer { ShareTempFiles.discardShareFolder(folder.deletingLastPathComponent()) }

        let horses = try records(.horses, in: folder)
        XCTAssertEqual(horses.count, 2)
        XCTAssertNotEqual(horses[0]["ID"], horses[1]["ID"])
        let photoByID = Dictionary(uniqueKeysWithValues: horses.map { ($0["ID"]!, $0["Photo"]!) })
        XCTAssertEqual(Set(photoByID.values), ["Photos/Horses/Storm.jpg", "Photos/Horses/Storm-2.jpg"])

        // The vet record's Horse ID resolves to the second Storm (its photo says so).
        let vetRow = try XCTUnwrap(try records(.vetRecords, in: folder).first)
        let vetHorsePhoto = try XCTUnwrap(photoByID[vetRow["Horse ID"]!])
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(vetHorsePhoto)), Data("second".utf8))

        // The link file pairs IDs, not names, and every ID resolves.
        let clientIDs = Set(try records(.clients, in: folder).map { $0["ID"]! })
        let links = try records(.horseClients, in: folder)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(Set(links.map { $0["Horse ID"]! }), Set(photoByID.keys))
        XCTAssertEqual(Set(links.map { $0["Client ID"]! }).count, 2, "two Jane Does stay distinct")
        XCTAssertTrue(Set(links.map { $0["Client ID"]! }).isSubset(of: clientIDs))
        XCTAssertNil(links.first?["Horse"], "no name columns in the link file")

        // Documents: one folder per horse, colliding titles de-duplicated, unsafe characters replaced.
        let docs = try records(.horseDocuments, in: folder)
        let paths = docs.map { $0["File"]! }
        XCTAssertEqual(Set(paths).count, paths.count)
        XCTAssertEqual(Set(paths), Set(["Documents/Horses/Storm/Coggins.pdf", "Documents/Horses/Storm/coggins-2.pdf",
                                        "Documents/Horses/Storm/a-b-c.pdf", "Documents/Horses/Storm-2/Coggins.pdf"]))
        for doc in docs {
            XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(doc["File"]!)), Data(doc["Title"]!.utf8))
        }
    }

    func test_exportAllData_cancelledMidway_discardsPartialFolder() async throws {
        try seed()
        try context.fetch(FetchDescriptor<Horse>()).forEach { $0.photoData = Data($0.name.utf8) }
        try context.save()
        let before = shareFolders()

        do {
            // Cancel once horses (and their photos) are written, while transactions start.
            _ = try await exportAllData { index, _, _ in
                if index == 3 { withUnsafeCurrentTask { $0?.cancel() } }
            }
            XCTFail("expected cancellation")
        } catch is CancellationError {
        }
        XCTAssertEqual(shareFolders(), before, "the partial share folder is deleted")
    }

    func test_bundleFiles_reimportHorsesClientsAndTransactions() async throws {
        try seed()
        let folder = try await exportAllData()
        defer { ShareTempFiles.discardShareFolder(folder.deletingLastPathComponent()) }

        let target = try ModelContainer(for: BarnHubSchema.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let targetContext = ModelContext(target)
        func importFile(_ kind: CSVExportKind, _ body: (CSVReader) throws -> DataImportService.ImportResult) throws -> DataImportService.ImportResult {
            try body(CSVReader(url: folder.appendingPathComponent("\(kind.rawValue).csv")))
        }
        let horses = try importFile(.horses) { try DataImportService.importHorses(reader: $0, context: targetContext, options: options) }
        let clients = try importFile(.clients) { try DataImportService.importClients(reader: $0, context: targetContext, options: options) }
        let txns = try importFile(.transactions) { try DataImportService.importTransactions(reader: $0, context: targetContext, options: options) }
        XCTAssertEqual([horses.imported, clients.imported, txns.imported], [2, 2, 1])
        XCTAssertEqual([horses.skipped, clients.skipped, txns.skipped], [0, 0, 0])
        XCTAssertEqual(Set(try targetContext.fetch(FetchDescriptor<Horse>()).map(\.name)), ["Storm", "Daisy"])
        XCTAssertEqual(try targetContext.fetch(FetchDescriptor<Transaction>()).first?.client?.fullName, "Jane Doe")
    }

    // MARK: - Share folder

    func test_shareFolder_cleanUpRemovesExportSubfolder() throws {
        let folder = try ShareTempFiles.makeShareFolder()
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, ShareTempFiles.rootDirectory.standardizedFileURL)
        let exportFolder = folder.appendingPathComponent("BarnHub Export", isDirectory: true)
        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        try Data("a\n".utf8).write(to: exportFolder.appendingPathComponent("horses.csv"))

        ShareTempFiles.cleanUp(exportFolder)
        #if os(macOS)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path), "macOS keeps the share until the next launch")
        ShareTempFiles.discardShareFolder(folder)
        #endif
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func test_discardShareFolder_ignoresFoldersOutsideShareRoot() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        ShareTempFiles.discardShareFolder(outside)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
}
