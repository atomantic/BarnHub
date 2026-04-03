import SwiftUI

struct CurrencyField: View {
    let label: String
    @Binding var value: Double

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Double.appCurrencyCode
        return f
    }()

    private var activeFormatter: NumberFormatter {
        let f = Self.formatter
        if f.currencyCode != Double.appCurrencyCode {
            f.currencyCode = Double.appCurrencyCode
        }
        return f
    }

    private var placeholder: String {
        activeFormatter.string(from: 0) ?? "$0.00"
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, value: $value, formatter: activeFormatter)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    Form {
        CurrencyField(label: "Amount", value: .constant(125.50))
    }
}
