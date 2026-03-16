import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Double = 0
    var date: Date = Date.now
    var memo: String = ""
    var categoryRaw: String = TransactionCategory.other.rawValue
    var typeRaw: String = TransactionType.expense.rawValue
    var isPaid: Bool = false

    @Relationship(deleteRule: .nullify)
    var client: Client? = nil

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        amount: Double = 0,
        date: Date = .now,
        memo: String = "",
        category: TransactionCategory = .other,
        type: TransactionType = .expense,
        isPaid: Bool = false
    ) {
        self.amount = amount
        self.date = date
        self.memo = memo
        self.categoryRaw = category.rawValue
        self.typeRaw = type.rawValue
        self.isPaid = isPaid
    }
}
