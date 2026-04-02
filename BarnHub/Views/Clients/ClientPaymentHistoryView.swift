import SwiftUI
import SwiftData

struct ClientPaymentHistoryView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var sortedTransactions: [Transaction] {
        (client?.transactions ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        let sorted = sortedTransactions
        let totalAmount = sorted.reduce(0) { $0 + $1.amount }
        let totalPaid = sorted.filter(\.isPaid).reduce(0) { $0 + $1.amount }
        let totalUnpaid = sorted.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }

        return Group {
            if let client {
                if sorted.isEmpty {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No Transactions",
                        subtitle: "No payment history for \(client.fullName)."
                    )
                } else {
                    List {
                        Section {
                            ForEach(sorted, id: \.persistentModelID) { transaction in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(transaction.category.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(transaction.date.shortFormatted)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !transaction.memo.isEmpty {
                                            Text(transaction.memo)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(transaction.amount.asCurrency)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(transaction.type == .income ? .green : .primary)
                                        Label(
                                            transaction.isPaid ? "Paid" : "Unpaid",
                                            systemImage: transaction.isPaid ? "checkmark.circle.fill" : "xmark.circle.fill"
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(transaction.isPaid ? .green : .red)
                                    }
                                }
                            }
                        }

                        Section("Summary") {
                            LabeledContent("Total", value: totalAmount.asCurrency)
                            LabeledContent("Paid") {
                                Text(totalPaid.asCurrency)
                                    .foregroundStyle(.green)
                            }
                            LabeledContent("Unpaid") {
                                Text(totalUnpaid.asCurrency)
                                    .foregroundStyle(totalUnpaid > 0 ? .red : .secondary)
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Client Not Found",
                    subtitle: "This client may have been deleted."
                )
            }
        }
        .navigationTitle("Payment History")
        .inlineNavTitle()
    }
}
