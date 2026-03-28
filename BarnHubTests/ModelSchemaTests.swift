import XCTest
import SwiftData
@testable import BarnHub

/// Verifies all 12 SwiftData model types can be inserted and persisted in an
/// in-memory container without throwing.
final class ModelSchemaTests: XCTestCase {

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

    func test_Horse_canBeInsertedAndFetched() throws {
        let h = Horse(name: "Blaze")
        context.insert(h)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Blaze")
    }

    func test_Client_canBeInsertedAndFetched() throws {
        let c = Client(firstName: "Anna", lastName: "Smith")
        context.insert(c)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Client>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fullName, "Anna Smith")
    }

    func test_Transaction_canBeInsertedAndFetched() throws {
        let t = Transaction(amount: 250.0, memo: "Boarding fee", category: .boarding, type: .income)
        context.insert(t)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.amount, 250.0)
    }

    func test_VetRecord_canBeInsertedAndFetched() throws {
        let v = VetRecord(vetName: "Dr. Hooves", descriptionText: "Annual checkup")
        context.insert(v)
        try context.save()
        let results = try context.fetch(FetchDescriptor<VetRecord>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.vetName, "Dr. Hooves")
    }

    func test_FarrierVisit_canBeInsertedAndFetched() throws {
        let f = FarrierVisit(farrierName: "Joe", serviceDescription: "Trim")
        context.insert(f)
        try context.save()
        let results = try context.fetch(FetchDescriptor<FarrierVisit>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.farrierName, "Joe")
    }

    func test_SupplyItem_canBeInsertedAndFetched() throws {
        let s = SupplyItem(name: "Hay", quantity: 50, reorderThreshold: 10)
        context.insert(s)
        try context.save()
        let results = try context.fetch(FetchDescriptor<SupplyItem>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Hay")
    }

    func test_Reminder_canBeInsertedAndFetched() throws {
        let r = Reminder(title: "Deworming")
        context.insert(r)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Reminder>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Deworming")
    }

    func test_Invoice_canBeInsertedAndFetched() throws {
        let i = Invoice(totalAmount: 500.0)
        context.insert(i)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Invoice>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.totalAmount, 500.0)
    }

    func test_WeightEntry_canBeInsertedAndFetched() throws {
        let w = WeightEntry(weight: 1100.0)
        context.insert(w)
        try context.save()
        let results = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.weight, 1100.0)
    }

    func test_ClientDocument_canBeInsertedAndFetched() throws {
        let d = ClientDocument(title: "Contract 2026", documentType: .pdf)
        context.insert(d)
        try context.save()
        let results = try context.fetch(FetchDescriptor<ClientDocument>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Contract 2026")
    }

    func test_BarnNote_canBeInsertedAndFetched() throws {
        let n = BarnNote(content: "Barn door needs repair", category: .maintenance)
        context.insert(n)
        try context.save()
        let results = try context.fetch(FetchDescriptor<BarnNote>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Barn door needs repair")
        XCTAssertEqual(results.first?.category, .maintenance)
    }

    func test_Lesson_canBeInsertedAndFetched() throws {
        let l = Lesson(duration: 45, lessonType: .group, cost: 80.0)
        context.insert(l)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.duration, 45)
        XCTAssertEqual(results.first?.lessonType, .group)
    }
}
