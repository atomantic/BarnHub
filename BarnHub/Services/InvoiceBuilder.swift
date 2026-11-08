import Foundation

/// Builds a client invoice from the client's transactions over a range of days.
///
/// Sign rules: an invoice bills what the client still owes. Only **unpaid income**
/// transactions (charges to the client: board, lessons, training, …) become line
/// items. Paid charges are already settled, and expenses linked to the client are
/// the barn's own costs, so neither appears on the invoice or changes Total Due.
/// Every line item is therefore a positive charge, and Total Due is their sum.
struct InvoiceBuilder {
    /// The picked days, `[startOfDay(from), startOfDay(through) + 1 day)`.
    let range: DateInterval
    /// The billed transactions, oldest first.
    let charges: [Transaction]
    /// Transactions in the range left off the invoice (paid, or expenses).
    let excludedCount: Int

    init(transactions: [Transaction], from start: Date, through end: Date, calendar: Calendar = .current) {
        let range = calendar.dayRange(from: start, through: end)
        self.range = range
        let inRange = transactions.filter { $0.date >= range.start && $0.date < range.end }
        let charges = inRange.filter(Self.isBillable).sorted { $0.date < $1.date }
        self.charges = charges
        self.excludedCount = inRange.count - charges.count
    }

    /// An unpaid income transaction: a charge the client still owes.
    static func isBillable(_ transaction: Transaction) -> Bool {
        transaction.type == .income && !transaction.isPaid
    }

    var totalDue: Double {
        charges.reduce(0) { $0 + $1.amount }
    }

    var lineItems: [InvoicePDFService.LineItem] {
        charges.map { txn in
            InvoicePDFService.LineItem(
                date: txn.date,
                description: txn.memo.isEmpty ? txn.category.displayName : txn.memo,
                category: txn.category.displayName,
                amount: txn.amount
            )
        }
    }
}
