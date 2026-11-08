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
    @State private var sortOrder = [KeyPathComparator(\Transaction.date, order: .reverse)]
    @State private var selection: PersistentIdentifier?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// A sortable table on the Mac and at regular width; a list of rows on iPhone.
    private var usesTable: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { txn in
            if let type = selectedType, txn.type != type { return false }
            if let category = selectedCategory, txn.category != category { return false }
            if txn.date < startDate || txn.date > endDate { return false }
            return true
        }
    }

    var body: some View {
        Group {
            if usesTable {
                tableLayout
            } else {
                listLayout
            }
        }
        .navigationTitle("Transactions")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: AccountingRoute.edit(nil))
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
                .help(Text("New Transaction"))
            }
        }
    }

    // MARK: - Wide: filter bar + table

    private var tableLayout: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)
            Divider()
            if filteredTransactions.isEmpty {
                EmptyStateView(
                    icon: "dollarsign.circle",
                    title: "No Transactions",
                    subtitle: "No transactions match your filters."
                )
                .frame(maxHeight: .infinity)
            } else {
                transactionTable
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 16) {
            // Explicit labels: iOS menu pickers hide their own.
            HStack(spacing: 6) {
                Text("Type").foregroundStyle(.secondary)
                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as TransactionType?)
                    ForEach(TransactionType.allCases) { type in
                        Text(type.displayName).tag(type as TransactionType?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(spacing: 6) {
                Text("Category").foregroundStyle(.secondary)
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(nil as TransactionCategory?)
                    ForEach(TransactionCategory.allCases) { cat in
                        Text(cat.displayName).tag(cat as TransactionCategory?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            Spacer()
            DatePicker("From", selection: $startDate, displayedComponents: .date)
                .fixedSize()
            DatePicker("To", selection: $endDate, displayedComponents: .date)
                .fixedSize()
        }
        .pickerStyle(.menu)
    }

    private var sortedTransactions: [Transaction] {
        filteredTransactions.sorted(using: sortOrder)
    }

    private var transactionTable: some View {
        Table(sortedTransactions, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { txn in
                Text(txn.date, format: .dateTime.year().month(.abbreviated).day())
            }
            .width(min: 95, ideal: 115, max: 140)
            TableColumn("Category", value: \.categoryRaw) { txn in
                Text(txn.category.displayName)
            }
            .width(min: 80, ideal: 110, max: 150)
            // Description takes the leftover width.
            TableColumn("Description", value: \.memo) { txn in
                Text(txn.memo)
            }
            .width(min: 160, ideal: 400)
            TableColumn("Client") { txn in
                Text(txn.client?.fullName ?? "")
            }
            .width(min: 80, ideal: 130, max: 200)
            TableColumn("Amount", value: \.signedAmount) { txn in
                Text(txn.amount.asCurrency)
                    .monospacedDigit()
                    .foregroundStyle(txn.type == .income ? .green : .red)
            }
            .width(min: 70, ideal: 90, max: 120)
            TableColumn("Paid") { txn in
                if txn.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(Text("Paid"))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Unpaid"))
                }
            }
            .width(40)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let id = ids.first {
                Button {
                    router.navigate(to: AccountingRoute.edit(id))
                } label: {
                    Label("Edit Transaction", systemImage: "pencil")
                }
            }
        } primaryAction: { ids in
            // Double-click (or Return) opens the transaction.
            if let id = ids.first {
                router.navigate(to: AccountingRoute.edit(id))
            }
        }
    }

    // MARK: - Compact: list of rows

    private var listLayout: some View {
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
    }
}

extension Transaction {
    /// Income positive, expenses negative, for sorting the Amount column.
    var signedAmount: Double { type == .income ? amount : -amount }
}
