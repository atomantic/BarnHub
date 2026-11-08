import XCTest
import SwiftData
@testable import BarnHub

/// #35: report periods are whole calendar periods, computed from an injected
/// `now` and calendar, and Home, Accounting and Reports share "this month".
final class FinanceSummaryTests: XCTestCase {

    /// A calendar east of UTC, so local and UTC boundaries differ by a day.
    private var auckland: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return calendar
    }()

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testMonthIsTheWholeLocalCalendarMonth() {
        let cal = auckland
        let now = date(cal, 2026, 3, 1, 0, 30)  // 2026-02-28 11:30 UTC
        let month = ReportPeriod.thisMonth.interval(asOf: now, calendar: cal)!
        XCTAssertEqual(month.start, date(cal, 2026, 3, 1))
        XCTAssertEqual(month.end, date(cal, 2026, 4, 1))
        XCTAssertTrue(month.contains(date(cal, 2026, 3, 31, 23, 59)), "later this month counts")
        XCTAssertFalse(month.contains(date(cal, 2026, 2, 28, 23, 59)))
    }

    func testLastMonthAcrossAYearBoundary() {
        let cal = auckland
        let last = ReportPeriod.lastMonth.interval(asOf: date(cal, 2026, 1, 10), calendar: cal)!
        XCTAssertEqual(last.start, date(cal, 2025, 12, 1))
        XCTAssertEqual(last.end, date(cal, 2026, 1, 1))
    }

    func testQuarterBoundaries() {
        let cal = auckland
        let expected: [(month: Int, start: Int)] = [(1, 1), (3, 1), (4, 4), (6, 4), (7, 7), (9, 7), (10, 10), (12, 10)]
        for (month, startMonth) in expected {
            let quarter = ReportPeriod.thisQuarter.interval(asOf: date(cal, 2026, month, 15), calendar: cal)!
            XCTAssertEqual(quarter.start, date(cal, 2026, startMonth, 1), "month \(month)")
            XCTAssertEqual(quarter.end, cal.date(byAdding: .month, value: 3, to: quarter.start), "month \(month)")
        }
        // The first and last moments of a quarter.
        let q2 = ReportPeriod.thisQuarter.interval(asOf: date(cal, 2026, 5, 1), calendar: cal)!
        XCTAssertTrue(q2.contains(date(cal, 2026, 4, 1)))
        XCTAssertEqual(q2.end, date(cal, 2026, 7, 1), "exclusive end")
        XCTAssertTrue(q2.contains(date(cal, 2026, 6, 30, 23, 59)))
    }

    func testYearIsTheWholeCalendarYear() {
        let cal = auckland
        let year = ReportPeriod.thisYear.interval(asOf: date(cal, 2026, 12, 31, 23, 59), calendar: cal)!
        XCTAssertEqual(year.start, date(cal, 2026, 1, 1))
        XCTAssertEqual(year.end, date(cal, 2027, 1, 1))
        XCTAssertNil(ReportPeriod.allTime.interval(asOf: .now, calendar: cal))
    }

    func testHomeAndAccountingUseTheReportsMonth() {
        let cal = auckland
        let now = date(cal, 2026, 8, 31, 22)
        let window = HomeSummary.Window(anchor: now, calendar: cal)
        XCTAssertEqual(window.month, ReportPeriod.thisMonth.interval(asOf: now, calendar: cal))
        XCTAssertEqual(FinanceSummary.currentMonth(asOf: now, calendar: cal), window.month)
    }

    func testTotalsAndTrendGroupByLocalMonth() {
        let cal = auckland
        let transactions = [
            Transaction(amount: 100, date: date(cal, 2026, 4, 1, 0, 15), category: .boarding, type: .income),
            Transaction(amount: 40, date: date(cal, 2026, 3, 31, 23, 45), category: .feed, type: .expense),
            Transaction(amount: 60, date: date(cal, 2026, 4, 20), category: .feed, type: .expense),
            Transaction(amount: 25, date: date(cal, 2026, 4, 2), category: .lesson, type: .income),
        ]
        let summary = FinanceSummary(transactions: transactions, calendar: cal)
        XCTAssertEqual(summary.totalIncome, 125)
        XCTAssertEqual(summary.totalExpenses, 100)
        XCTAssertEqual(summary.netBalance, 25)
        XCTAssertEqual(summary.expensesByCategory.map(\.category), [.feed])
        XCTAssertEqual(summary.incomeByCategory.map(\.category), [.boarding, .lesson])
        XCTAssertEqual(summary.monthlyTotals.map(\.month), [date(cal, 2026, 3, 1), date(cal, 2026, 4, 1)])
        XCTAssertEqual(summary.monthlyTotals.map(\.income), [0, 125])
        XCTAssertEqual(summary.monthlyTotals.map(\.expenses), [40, 60])
    }

    func testPeriodLabelsAreLocalized() {
        for period in ReportPeriod.allCases {
            XCTAssertFalse(period.label.isEmpty)
        }
        XCTAssertEqual(ReportPeriod.lastMonth.label, "Last Mo")
    }
}
