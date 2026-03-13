import XCTest
import SwiftData
@testable import BarnBook

final class BarnBookTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    func testHorseCreation() {
        let horse = Horse()
        horse.name = "Thunder"
        horse.breed = "Thoroughbred"
        context.insert(horse)
        try! context.save()

        let descriptor = FetchDescriptor<Horse>()
        let horses = try! context.fetch(descriptor)
        XCTAssertEqual(horses.count, 1)
        XCTAssertEqual(horses.first?.name, "Thunder")
    }

    func testClientFullName() {
        let client = Client()
        client.firstName = "Jane"
        client.lastName = "Doe"
        XCTAssertEqual(client.fullName, "Jane Doe")
    }

    func testTransactionEnums() {
        let transaction = Transaction()
        transaction.category = .lesson
        XCTAssertEqual(transaction.categoryRaw, "lesson")
        transaction.type = .income
        XCTAssertEqual(transaction.typeRaw, "income")
    }

    func testSupplyItemLowStock() {
        let item = SupplyItem()
        item.quantity = 5
        item.reorderThreshold = 10
        XCTAssertTrue(item.isLowStock)
        item.quantity = 15
        XCTAssertFalse(item.isLowStock)
    }

    func testReminderNextOccurrence() {
        let reminder = Reminder()
        reminder.dueDate = Date()
        reminder.frequency = .weekly
        let next = reminder.nextOccurrence()
        XCTAssertNotNil(next)
    }

    func testHorseClientRelationship() {
        let horse = Horse()
        horse.name = "Star"
        let client = Client()
        client.firstName = "John"
        context.insert(horse)
        context.insert(client)
        horse.clients = [client]
        try! context.save()
        XCTAssertEqual(horse.clients?.count, 1)
    }

    func testCurrencyFormatting() {
        let value = 150.50
        XCTAssertTrue(value.asCurrency.contains("150"))
    }
}
