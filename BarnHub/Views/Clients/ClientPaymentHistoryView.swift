import SwiftUI
import SwiftData

struct ClientPaymentHistoryView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    private var client: Client? {
        modelContext.existingModel(for: clientID)
    }

    private var sortedTransactions: [Transaction] {
        (client?.transactions ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        let sorted = sortedTransactions
        let balance = ClientBalance(sorted)

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
                                        Text(transaction.signedAmount.asCurrency)
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

                        Section {
                            LabeledContent("Total", value: balance.charged.asCurrency)
                            LabeledContent("Paid") {
                                Text(balance.paid.asCurrency)
                                    .foregroundStyle(.green)
                            }
                            LabeledContent("Unpaid") {
                                Text(balance.unpaid.asCurrency)
                                    .foregroundStyle(balance.unpaid > 0 ? .red : .secondary)
                            }
                            if balance.linkedExpenses > 0 {
                                LabeledContent("Linked Expenses", value: (-balance.linkedExpenses).asCurrency)
                            }
                        } header: {
                            Text("Summary")
                        } footer: {
                            if balance.linkedExpenses > 0 {
                                Text("Total, Paid and Unpaid count charges to the client only. Expenses linked to the client are the barn's own costs, so they aren't part of what the client owes.")
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
