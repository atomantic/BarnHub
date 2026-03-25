import SwiftUI
import SwiftData

struct TransactionRowView: View {
    let transaction: Transaction

    private var categoryIcon: String {
        switch transaction.category {
        case .lesson: return "figure.walk"
        case .boarding: return "house.fill"
        case .training: return "figure.equestrian.sports"
        case .vetBill: return "cross.case.fill"
        case .farrier: return "hammer.fill"
        case .feed: return "leaf.fill"
        case .supplies: return "shippingbox.fill"
        case .tack: return "tag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    private var amountColor: Color {
        transaction.type == .income ? .green : .red
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .foregroundStyle(amountColor)
                .frame(width: 28)
                .accessibilityLabel(transaction.category.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category.displayName)
                    .font(.headline)
                if !transaction.memo.isEmpty {
                    Text(transaction.memo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: transaction.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.caption)
                    Text(transaction.amount.asCurrency)
                        .font(.headline)
                }
                .foregroundStyle(amountColor)
                HStack(spacing: 4) {
                    Text(transaction.date.shortFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if transaction.isPaid {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Paid")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
