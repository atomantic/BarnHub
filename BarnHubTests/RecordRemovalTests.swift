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

    // MARK: - Clients

    func test_deactivateClient_keepsEveryLinkedRecord() throws {
        let client = try makeClientWithHistory()
        let totalBefore = try incomeTotal()

        RecordRemoval.deactivate(client, in: context)

        XCTAssertFalse(client.isActive)
        XCTAssertEqual(try count(Client.self), 1)
        XCTAssertEqual(client.transactions?.count, 2)
        XCTAssertEqual(client.invoices?.count, 1)
        XCTAssertEqual(client.lessons?.count, 1)
        XCTAssertEqual(client.documents?.count, 1)
        XCTAssertEqual(try incomeTotal(), totalBefore, "Reports totals must not change")
    }

    func test_deleteClient_keepsTransactionsAndLessonsUnlinked_removesInvoicesAndDocuments() throws {
        let client = try makeClientWithHistory()
        let totalBefore = try incomeTotal()

        RecordRemoval.delete(client, in: context)

        XCTAssertEqual(try count(Client.self), 0)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 2)
        XCTAssertTrue(transactions.allSatisfy { $0.client == nil })
        XCTAssertEqual(try incomeTotal(), totalBefore, "Income stays in Reports")
        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertEqual(lessons.count, 1)
        XCTAssertNil(lessons.first?.client)
        XCTAssertEqual(try count(Invoice.self), 0, "Invoices are only reachable through the client")
        XCTAssertEqual(try count(ClientDocument.self), 0)
    }

    // MARK: - Horses

    func test_markHorseInactive_keepsRecords() throws {
        let horse = Horse(name: "Blaze")
        context.insert(horse)
        let record = VetRecord(vetName: "Dr. Hooves")
        context.insert(record)
        record.horse = horse
        try context.save()

        RecordRemoval.markInactive(horse, in: context)

        XCTAssertFalse(horse.isActive)
        XCTAssertEqual(horse.vetRecords?.count, 1)
    }

    func test_deleteHorse_keepsLessonsUnlinked_removesHealthRecords() throws {
        let horse = Horse(name: "Blaze")
        context.insert(horse)
        let record = VetRecord(vetName: "Dr. Hooves")
        context.insert(record)
        record.horse = horse
        let lesson = Lesson(duration: 45, lessonType: .group, cost: 80)
        context.insert(lesson)
        lesson.horse = horse
        try context.save()

        RecordRemoval.delete(horse, in: context)

        XCTAssertEqual(try count(Horse.self), 0)
        XCTAssertEqual(try count(VetRecord.self), 0)
        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertEqual(lessons.count, 1, "Lessons carry client billing")
        XCTAssertNil(lessons.first?.horse)
    }

    // MARK: - Editing a deleted record

    func test_isDeletedRecord_newRecordIsNeverDeleted() {
        XCTAssertFalse(context.isDeletedRecord(nil, as: Horse.self))
    }

    func test_isDeletedRecord_liveRecordIsNotDeleted() throws {
        let horse = Horse(name: "Blaze")
        context.insert(horse)
        try context.save()
        XCTAssertFalse(context.isDeletedRecord(horse.persistentModelID, as: Horse.self))
    }

    /// Mirrors an edit form's save: guard on `isDeletedRecord`, then update the
    /// existing record or insert a new one.
    func test_savingEditOfDeletedRecord_doesNotInsert() throws {
        let client = Client(firstName: "Gone")
        context.insert(client)
        try context.save()
        let editedID = client.persistentModelID
        context.delete(client)
        try context.save()

        XCTAssertTrue(context.isDeletedRecord(editedID, as: Client.self))
        func save() {
            guard !context.isDeletedRecord(editedID, as: Client.self) else { return }
            if let existing: Client = context.existingModel(for: editedID) {
                existing.firstName = "Edited"
            } else {
                context.insert(Client(firstName: "Edited"))
            }
            try? context.save()
        }
        save()

        XCTAssertEqual(try count(Client.self), 0)
    }

    /// The same, for a record deleted by another context (as when iCloud sync
    /// applies a delete made on another device).
    func test_isDeletedRecord_detectsDeleteFromAnotherContext() throws {
        let note = BarnNote(content: "Fence")
        context.insert(note)
        try context.save()
        let id = note.persistentModelID

        let otherContext = ModelContext(container)
        let otherNote: BarnNote? = otherContext.existingModel(for: id)
        otherContext.delete(try XCTUnwrap(otherNote))
        try otherContext.save()

        let freshContext = ModelContext(container)
        XCTAssertTrue(freshContext.isDeletedRecord(id, as: BarnNote.self))
    }
}
