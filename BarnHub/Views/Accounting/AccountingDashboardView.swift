import SwiftUI
import SwiftData

struct AccountingDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return [] }
        return transactions.filter { $0.date >= monthStart && $0.date < monthEnd }
    }

    private var monthlyIncome: Double {
        currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpenses: Double {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var balance: Double {
        monthlyIncome - monthlyExpenses
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(10))
    }

    var body: some View {
        List {
            Section("This Month") {
                HStack(spacing: 12) {
                    summaryCard(title: "Income", amount: monthlyIncome, color: .green)
                    summaryCard(title: "Expenses", amount: monthlyExpenses, color: .red)
                    summaryCard(title: "Balance", amount: balance, color: balance >= 0 ? .blue : .orange)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink(value: AccountingRoute.list) {
                    Label("All Transactions", systemImage: "list.bullet.rectangle")
                }
            }

            Section("Recent Transactions") {
                if recentTransactions.isEmpty {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No Transactions",
                        subtitle: "Tap + to add your first transaction."
                    )
                } else {
                    ForEach(recentTransactions) { transaction in
                        NavigationLink(value: AccountingRoute.edit(transaction.persistentModelID)) {
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle("Accounting")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: AccountingRoute.edit(nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func summaryCard(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}
