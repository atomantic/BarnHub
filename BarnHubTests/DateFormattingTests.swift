import XCTest
@testable import BarnHub

final class DateFormattingTests: XCTestCase {

    func testShortFormattedReturnsExpectedFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 12
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(date.shortFormatted, "01/15/2026")
    }

    func testShortFormattedSingleDigitMonthAndDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 5
        components.hour = 12
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(date.shortFormatted, "03/05/2026")
    }

    func testShortFormattedDecember31() {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 12
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(date.shortFormatted, "12/31/2025")
    }

    func testIsOverdueForPastDate() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        XCTAssertTrue(pastDate.isOverdue)
    }

    func testIsOverdueForFutureDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        XCTAssertFalse(futureDate.isOverdue)
    }

    func testIsOverdueForDistantPast() {
        let distantPast = Calendar.current.date(byAdding: .year, value: -5, to: .now)!
        XCTAssertTrue(distantPast.isOverdue)
    }

    func testRelativeDateStringForPastDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let result = yesterday.relativeDateString
        // RelativeDateTimeFormatter produces locale-dependent strings like "1 day ago"
        XCTAssertTrue(result.contains("ago") || result.contains("yesterday"),
                      "Expected relative past string, got: \(result)")
    }

    func testRelativeDateStringForFutureDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let result = tomorrow.relativeDateString
        // Should contain "in" for future dates (e.g. "in 1 day")
        XCTAssertTrue(result.contains("in ") || result.contains("tomorrow"),
                      "Expected relative future string, got: \(result)")
    }

    func testRelativeDateStringForDistantPast() {
        let longAgo = Calendar.current.date(byAdding: .month, value: -6, to: .now)!
        let result = longAgo.relativeDateString
        XCTAssertTrue(result.contains("ago"),
                      "Expected relative past string, got: \(result)")
    }

}
