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

    var asShortCurrency: String {
        let fmt = Self.currencyFormatter
        if fmt.currencyCode != Self.appCurrencyCode {
            fmt.currencyCode = Self.appCurrencyCode
        }
        let symbol = fmt.currencySymbol ?? "$"
        if self >= 1000 {
            return "\(symbol)\(Int(self / 1000))k"
        }
        return "\(symbol)\(Int(self))"
    }
}
