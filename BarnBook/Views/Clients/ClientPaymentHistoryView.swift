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

    private var totalAmount: Double {
        sortedTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalPaid: Double {
        sortedTransactions.filter(\.isPaid).reduce(0) { $0 + $1.amount }
    }

    private var totalUnpaid: Double {
        sortedTransactions.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Group {
            if let client {
                if sortedTransactions.isEmpty {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No Transactions",
                        subtitle: "No payment history for \(client.fullName)."
                    )
                } else {
                    List {
                        Section {
                            ForEach(sortedTransactions, id: \.persistentModelID) { transaction in
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
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(transaction.isPaid ? Color.green : Color.red)
                                                .frame(width: 6, height: 6)
                                            Text(transaction.isPaid ? "Paid" : "Unpaid")
                                                .font(.caption2)
                                                .foregroundStyle(transaction.isPaid ? .green : .red)
                                        }
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
    }
}
