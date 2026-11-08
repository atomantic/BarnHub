import XCTest
import SwiftData
@testable import BarnHub

/// #30: removing a client or horse, or deleting all data, must only remove what
/// the user chose, and edit forms must never re-insert a deleted record.
final class RecordRemovalTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A client with two transactions, an invoice, a lesson and a document.
    @discardableResult
    private func makeClientWithHistory() throws -> Client {
        let client = Client(firstName: "Anna", lastName: "Smith")
        context.insert(client)
        for amount in [100.0, 250.0] {
            let transaction = Transaction(amount: amount, memo: "Board", category: .boarding, type: .income)
            context.insert(transaction)
            transaction.client = client
        }
        let invoice = Invoice(totalAmount: 350)
        context.insert(invoice)
        invoice.client = client
        let lesson = Lesson(duration: 60, lessonType: .privateLesson, cost: 75)
        context.insert(lesson)
        lesson.client = client
        let document = ClientDocument(title: "Contract")
        context.insert(document)
        document.client = client
        try context.save()
        return client
    }

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    private func incomeTotal() throws -> Double {
        try context.fetch(FetchDescriptor<Transaction>()).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Delete All

    /// One of every model type, with documents linked to a horse and a client.
    private func populateEveryModel() throws {
        let horse = Horse(name: "Blaze")
        let client = try makeClientWithHistory()
        context.insert(horse)
        horse.clients = [client]
        let product = FeedProduct(name: "Oats")
        context.insert(product)
        let entry = FeedPlanEntry()
        context.insert(entry)
        entry.horse = horse
        entry.product = product
        let horseDocument = HorseDocument(title: "Coggins")
        context.insert(horseDocument)
        horseDocument.horse = horse
        let vet = VetRecord(vetName: "Dr. Hooves")
        let farrier = FarrierVisit(farrierName: "Joe")
        let dentist = DentistVisit(dentistName: "Dr. Tooth")
        let reminder = Reminder(title: "Worming")
        let weight = WeightEntry(weight: 500)
        let note = BarnNote(content: "Fence", horse: horse)
        for model in [vet, farrier, dentist, reminder, weight, note] as [any PersistentModel] {
            context.insert(model)
        }
        vet.horse = horse
        farrier.horse = horse
        dentist.horse = horse
        reminder.horse = horse
        weight.horse = horse
        context.insert(SupplyItem(name: "Hay", quantity: 50, reorderThreshold: 10))
        context.insert(Horse(name: "No Documents"))
        context.insert(Client(firstName: "No Documents"))
        try context.save()
    }

    private func totalCount(of type: any PersistentModel.Type) throws -> Int {
        try count(type)
    }

    func test_populateEveryModel_coversEverySchemaModel() throws {
        try populateEveryModel()
        for type in BarnHubSchema.models {
            XCTAssertGreaterThan(try totalCount(of: type), 0, "\(type) not populated")
        }
    }

    func test_deleteAllData_leavesZeroRecordsOfEveryModelType() throws {
        try populateEveryModel()

        try RecordRemoval.deleteAllData(in: context, keepDocuments: false)

        for type in BarnHubSchema.models {
            XCTAssertEqual(try totalCount(of: type), 0, "\(type) survived Delete All")
        }
    }

    func test_deleteAllData_keepingDocuments_keepsOnlyDocumentsAndTheirOwners() throws {
        try populateEveryModel()

        try RecordRemoval.deleteAllData(in: context, keepDocuments: true)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Horse>()).map(\.name), ["Blaze"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Client>()).map(\.firstName), ["Anna"])
        XCTAssertEqual(try count(HorseDocument.self), 1)
        XCTAssertEqual(try count(ClientDocument.self), 1)
        let kept: Set<String> = ["Horse", "Client", "HorseDocument", "ClientDocument"]
        for type in BarnHubSchema.models where !kept.contains(String(describing: type)) {
            XCTAssertEqual(try totalCount(of: type), 0, "\(type) survived Delete All")
        }
    }

    func test_schemaModels_matchContainerSchema() {
        XCTAssertEqual(container.schema.entities.count, BarnHubSchema.models.count)
        XCTAssertEqual(BarnHubSchema.models.count, 16)
    }
}
