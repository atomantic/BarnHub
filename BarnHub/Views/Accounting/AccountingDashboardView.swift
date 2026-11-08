import SwiftUI
import SwiftData

struct AccountingDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    var body: some View {
        // This month's transactions for the totals and the ten newest for the
        // list, rather than the whole table (#32).
        QueryContent(DashboardQueries.transactions(in: Calendar.current.monthInterval(containing: .now))) { monthTransactions in
            QueryContent(DashboardQueries.recentTransactions(limit: 10)) { recentTransactions in
                dashboard(month: TransactionTotals(monthTransactions), recentTransactions: recentTransactions)
            }
        }
        .navigationTitle("Accounting")
        .inlineNavTitle()
        .prioritizedToolbarItem(.high, placement: .primaryAction) {
            Button {
                router.navigate(to: AccountingRoute.edit(nil))
            } label: {
                Label("New Transaction", systemImage: "plus")
            }
        }
    }

    private func dashboard(month: TransactionTotals, recentTransactions: [Transaction]) -> some View {
        List {
            Section("This Month") {
                HStack(spacing: 12) {
                    SummaryCard(title: "Income", amount: month.income, color: .green)
                    SummaryCard(title: "Expenses", amount: month.expenses, color: .red)
                    SummaryCard(title: "Balance", amount: month.balance, color: month.balance >= 0 ? .blue : .orange)
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
                        Button {
                            router.navigate(to: AccountingRoute.edit(transaction.persistentModelID))
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
                    }
                }
            }
        }
    }

}
