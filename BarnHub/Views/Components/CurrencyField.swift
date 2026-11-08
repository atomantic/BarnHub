import SwiftUI

/// An amount field. Accepts what people type on a decimal pad ("12.50", "12,50",
/// "1,250") with or without a currency symbol, and writes the amount to `value`
/// on every keystroke: the decimal pad has no Return key, so waiting for a submit
/// (as `TextField(value:formatter:)` does) would lose the amount when the form is
/// saved straight away. Shows the formatted currency when not editing.
struct CurrencyField: View {
    let label: LocalizedStringKey
    @Binding var value: Double

    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        LabeledContent(label) {
            TextField(0.0.asCurrency, text: $text)
                .labelsHidden()
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onChange(of: text) { _, newText in
                    guard isFocused else { return }
                    // Unparseable input (no digits) keeps the last good amount.
                    if let parsed = Self.parse(newText, locale: locale), parsed != value {
                        value = parsed
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    text = focused ? Self.editingText(value, locale: locale) : Self.displayText(value)
                }
                .onChange(of: value) { _, newValue in
                    // Loaded or changed elsewhere (e.g. an edit form filling in).
                    if !isFocused { text = Self.displayText(newValue) }
                }
                .onAppear { text = Self.displayText(value) }
        }
    }

    private static func displayText(_ value: Double) -> String {
        value == 0 ? "" : value.asCurrency
    }

    /// The amount as a plain number to edit, e.g. "12.5" or "12,5".
    static func editingText(_ value: Double, locale: Locale) -> String {
        value == 0 ? "" : value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)).locale(locale))
    }

    /// Reads a typed amount. Currency symbols, codes, spaces and other letters are
    /// ignored. The last "." or "," is the decimal separator when it is `locale`'s
    /// separator or isn't followed by exactly three digits; otherwise it groups
    /// thousands. So "12.50", "12,50", "$1,250.00" and (in German) "1.250" all
    /// read as expected, even when the keyboard's separator differs from the app
    /// language's. Empty input is 0; input with no digits is nil.
    static func parse(_ text: String, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let isNegative = trimmed.contains("-") || trimmed.contains("\u{2212}")
        let isDigit: (Character) -> Bool = { ("0"..."9").contains($0) }
        let kept = trimmed.filter { isDigit($0) || $0 == "." || $0 == "," }
        guard kept.contains(where: isDigit) else { return nil }

        var integerPart = kept
        var fractionPart = ""
        if let separatorIndex = kept.lastIndex(where: { $0 == "." || $0 == "," }) {
            let separator = String(kept[separatorIndex])
            let after = String(kept[kept.index(after: separatorIndex)...])
            if separator == (locale.decimalSeparator ?? ".") || after.count != 3 {
                integerPart = String(kept[..<separatorIndex])
                fractionPart = after
            }
        }
        let digits = integerPart.filter(isDigit)
        guard let number = Double("\(digits.isEmpty ? "0" : digits).\(fractionPart.isEmpty ? "0" : fractionPart)") else { return nil }
        return isNegative ? -number : number
    }
}

#Preview {
    Form {
        CurrencyField(label: "Amount", value: .constant(125.50))
    }
}
