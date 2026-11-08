import XCTest
@testable import BarnHub

/// #35: amounts typed without a symbol.
final class LocaleFormattingTests: XCTestCase {

    private let us = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    // MARK: - CurrencyField parsing

    func testParsesAmountsWithoutACurrencySymbol() {
        XCTAssertEqual(CurrencyField.parse("12.50", locale: us), 12.5)
        XCTAssertEqual(CurrencyField.parse("12", locale: us), 12)
        XCTAssertEqual(CurrencyField.parse("12.", locale: us), 12)
        XCTAssertEqual(CurrencyField.parse(".5", locale: us), 0.5)
        XCTAssertEqual(CurrencyField.parse("", locale: us), 0)
        XCTAssertNil(CurrencyField.parse("abc", locale: us))
    }

    func testParsesFormattedAmounts() {
        XCTAssertEqual(CurrencyField.parse("$1,250.00", locale: us), 1250)
        XCTAssertEqual(CurrencyField.parse("1,250", locale: us), 1250)
        XCTAssertEqual(CurrencyField.parse("USD 99.99", locale: us), 99.99)
        XCTAssertEqual(CurrencyField.parse("-$5.25", locale: us), -5.25)
    }

    func testParsesLocaleDecimalSeparators() {
        XCTAssertEqual(CurrencyField.parse("12,50", locale: german), 12.5)
        XCTAssertEqual(CurrencyField.parse("1.250", locale: german), 1250)
        XCTAssertEqual(CurrencyField.parse("1.250,75 €", locale: german), 1250.75)
        // A keyboard with "." while the app language uses ",".
        XCTAssertEqual(CurrencyField.parse("12.50", locale: german), 12.5)
    }

    func testEditingTextRoundTrips() {
        for value in [12.5, 1250, 0.99] {
            XCTAssertEqual(CurrencyField.parse(CurrencyField.editingText(value, locale: german), locale: german), value)
            XCTAssertEqual(CurrencyField.parse(CurrencyField.editingText(value, locale: us), locale: us), value)
        }
    }
}
