import XCTest
@testable import BarnHub

/// #35: amounts typed without a symbol, chart axis currency, and week starts.
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

    // MARK: - Short currency

    func testShortCurrencyKeepsAxisLabelsDistinct() {
        let labels = [0, 500, 1000, 1500, 2000, 2500].map { Double.shortCurrency(Double($0), code: "USD", locale: us) }
        XCTAssertEqual(labels, ["$0", "$500", "$1K", "$1.5K", "$2K", "$2.5K"])
        XCTAssertEqual(Set([1200.0, 1250, 1300].map { Double.shortCurrency($0, code: "USD", locale: us) }).count, 3)
    }

    func testShortCurrencyFormatsNegativesWithTheSignFirst() {
        XCTAssertEqual(Double.shortCurrency(-1500, code: "USD", locale: us), "-$1.5K")
    }

    func testShortCurrencyFollowsTheLocale() {
        let euro = Double.shortCurrency(500, code: "EUR", locale: german)
        XCTAssertTrue(euro.hasSuffix("€"), euro)
        XCTAssertTrue(euro.hasPrefix("500"), euro)
    }

    // MARK: - Week start

    func testWeeksStartOnTheLocalesFirstWeekday() {
        XCTAssertEqual(us.firstWeekdayNumber, 1)
        XCTAssertEqual(german.firstWeekdayNumber, 2)
        var monday = Calendar(identifier: .gregorian)
        monday.timeZone = TimeZone(identifier: "Europe/Berlin")!
        monday.firstWeekday = german.firstWeekdayNumber
        var sunday = monday
        sunday.firstWeekday = us.firstWeekdayNumber

        // Wednesday 2026-07-01.
        let wednesday = monday.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 14))!
        XCTAssertEqual(monday.startOfWeek(containing: wednesday), monday.date(from: DateComponents(year: 2026, month: 6, day: 29)))
        XCTAssertEqual(sunday.startOfWeek(containing: wednesday), sunday.date(from: DateComponents(year: 2026, month: 6, day: 28)))
        // A Sunday belongs to the week before in a Monday-first locale.
        let sundayDate = monday.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 9))!
        XCTAssertEqual(monday.startOfWeek(containing: sundayDate), monday.date(from: DateComponents(year: 2026, month: 6, day: 29)))
        XCTAssertEqual(sunday.startOfWeek(containing: sundayDate), sunday.date(from: DateComponents(year: 2026, month: 7, day: 5)))

        // July 2026 starts on a Wednesday: 2 blanks Monday-first, 3 Sunday-first.
        let july = monday.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        XCTAssertEqual(monday.leadingBlankDays(forMonthStartingOn: july), 2)
        XCTAssertEqual(sunday.leadingBlankDays(forMonthStartingOn: july), 3)

        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        XCTAssertEqual(monday.weekdaySymbolsStartingOnFirstWeekday(symbols).first, "Mon")
        XCTAssertEqual(monday.weekdaySymbolsStartingOnFirstWeekday(symbols).last, "Sun")
        XCTAssertEqual(sunday.weekdaySymbolsStartingOnFirstWeekday(symbols), symbols)
    }

    // MARK: - App-language currency, dates and numbers (#52)

    func testCurrencyFollowsTheLocale() {
        XCTAssertEqual(Double.currency(1250, code: "USD", locale: us), "$1,250.00")
        let dollars = Double.currency(1250, code: "USD", locale: german)
        XCTAssertTrue(dollars.hasPrefix("1.250,00"), dollars)
        XCTAssertTrue(dollars.hasSuffix("$"), dollars)
        let euro = Double.currency(-12.5, code: "EUR", locale: german)
        XCTAssertTrue(euro.hasPrefix("-12,50"), euro)
        XCTAssertTrue(euro.hasSuffix("€"), euro)
    }

    func testShortDatesFollowTheLocale() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        XCTAssertEqual(date.shortFormatted(locale: us), "01/15/2026")
        XCTAssertEqual(date.shortFormatted(locale: german), "15.01.2026")
        XCTAssertEqual(date.shortFormatted(locale: Locale(identifier: "de")), "15.01.2026", "the in-app language has no region")
    }

    func testRelativeDatesFollowTheLocale() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)
        XCTAssertEqual(twoDaysAgo.relativeDateString(relativeTo: now, locale: us), "2 days ago")
        XCTAssertEqual(twoDaysAgo.relativeDateString(relativeTo: now, locale: german), "vor 2 Tagen")
    }

    func testLowStockDetailFormatsNumbersForTheLocale() {
        // The words come from the app language's catalog (English in tests);
        // the numbers follow the locale.
        XCTAssertEqual(SupplyItem.lowStockDetail(quantity: 1.5, unit: "bags", reorderAt: 4, locale: us), "1.5 bags · reorder at 4")
        XCTAssertEqual(SupplyItem.lowStockDetail(quantity: 1.5, unit: "bags", reorderAt: 4, locale: german), "1,5 bags · reorder at 4")
        XCTAssertEqual(SupplyItem.lowStockDetail(quantity: 3, unit: " ", reorderAt: 2.5, locale: us), "3 · reorder at 2.5")
    }

    func testFormatKeysResolveInTheAppLanguage() {
        let key = "net.shadowpuppet.BarnBook.appLocale"
        let saved = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set("de", forKey: key)
        Bundle.resetAppBundleCache()
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
            Bundle.resetAppBundleCache()
        }
        let horse = "Star"
        XCTAssertEqual(appLocalized("Vet: \(horse)"), "Tierarzt: Star")
        XCTAssertEqual(SupplyItem.lowStockDetail(quantity: 1.5, unit: "Säcke", reorderAt: 4, locale: .app), "1,5 Säcke · Nachbestellen bei 4")
        XCTAssertEqual(1250.0.asCurrency, Double.currency(1250, code: Double.appCurrencyCode, locale: Locale(identifier: "de")))
        XCTAssertTrue(1250.0.asCurrency.hasPrefix("1.250,00"), 1250.0.asCurrency)
    }
}
