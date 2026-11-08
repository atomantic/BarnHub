import XCTest
import SwiftData
import CoreGraphics
@testable import BarnHub

/// Restore All Data (#71): an All Data export folder restored into the store,
/// with its photos, documents, invoice PDFs and ID links.
final class AllDataRestoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var exportFolders: [URL] = []
    private let options = CSVOptions(timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: Locale(identifier: "en_US"))

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(for: BarnHubSchema.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    override func tearDown() {
        for folder in exportFolders { ShareTempFiles.discardShareFolder(folder.deletingLastPathComponent()) }
        exportFolders = []
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = options.timeZone
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// A small real JPEG, so thumbnails can be generated from it.
    private func jpeg(_ shade: CGFloat) -> Data {
        let cg = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        cg.setFillColor(red: shade, green: 0.4, blue: 1 - shade, alpha: 1)
        cg.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        return ImageProcessing.jpegData(from: cg.makeImage()!)!
    }

    /// Every record type, with twin horses (same name, breed and birth date,
    /// different photos and history), two Jane Does sharing an email, a
    /// many-to-many horse/client web, photos, documents and invoice PDFs.
    private func seed() throws {
        let dob = date(2015, 4, 20)
        let stormA = Horse(name: "Storm", breed: "Arabian", dateOfBirth: dob, colorMarkings: "Grey, star", weight: 950,
                           purchasePrice: 2500.75, medicalNotes: "=Allergic, to \"dust\"\nsecond line", feedingSchedule: "AM/PM",
                           stallNumber: "4", gender: .gelding, photoData: jpeg(0.1))
        let stormB = Horse(name: "Storm", breed: "Arabian", dateOfBirth: dob, colorMarkings: "Grey, star", weight: 950,
                           purchasePrice: 2500.75, medicalNotes: "=Allergic, to \"dust\"\nsecond line", feedingSchedule: "AM/PM",
                           stallNumber: "4", gender: .gelding, photoData: jpeg(0.9))
        let daisy = Horse(name: "Daisy", breed: "Pony", dateOfBirth: date(2010, 1, 2), gender: .mare, isActive: false)
        let janeA = Client(firstName: "Jane", lastName: "Doe", email: "jane@example.com", phone: "555-0100")
        let janeB = Client(firstName: "Jane", lastName: "Doe", email: "jane@example.com", phone: "555-0199", notes: "Second Jane")
        let sam = Client(firstName: "Sam", lastName: "Lee", phone: "+1 555 0101", emergencyContact: "Pat", emergencyPhone: "555-0102",
                         isActive: false)
        [stormA, stormB, daisy].forEach(context.insert)
        [janeA, janeB, sam].forEach(context.insert)
        stormA.clients = [janeA, sam]
        stormB.clients = [janeB]
        daisy.clients = [janeA, janeB, sam]

        for (amount, client, memo) in [(50.0, janeA, "Board, March"), (75, janeB, "Board, March"), (12.5, nil, "-Hay")] as [(Double, Client?, String)] {
            let txn = Transaction(amount: amount, date: date(2026, 3, 1), memo: memo, category: .boarding, type: .income, isPaid: client != nil)
            context.insert(txn)
            txn.client = client
        }

        let vetBill = Transaction(amount: 85, date: date(2026, 3, 2), memo: "Coggins", category: .vetBill, type: .expense)
        context.insert(vetBill)

        for (horse, description) in [(stormA, "Coggins"), (stormB, "Vaccines"), (daisy, "Coggins")] {
            let vet = VetRecord(date: date(2026, 3, 2), vetName: "Dr. Hart", descriptionText: description, cost: 85,
                                nextDueDate: date(2027, 3, 2), reminderFrequency: .annually)
            context.insert(vet)
            vet.horse = horse
        }
        let farrier = FarrierVisit(date: date(2026, 3, 3), farrierName: "Ben", serviceDescription: "Trim", cost: 60, nextDueDate: date(2026, 5, 3))
        context.insert(farrier)
        farrier.horse = stormB
        let dentist = DentistVisit(date: date(2026, 3, 4), dentistName: "Ana", serviceDescription: "Float", cost: 120)
        context.insert(dentist)
        dentist.horse = daisy
        // Two identical weigh-ins on one day are both kept.
        for lbs in [1100.0, 1112.5, 1112.5] {
            let entry = WeightEntry(date: date(2026, 1, 1), weight: lbs)
            context.insert(entry)
            entry.horse = stormA
        }

        let grain = FeedProduct(name: "Senior Feed", brand: "Acme", notes: "Soak first", defaultUnit: .lbs, photoData: jpeg(0.5))
        let hay = FeedProduct(name: "Timothy", brand: "", defaultUnit: .flakes)
        [grain, hay].forEach(context.insert)
        for (horse, product, time) in [(stormA, grain, FeedTime.evening), (stormB, grain, .morning), (daisy, hay, .morning)] {
            let plan = FeedPlanEntry(amount: 2.5, unit: product.defaultUnit, feedTime: time, assignedPerson: "Kim", notes: "Wet")
            context.insert(plan)
            plan.horse = horse
            plan.product = product
        }

        let reminder = Reminder(title: "Deworm", notes: "Rotate paste", dueDate: date(2026, 5, 1, hour: 7, minute: 30), frequency: .monthly)
        context.insert(reminder)
        reminder.horse = stormB
        let general = Reminder(title: "Order shavings", dueDate: date(2026, 6, 1, hour: 18, minute: 5), isCompleted: true)
        context.insert(general)

        let lesson = Lesson(date: date(2026, 5, 2, hour: 16, minute: 15), duration: 45, lessonType: .group, notes: "Bring helmet",
                            cost: 70, isPaid: true, frequency: .weekly, nextDate: date(2026, 5, 9))
        context.insert(lesson)
        lesson.client = janeB
        lesson.horse = stormA

        context.insert(BarnNote(content: "Fence fixed, north side", date: date(2026, 5, 3), category: .general, horse: stormA))
        context.insert(BarnNote(content: "Barn-wide note", date: date(2026, 5, 4)))
        context.insert(SupplyItem(name: "Shavings", categoryRaw: "Bedding", quantity: 12, unit: "bags", reorderThreshold: 4,
                                  lastOrderedDate: date(2026, 4, 1)))

        let invoice = Invoice(startDate: date(2026, 4, 1), endDate: date(2026, 4, 30), totalAmount: 700, createdAt: date(2026, 5, 1),
                              pdfData: Data("%PDF-1.4 invoice A".utf8))
        let invoiceB = Invoice(startDate: date(2026, 4, 1), endDate: date(2026, 4, 30), totalAmount: 650, createdAt: date(2026, 5, 1),
                               pdfData: Data("%PDF-1.4 invoice B".utf8))
        let noPDF = Invoice(startDate: date(2026, 3, 1), endDate: date(2026, 3, 31), totalAmount: 10, createdAt: date(2026, 4, 1))
        [invoice, invoiceB, noPDF].forEach(context.insert)
        invoice.client = janeA
        invoiceB.client = janeB
        noPDF.client = sam

        for (horse, title, bytes) in [(stormA, "Coggins", [1, 2, 3]), (stormB, "Coggins", [4, 5]), (stormA, "Papers", [6])] as [(Horse, String, [UInt8])] {
            let doc = HorseDocument(title: title, documentType: .pdf, fileData: Data(bytes))
            doc.createdAt = date(2026, 2, 1)
            context.insert(doc)
            doc.horse = horse
        }
        let contract = ClientDocument(title: "Contract scan", documentType: .photo, fileData: jpeg(0.3))
        contract.createdAt = date(2026, 2, 2)
        context.insert(contract)
        contract.client = janeB

        try context.save()
    }

    /// Photos, documents and invoice PDFs in the seed.
    private let seededFiles = 2 + 1 + 2 + 3 + 1

    /// Everything about the store that All Data exports, as sorted strings per
    /// record type. Owners are described by their fields and photo bytes, so a
    /// record linked to the wrong twin shows up as a difference.
    private func snapshot() throws -> [String: [String]] {
        let context = ModelContext(container)
        let codec = CSVDateCodec(options: options)
        func d(_ date: Date?) -> String { date.map(codec.string(from:)) ?? "-" }
        func t(_ date: Date) -> String { d(date) + " " + codec.timeString(from: date) }
        func bytes(_ data: Data?) -> String { data?.base64EncodedString() ?? "none" }
        func horse(_ h: Horse?) -> String {
            guard let h else { return "no horse" }
            return [h.name, h.breed, d(h.dateOfBirth), h.colorMarkings, "\(h.weight)", "\(h.purchasePrice)", h.stallNumber,
                    h.medicalNotes, h.feedingSchedule, "\(h.isActive)", h.genderRaw, bytes(h.photoData)].joined(separator: "|")
        }
        func client(_ c: Client?) -> String {
            guard let c else { return "no client" }
            return [c.firstName, c.lastName, c.email, c.phone, c.emergencyContact, c.emergencyPhone, c.notes, "\(c.isActive)"].joined(separator: "|")
        }
        func product(_ p: FeedProduct?) -> String {
            guard let p else { return "no product" }
            return [p.name, p.brand, p.defaultUnitRaw, p.notes, bytes(p.photoData)].joined(separator: "|")
        }
        var result: [String: [String]] = [:]
        func add<T: PersistentModel>(_ name: String, _: T.Type, _ describe: (T) -> [String]) throws {
            result[name] = try context.fetch(FetchDescriptor<T>()).map { describe($0).joined(separator: "|") }.sorted()
        }
        try add("horses", Horse.self) { [horse($0), "clients:" + ($0.clients ?? []).map(client).sorted().joined(separator: ";")] }
        try add("clients", Client.self) { [client($0)] }
        try add("transactions", Transaction.self) { [d($0.date), $0.typeRaw, $0.categoryRaw, "\($0.amount)", $0.memo, "\($0.isPaid)", client($0.client)] }
        try add("vet", VetRecord.self) { [d($0.date), $0.vetName, $0.descriptionText, "\($0.cost)", d($0.nextDueDate), $0.reminderFrequencyRaw, horse($0.horse)] }
        try add("farrier", FarrierVisit.self) { [d($0.date), $0.farrierName, $0.serviceDescription, "\($0.cost)", d($0.nextDueDate), horse($0.horse)] }
        try add("dentist", DentistVisit.self) { [d($0.date), $0.dentistName, $0.serviceDescription, "\($0.cost)", d($0.nextDueDate), horse($0.horse)] }
        try add("weight", WeightEntry.self) { [d($0.date), "\($0.weight)", horse($0.horse)] }
        try add("products", FeedProduct.self) { [product($0)] }
        try add("plan", FeedPlanEntry.self) { ["\($0.amount)", $0.unitRaw, $0.feedTimeRaw, $0.assignedPerson, $0.notes, horse($0.horse), product($0.product)] }
        try add("reminders", Reminder.self) { [t($0.dueDate), $0.title, $0.notes, "\($0.isCompleted)", $0.frequencyRaw, horse($0.horse)] }
        try add("lessons", Lesson.self) {
            [t($0.date), "\($0.duration)", $0.lessonTypeRaw, $0.notes, "\($0.cost)", "\($0.isPaid)", $0.frequencyRaw, d($0.nextDate),
             client($0.client), horse($0.horse)]
        }
        try add("notes", BarnNote.self) { [d($0.date), $0.categoryRaw, $0.content, horse($0.horse)] }
        try add("supplies", SupplyItem.self) { [$0.name, $0.categoryRaw, "\($0.quantity)", $0.unit, "\($0.reorderThreshold)", d($0.lastOrderedDate)] }
        try add("invoices", Invoice.self) { [d($0.startDate), d($0.endDate), "\($0.totalAmount)", d($0.createdAt), bytes($0.pdfData), client($0.client)] }
        try add("horseDocs", HorseDocument.self) { [$0.title, $0.typeRaw, d($0.createdAt), bytes($0.fileData), horse($0.horse)] }
        try add("clientDocs", ClientDocument.self) { [$0.title, $0.typeRaw, d($0.createdAt), bytes($0.fileData), client($0.client)] }
        return result
    }

    /// Records plus horse/client links: what a restore into an empty store adds.
    private func recordCount(_ snapshot: [String: [String]]) throws -> Int {
        let links = try ModelContext(container).fetch(FetchDescriptor<Horse>()).reduce(0) { $0 + ($1.clients?.count ?? 0) }
        return snapshot.values.reduce(0) { $0 + $1.count } + links
    }

    private func exportAllData() async throws -> URL {
        let options = self.options
        let container = self.container!
        let folder = try await Task.detached {
            try await CSVDataActor(modelContainer: container).exportAllData(options: options, progress: nil)
        }.value
        exportFolders.append(folder)
        return folder
    }

    private func restore(_ folder: URL, batchSize: Int = 500, step: CSVStepHandler? = nil) async throws -> DataRestoreService.Result {
        var options = self.options
        options.batchSize = batchSize
        let container = self.container!
        return try await Task.detached {
            try await CSVDataActor(modelContainer: container).restoreAllData(from: folder, options: options, progress: nil, step: step)
        }.value
    }

    private func wipe() throws {
        try RecordRemoval.deleteAllData(in: container, keepDocuments: false)
        XCTAssertTrue(try snapshot().values.allSatisfy(\.isEmpty), "store is empty before the restore")
    }

    // MARK: - Tests

    func test_order_readsEveryKindWithOwnersFirst() {
        XCTAssertEqual(Set(DataRestoreService.order), Set(CSVExportKind.allCases))
        XCTAssertEqual(DataRestoreService.order.count, CSVExportKind.allCases.count)
        XCTAssertEqual(Array(DataRestoreService.order.prefix(4)), [.horses, .clients, .feedProducts, .horseClients])
    }

    func test_roundTrip_restoresEveryRecordLinkAndFile() async throws {
        try seed()
        let before = try snapshot()
        let expected = try recordCount(before)
        let folder = try await exportAllData()
        try wipe()

        let result = try await restore(folder)

        XCTAssertEqual(try snapshot(), before)
        XCTAssertEqual(result.imported, expected)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.filesRestored, seededFiles)
        XCTAssertEqual(result.filesMissing, 0)

        // Thumbnails are made from the restored photo, as when a photo is picked.
        let check = ModelContext(container)
        for horse in try check.fetch(FetchDescriptor<Horse>()) {
            if let photo = horse.photoData {
                XCTAssertNotNil(horse.thumbnailData)
                XCTAssertEqual(horse.thumbnailData, ImageProcessing.thumbnailJPEG(from: photo))
            } else {
                XCTAssertNil(horse.thumbnailData)
            }
        }
        let grain = try XCTUnwrap(try check.fetch(FetchDescriptor<FeedProduct>(predicate: #Predicate { $0.name == "Senior Feed" })).first)
        XCTAssertNotNil(grain.thumbnailData)
        // Reminders get notification keys of their own.
        XCTAssertTrue(try check.fetch(FetchDescriptor<Reminder>()).allSatisfy { $0.notificationKey != nil })
    }

    func test_roundTrip_inSmallBatches_linksAcrossSaves() async throws {
        try seed()
        let before = try snapshot()
        let folder = try await exportAllData()
        try wipe()

        // Every two rows are saved and the context replaced, so links resolve
        // through saved IDs rather than objects still in memory.
        let result = try await restore(folder, batchSize: 2)

        XCTAssertEqual(try snapshot(), before)
        XCTAssertEqual(result.imported, try recordCount(before))
    }

    func test_cancelLate_inSmallBatches_removesEveryBatch() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()

        do {
            // Step 17 (client documents) runs after every other file was saved in many batches.
            _ = try await restore(folder, batchSize: 2) { index, _, _ in
                if index == 17 { withUnsafeCurrentTask { $0?.cancel() } }
            }
            XCTFail("expected cancellation")
        } catch is CancellationError {
        }

        XCTAssertTrue(try snapshot().values.allSatisfy(\.isEmpty))
    }

    func test_cancel_withThousandsOfRowsForOneHorse_removesThemAll() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        // 5,000 weigh-ins for the first horse in the file.
        let url = folder.appendingPathComponent("weight_entries.csv")
        var csv = try String(contentsOf: url, encoding: .utf8)
        for i in 0..<5_000 { csv += "extra-\(i),2020-01-01,Storm,\(900 + i),horse-1\n" }
        try csv.write(to: url, atomically: true, encoding: .utf8)

        let start = Date()
        do {
            _ = try await restore(folder) { index, _, _ in
                if index == 17 { withUnsafeCurrentTask { $0?.cancel() } }
            }
            XCTFail("expected cancellation")
        } catch is CancellationError {
        }

        XCTAssertTrue(try snapshot().values.allSatisfy(\.isEmpty))
        XCTAssertLessThan(Date().timeIntervalSince(start), 60, "restore and rollback stay fast")
    }

    /// #77: 20,000 weigh-ins for one horse, restored and then rolled back,
    /// once for a horse that's already in the store and once for one the
    /// restore adds. Both used to slow down with every row.
    func test_cancel_withTwentyThousandRowsForOneHorse_restoresAndRollsBackQuickly() async throws {
        for horseExists in [true, false] {
            try RecordRemoval.deleteAllData(in: container, keepDocuments: false)
            try seed()
            let folder = try await exportAllData()
            if !horseExists { try wipe() }
            let before = try snapshot()
            let url = folder.appendingPathComponent("weight_entries.csv")
            var csv = try String(contentsOf: url, encoding: .utf8)
            for i in 0..<20_000 { csv += "extra-\(i),2020-01-01,Storm,\(900 + Double(i) / 100),horse-1\n" }
            try csv.write(to: url, atomically: true, encoding: .utf8)

            let start = Date()
            var cancelledAt: Date?
            do {
                _ = try await restore(folder) { index, _, _ in
                    // Step 17, the last file, runs after every weigh-in was saved.
                    if index == 17 {
                        cancelledAt = Date()
                        withUnsafeCurrentTask { $0?.cancel() }
                    }
                }
                XCTFail("expected cancellation")
            } catch is CancellationError {
            }
            let end = Date()

            let cancelled = try XCTUnwrap(cancelledAt)
            print("#77 timing horseExists=\(horseExists): restore \(cancelled.timeIntervalSince(start)) s, rollback \(end.timeIntervalSince(cancelled)) s")
            XCTAssertEqual(try snapshot(), before, "horseExists=\(horseExists)")
            // Generous ceiling (well under 10 s on an M-series simulator) so a slow runner doesn't flake.
            XCTAssertLessThan(end.timeIntervalSince(start), 30, "restore and rollback stay fast, horseExists=\(horseExists)")
        }
    }

    /// Restore's "Delete All Data, Then Restore": the store ends up as the
    /// export, with nothing left from before.
    func test_deleteAllDataThenRestore_leavesExactlyTheExport() async throws {
        for keepDocuments in [false, true] {
            try RecordRemoval.deleteAllData(in: container, keepDocuments: false)
            try seed()
            let exported = try snapshot()
            let folder = try await exportAllData()
            // Edits made after the export: a new horse, a changed client and a photo the export doesn't have.
            context.insert(Horse(name: "Leftover", breed: "Mustang"))
            let sam = try XCTUnwrap(try context.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.firstName == "Sam" })).first)
            sam.phone = "555-9999"
            let daisy = try XCTUnwrap(try context.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Daisy" })).first)
            daisy.photoData = jpeg(0.3)
            try context.save()
            XCTAssertNotEqual(try snapshot(), exported)

            try RecordRemoval.deleteAllData(in: container, keepDocuments: keepDocuments)
            _ = try await restore(folder)

            // With Keep Documents, the kept twin horses and Jane B are matched to
            // their own rows, not to the twin listed first (#81).
            XCTAssertEqual(try snapshot(), exported, "keepDocuments=\(keepDocuments)")
        }
    }

    /// Reverses the data rows of one of the export's CSV files, so its rows
    /// come in the opposite order to the store's fetch order.
    private func reverseRows(of kind: CSVExportKind, in folder: URL) throws {
        let url = folder.appendingPathComponent("\(kind.rawValue).csv")
        let reader = try CSVReader(url: url)
        let header = try XCTUnwrap(reader.nextRow())
        var rows: [[String]] = []
        while let row = reader.nextRow() { rows.append(row) }
        let writer = try CSVWriter(url: url)
        try writer.writeRow(header)
        for row in rows.reversed() { try writer.writeRow(row) }
        try writer.finish()
    }

    /// Twin horses kept by Keep Documents are told apart by photo even when the
    /// export lists them in the opposite order to the store (#85).
    func test_keepDocumentsThenRestore_matchesTwinHorsesByPhoto_whateverTheOrder() async throws {
        try seed()
        let exported = try snapshot()
        let folder = try await exportAllData()
        try reverseRows(of: .horses, in: folder)

        try RecordRemoval.deleteAllData(in: container, keepDocuments: true)
        _ = try await restore(folder)

        XCTAssertEqual(try snapshot(), exported)
        let storms = try ModelContext(container).fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Storm" }))
        XCTAssertEqual(storms.count, 2)
        let stormB = try XCTUnwrap(storms.first { $0.photoData == jpeg(0.9) })
        XCTAssertEqual(stormB.vetRecords?.map(\.descriptionText), ["Vaccines"])
        XCTAssertEqual(stormB.farrierVisits?.count, 1)
        XCTAssertEqual(stormB.weightEntries?.count ?? 0, 0)
    }

    /// Twin feed products are told apart by photo too: a feed plan entry
    /// restored into the store goes to the product with its row's photo (#85).
    func test_restoreIntoStore_matchesTwinFeedProductsByPhoto_whateverTheOrder() async throws {
        try seed()
        let daisy = try XCTUnwrap(try context.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Daisy" })).first)
        let twin = FeedProduct(name: "Senior Feed", brand: "Acme", notes: "Soak first", defaultUnit: .lbs, photoData: jpeg(0.7))
        context.insert(twin)
        let plan = FeedPlanEntry(amount: 1, unit: .lbs, feedTime: .evening, assignedPerson: "Kim", notes: "")
        context.insert(plan)
        plan.horse = daisy
        plan.product = twin
        try context.save()
        let exported = try snapshot()
        let folder = try await exportAllData()
        try reverseRows(of: .feedProducts, in: folder)
        context.delete(plan)
        try context.save()

        let result = try await restore(folder)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(try snapshot(), exported)
    }

    func test_roundTrip_keepsSameNamedHorsesAndClientsDistinct() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        _ = try await restore(folder)

        let check = ModelContext(container)
        let storms = try check.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Storm" }))
        XCTAssertEqual(storms.count, 2)
        let stormB = try XCTUnwrap(storms.first { $0.farrierVisits?.isEmpty == false })
        XCTAssertEqual(stormB.vetRecords?.map(\.descriptionText), ["Vaccines"])
        XCTAssertEqual(stormB.clients?.map(\.phone), ["555-0199"])
        XCTAssertEqual(stormB.documents?.map(\.fileData), [Data([4, 5])])

        let janes = try check.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.firstName == "Jane" }))
        XCTAssertEqual(janes.count, 2)
        let janeB = try XCTUnwrap(janes.first { $0.phone == "555-0199" })
        XCTAssertEqual(janeB.transactions?.map(\.amount), [75])
        XCTAssertEqual(janeB.invoices?.map(\.pdfData), [Data("%PDF-1.4 invoice B".utf8)])
        XCTAssertEqual((janeB.horses ?? []).map(\.name).sorted(), ["Daisy", "Storm"])
        XCTAssertEqual(janeB.lessons?.count, 1)
    }

    func test_restoringTwice_addsNothing() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        let first = try await restore(folder)
        let afterFirst = try snapshot()

        let second = try await restore(folder)

        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.duplicates, first.imported)
        XCTAssertEqual(second.filesRestored, 0, "duplicates don't read their files")
        XCTAssertEqual(try snapshot(), afterFirst)
    }

    func test_restoringIntoTheExportedStore_addsNothing() async throws {
        try seed()
        let before = try snapshot()
        let folder = try await exportAllData()

        let result = try await restore(folder)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.duplicates, try recordCount(before))
        XCTAssertEqual(try snapshot(), before)
    }

    func test_restoringIntoAnEditedStore_addsOnlyWhatIsMissing() async throws {
        try seed()
        let folder = try await exportAllData()
        // Since the export: a vet record was deleted, a link removed and a
        // horse's stall changed. Restoring brings back the record and the link
        // and leaves the edited horse as it is.
        let daisy = try XCTUnwrap(try context.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Daisy" })).first)
        context.delete(try XCTUnwrap(daisy.vetRecords?.first))
        daisy.clients = (daisy.clients ?? []).filter { $0.firstName != "Sam" }
        daisy.stallNumber = "9"
        try context.save()

        let result = try await restore(folder)

        XCTAssertEqual(result.imported, 2)
        let check = ModelContext(container)
        let restored = try XCTUnwrap(try check.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.name == "Daisy" })).first)
        XCTAssertEqual(restored.stallNumber, "9")
        XCTAssertEqual(restored.vetRecords?.map(\.descriptionText), ["Coggins"])
        XCTAssertEqual((restored.clients ?? []).map(\.firstName).sorted(), ["Jane", "Jane", "Sam"])
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<Horse>()), 3)
    }

    func test_cancel_removesEverythingTheRestoreAdded() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        // Records that were already there, matching the export: they stay, and
        // the link the restore adds between them is removed again.
        let daisy = Horse(name: "Daisy", breed: "Pony", dateOfBirth: date(2010, 1, 2))
        let sam = Client(firstName: "Sam", lastName: "Lee")
        context.insert(daisy)
        context.insert(sam)
        try context.save()
        let before = try snapshot()

        do {
            // Step 5 (transactions) starts after horses, clients, feed and links were saved.
            _ = try await restore(folder) { index, _, _ in
                if index == 5 { withUnsafeCurrentTask { $0?.cancel() } }
            }
            XCTFail("expected cancellation")
        } catch is CancellationError {
        }

        XCTAssertEqual(try snapshot(), before)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Horse>()).first?.clients?.count ?? 0, 0)
    }

    func test_error_removesEverythingTheRestoreAdded() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        // An unreadable lessons.csv fails the restore after most files are saved.
        let lessons = folder.appendingPathComponent("lessons.csv")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lessons.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: lessons.path) }

        do {
            _ = try await restore(folder)
            XCTFail("expected an error")
        } catch is CancellationError {
            XCTFail("expected a read error, not cancellation")
        } catch {
        }

        XCTAssertTrue(try snapshot().values.allSatisfy(\.isEmpty))
    }

    func test_missingFile_isCountedAndTheRecordStillRestores() async throws {
        try seed()
        let folder = try await exportAllData()
        // The twins' folders are "Storm" and "Storm-2" in fetch order, so look the path up.
        let reader = try CSVReader(url: folder.appendingPathComponent("horse_documents.csv"))
        let header = try XCTUnwrap(reader.nextRow())
        var papersPath: String?
        while let row = reader.nextRow() {
            let record = Dictionary(uniqueKeysWithValues: zip(header, row))
            if record["Title"] == "Papers" { papersPath = record["File"] }
        }
        try FileManager.default.removeItem(at: folder.appendingPathComponent(try XCTUnwrap(papersPath)))
        try wipe()

        let result = try await restore(folder)

        XCTAssertEqual(result.filesMissing, 1)
        XCTAssertEqual(result.filesRestored, seededFiles - 1)
        let papers = try ModelContext(container).fetch(FetchDescriptor<HorseDocument>(predicate: #Predicate { $0.title == "Papers" }))
        XCTAssertEqual(papers.count, 1)
        XCTAssertNil(papers.first?.fileData)
        XCTAssertEqual(papers.first?.horse?.name, "Storm")
    }

    func test_pathsOutsideTheFolder_areNotRead() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        let url = folder.appendingPathComponent("feed_products.csv")
        let csv = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(csv.contains("Photos/Feed/Senior_Feed.jpg"))
        try csv.replacingOccurrences(of: "Photos/Feed/Senior_Feed.jpg", with: "../../outside.jpg").write(to: url, atomically: true, encoding: .utf8)

        let result = try await restore(folder)

        XCTAssertEqual(result.filesMissing, 1)
        let grain = try ModelContext(container).fetch(FetchDescriptor<FeedProduct>(predicate: #Predicate { $0.name == "Senior Feed" })).first
        XCTAssertNotNil(grain)
        XCTAssertNil(grain?.photoData)
    }

    func test_folderAroundTheExport_isAccepted() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        let result = try await restore(folder.deletingLastPathComponent())
        XCTAssertGreaterThan(result.imported, 0)
    }

    func test_folderWithoutAnExport_isRejected() async throws {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        // A single-file export (no ID column) isn't an All Data folder either.
        try "Name,Breed\nStorm,Arabian\n".write(to: empty.appendingPathComponent("horses.csv"), atomically: true, encoding: .utf8)

        do {
            _ = try await restore(empty)
            XCTFail("expected notAnExport")
        } catch let error as DataRestoreService.RestoreError {
            XCTAssertEqual(error, .notAnExport)
        }
        XCTAssertTrue(try snapshot().values.allSatisfy(\.isEmpty))
    }

    func test_linkToUnknownHorse_isSkipped() async throws {
        try seed()
        let folder = try await exportAllData()
        try wipe()
        let url = folder.appendingPathComponent("horse_clients.csv")
        try (try String(contentsOf: url, encoding: .utf8) + "link-99,horse-99,client-1\n").write(to: url, atomically: true, encoding: .utf8)

        let result = try await restore(folder)

        XCTAssertEqual(result.skipReasons, [.unknownLink: 1])
    }
    /// The app's sample data (the -SeedSampleData store) restored into itself adds nothing.
    func test_sampleData_restoredIntoItself_addsNothing() async throws {
        PreviewSampleData.populate(container: container)
        let before = try snapshot()
        let folder = try await exportAllData()

        let result = try await restore(folder)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(try snapshot(), before)
    }
}
