import Foundation

extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var asShortCurrency: String {
        if self >= 1000 {
            return "$\(Int(self / 1000))k"
        }
        return "$\(Int(self))"
    }
}
