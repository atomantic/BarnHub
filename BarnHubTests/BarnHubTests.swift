import XCTest
import SwiftData
@testable import BarnHub

final class BarnHubTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self,
            BarnNote.self, Lesson.self,
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

        // Reverse mapping: rawValue -> enum
        for category in TransactionCategory.allCases {
            XCTAssertEqual(TransactionCategory(rawValue: category.rawValue), category)
        }
        for type in TransactionType.allCases {
            XCTAssertEqual(TransactionType(rawValue: type.rawValue), type)
        }

        // Invalid rawValue returns nil
        XCTAssertNil(TransactionCategory(rawValue: "bogus"))
        XCTAssertNil(TransactionType(rawValue: "bogus"))

        // Verify all category rawValues match expected strings
        XCTAssertEqual(TransactionCategory.boarding.rawValue, "boarding")
        XCTAssertEqual(TransactionCategory.training.rawValue, "training")
        XCTAssertEqual(TransactionCategory.vetBill.rawValue, "vetBill")
        XCTAssertEqual(TransactionCategory.farrier.rawValue, "farrier")
        XCTAssertEqual(TransactionCategory.feed.rawValue, "feed")
        XCTAssertEqual(TransactionCategory.supplies.rawValue, "supplies")
        XCTAssertEqual(TransactionCategory.tack.rawValue, "tack")
        XCTAssertEqual(TransactionCategory.other.rawValue, "other")

        // Verify displayName for vetBill special case
        XCTAssertEqual(TransactionCategory.vetBill.displayName, "Vet Bill")
        XCTAssertEqual(TransactionCategory.lesson.displayName, "Lesson")
        XCTAssertEqual(TransactionType.income.displayName, "Income")
        XCTAssertEqual(TransactionType.expense.displayName, "Expense")
    }

    func testSupplyItemLowStock() {
        let item = SupplyItem()
        item.quantity = 5
        item.reorderThreshold = 10
        XCTAssertTrue(item.isLowStock)
        item.quantity = 15
        XCTAssertFalse(item.isLowStock)
    }

    func testSupplyItem_isLowStock_whenQuantityEqualsThreshold() {
        let item = SupplyItem()
        item.quantity = 10
        item.reorderThreshold = 10
        // quantity <= reorderThreshold should be true at boundary
        XCTAssertTrue(item.isLowStock)
    }

    func testSupplyItem_isLowStock_whenQuantityIsZero() {
        let item = SupplyItem()
        item.quantity = 0
        item.reorderThreshold = 0
        // 0 <= 0 → low stock
        XCTAssertTrue(item.isLowStock)
    }

    func testClientFullName_emptyLastName() {
        let client = Client()
        client.firstName = "Jane"
        client.lastName = ""
        XCTAssertEqual(client.fullName, "Jane")
    }

    func testClientFullName_emptyFirstName() {
        let client = Client()
        client.firstName = ""
        client.lastName = "Doe"
        XCTAssertEqual(client.fullName, "Doe")
    }

    func testClientFullName_bothEmpty() {
        let client = Client()
        client.firstName = ""
        client.lastName = ""
        XCTAssertEqual(client.fullName, "")
    }

    func testReminderNextOccurrence() {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!

        let reminder = Reminder()
        reminder.dueDate = baseDate

        // Once: no next occurrence
        reminder.frequency = .once
        XCTAssertNil(reminder.nextOccurrence())

        // Daily: exactly 1 day later
        reminder.frequency = .daily
        let nextDaily = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextDaily), 2026)
        XCTAssertEqual(calendar.component(.month, from: nextDaily), 3)
        XCTAssertEqual(calendar.component(.day, from: nextDaily), 2)

        // Weekly: exactly 1 week later
        reminder.frequency = .weekly
        let nextWeekly = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextWeekly), 2026)
        XCTAssertEqual(calendar.component(.month, from: nextWeekly), 3)
        XCTAssertEqual(calendar.component(.day, from: nextWeekly), 8)

        // Monthly: exactly 1 month later
        reminder.frequency = .monthly
        let nextMonthly = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextMonthly), 2026)
        XCTAssertEqual(calendar.component(.month, from: nextMonthly), 4)
        XCTAssertEqual(calendar.component(.day, from: nextMonthly), 1)

        // Quarterly: exactly 3 months later
        reminder.frequency = .quarterly
        let nextQuarterly = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextQuarterly), 2026)
        XCTAssertEqual(calendar.component(.month, from: nextQuarterly), 6)
        XCTAssertEqual(calendar.component(.day, from: nextQuarterly), 1)

        // Biannually: exactly 6 months later
        reminder.frequency = .biannually
        let nextBiannual = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextBiannual), 2026)
        XCTAssertEqual(calendar.component(.month, from: nextBiannual), 9)
        XCTAssertEqual(calendar.component(.day, from: nextBiannual), 1)

        // Annually: exactly 1 year later
        reminder.frequency = .annually
        let nextAnnual = reminder.nextOccurrence()!
        XCTAssertEqual(calendar.component(.year, from: nextAnnual), 2027)
        XCTAssertEqual(calendar.component(.month, from: nextAnnual), 3)
        XCTAssertEqual(calendar.component(.day, from: nextAnnual), 1)
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
        XCTAssertEqual(150.50.asCurrency, "$150.50")
        XCTAssertEqual(0.0.asCurrency, "$0.00")
        XCTAssertEqual((-25.99).asCurrency, "-$25.99")
        XCTAssertEqual(1_000_000.0.asCurrency, "$1,000,000.00")
        XCTAssertEqual(0.01.asCurrency, "$0.01")
        XCTAssertEqual(9999.999.asCurrency, "$10,000.00")
    }
}
