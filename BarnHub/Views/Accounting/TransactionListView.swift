import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedType: TransactionType?
    @State private var selectedCategory: TransactionCategory?
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var showFilters = false

    private var filteredTransactions: [Transaction] {
        transactions.filter { txn in
            if let type = selectedType, txn.type != type { return false }
            if let category = selectedCategory, txn.category != category { return false }
            if txn.date < startDate || txn.date > endDate { return false }
            return true
        }
    }

    var body: some View {
        List {
            DisclosureGroup("Filters", isExpanded: $showFilters) {
                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as TransactionType?)
                    ForEach(TransactionType.allCases) { type in
                        Text(type.displayName).tag(type as TransactionType?)
                    }
                }

                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(nil as TransactionCategory?)
                    ForEach(TransactionCategory.allCases) { cat in
                        Text(cat.displayName).tag(cat as TransactionCategory?)
                    }
                }

                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }

            if filteredTransactions.isEmpty {
                EmptyStateView(
                    icon: "dollarsign.circle",
                    title: "No Transactions",
                    subtitle: "No transactions match your filters."
                )
            } else {
                ForEach(filteredTransactions) { transaction in
                    NavigationLink(value: AccountingRoute.edit(transaction.persistentModelID)) {
                        TransactionRowView(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: AccountingRoute.edit(nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: AccountingRoute.self) { route in
            switch route {
            case .list:
                TransactionListView()
            case .edit(let id):
                TransactionEditView(transactionID: id)
            }
        }
    }
}
