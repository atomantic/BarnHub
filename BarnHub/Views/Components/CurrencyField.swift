import SwiftUI

struct CurrencyField: View {
    let label: String
    @Binding var value: Double

    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("$0.00", value: $value, formatter: formatter)
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
