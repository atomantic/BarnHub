import Foundation

extension Double {
    private static let currencyKey = "net.shadowpuppet.BarnBook.currencyCode"

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = appCurrencyCode
        return f
    }()

    static var appCurrencyCode: String {
        let code = UserDefaults.standard.string(forKey: currencyKey) ?? ""
        return code.isEmpty ? "USD" : code
    }

    /// Syncs the cached formatter when currency changes. Called from SettingsView.
    static func refreshCurrencyFormatter() {
        currencyFormatter.currencyCode = appCurrencyCode
    }

    var asCurrency: String {
        let fmt = Self.currencyFormatter
        if fmt.currencyCode != Self.appCurrencyCode {
            fmt.currencyCode = Self.appCurrencyCode
        }
        return fmt.string(from: NSNumber(value: self)) ?? "0.00"
    }

    /// Compact currency for chart axes: "$950", "$1.5K", "-$12K", "1,2 Mio. €".
    /// Keeps up to three significant digits so neighbouring axis values stay
    /// distinct, and follows the in-app language for symbol placement and signs.
    var asShortCurrency: String {
        Self.shortCurrency(self, code: Self.appCurrencyCode, locale: .app)
    }

    static func shortCurrency(_ value: Double, code: String, locale: Locale) -> String {
        // Compact currency styles need iOS 18, so put the compact number ("1.5K",
        // "1,2 Mio.") into the locale's currency pattern for ±1 ("$1", "-$1", "1 €").
        let compact = abs(value).formatted(
            .number.notation(.compactName).precision(.significantDigits(1...3)).locale(locale)
        )
        let pattern = (value < 0 ? -1.0 : 1.0).formatted(
            .currency(code: code).precision(.fractionLength(0)).locale(locale)
        )
        guard let one = pattern.range(of: "1") else { return compact }
        return pattern.replacingCharacters(in: one, with: compact)
    }
}
