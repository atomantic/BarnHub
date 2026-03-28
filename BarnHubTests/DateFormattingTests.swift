import XCTest
@testable import BarnHub

final class DateFormattingTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a RelativeDateTimeFormatter locked to en_US so tests are locale-independent.
    private func enUSRelativeFormatter() -> RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "en_US")
        f.unitsStyle = .full
        return f
    }

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
        let f = enUSRelativeFormatter()
        let expected = f.localizedString(for: yesterday, relativeTo: .now)
        // en_US: "1 day ago" or "yesterday"
        XCTAssertEqual(yesterday.relativeDateString, expected)
        XCTAssertTrue(expected.contains("ago") || expected.contains("yesterday"),
                      "Expected relative past string, got: \(expected)")
    }

    func testRelativeDateStringForFutureDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let f = enUSRelativeFormatter()
        let expected = f.localizedString(for: tomorrow, relativeTo: .now)
        // en_US: "in 1 day" or "tomorrow"
        XCTAssertEqual(tomorrow.relativeDateString, expected)
        XCTAssertTrue(expected.contains("in ") || expected.contains("tomorrow"),
                      "Expected relative future string, got: \(expected)")
    }

    func testRelativeDateStringForDistantPast() {
        let longAgo = Calendar.current.date(byAdding: .month, value: -6, to: .now)!
        let f = enUSRelativeFormatter()
        let expected = f.localizedString(for: longAgo, relativeTo: .now)
        XCTAssertEqual(longAgo.relativeDateString, expected)
        XCTAssertTrue(expected.contains("ago"),
                      "Expected relative past string, got: \(expected)")
    }

    // MARK: - compactFormatted

    func testCompactFormattedReturnsYYYYMMDD() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = 12
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.compactFormatted, "20260105")
    }

    func testCompactFormattedDecember31() {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 12
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.compactFormatted, "20251231")
    }

}
