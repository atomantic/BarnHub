import XCTest
@testable import BarnHub

/// #35: an invoice bills unpaid income charges in whole picked days.
final class InvoiceBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Denver")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    func testTotalDueIsUnpaidIncomeOnly() {
        let transactions = [
            Transaction(amount: 850, date: date(1), memo: "June board", category: .boarding, type: .income),
            Transaction(amount: 75, date: date(5), category: .lesson, type: .income, isPaid: true),
            Transaction(amount: 120, date: date(8), category: .vetBill, type: .expense),
            Transaction(amount: 60, date: date(9), memo: "", category: .lesson, type: .income),
        ]
        let invoice = InvoiceBuilder(transactions: transactions, from: date(1), through: date(30), calendar: calendar)
        XCTAssertEqual(invoice.totalDue, 910)
        XCTAssertEqual(invoice.charges.map(\.amount), [850, 60])
        XCTAssertEqual(invoice.excludedCount, 2, "the paid lesson and the expense")
        XCTAssertEqual(invoice.lineItems.map(\.amount), [850, 60], "every line item is a positive charge")
        XCTAssertEqual(invoice.lineItems.map(\.description), ["June board", TransactionCategory.lesson.displayName])
        XCTAssertEqual(invoice.lineItems.reduce(0) { $0 + $1.amount }, invoice.totalDue)
    }

    func testPickedDaysIncludeTheWholeStartAndEndDays() {
        let firstMinute = Transaction(amount: 1, date: date(10, 0, 0), type: .income)
        let lastMinute = Transaction(amount: 2, date: date(20, 23, 59), type: .income)
        let dayBefore = Transaction(amount: 4, date: date(9, 23, 59), type: .income)
        let dayAfter = Transaction(amount: 8, date: date(21, 0, 0), type: .income)
        // The pickers keep the time they were opened at: afternoon start, morning end.
        let invoice = InvoiceBuilder(
            transactions: [dayAfter, lastMinute, dayBefore, firstMinute],
            from: date(10, 15), through: date(20, 9), calendar: calendar
        )
        XCTAssertEqual(invoice.charges.map(\.amount), [1, 2], "oldest first")
        XCTAssertEqual(invoice.totalDue, 3)
        XCTAssertEqual(invoice.range.start, date(10, 0))
        XCTAssertEqual(invoice.range.end, date(21, 0))
    }

    func testEndBeforeStartIsEmpty() {
        let invoice = InvoiceBuilder(
            transactions: [Transaction(amount: 5, date: date(10), type: .income)],
            from: date(12), through: date(10), calendar: calendar
        )
        XCTAssertTrue(invoice.charges.isEmpty)
        XCTAssertEqual(invoice.totalDue, 0)
        XCTAssertEqual(invoice.range.duration, 0)
    }

    func testSingleDayRange() {
        let range = calendar.dayRange(from: date(15, 18), through: date(15, 6))
        XCTAssertEqual(range.start, date(15, 0))
        XCTAssertEqual(range.end, date(16, 0))
    }
}
