import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    private var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { totalIncome - totalExpenses }

    private var expensesByCategory: [(String, Double)] {
        let expenses = transactions.filter { $0.type == .expense }
        var grouped: [TransactionCategory: Double] = [:]
        for t in expenses {
            grouped[t.category, default: 0] += t.amount
        }
        return grouped.map { ($0.key.rawValue.capitalized, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private var incomeByCategory: [(String, Double)] {
        let income = transactions.filter { $0.type == .income }
        var grouped: [TransactionCategory: Double] = [:]
        for t in income {
            grouped[t.category, default: 0] += t.amount
        }
        return grouped.map { ($0.key.rawValue.capitalized, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        List {
            Section("Summary") {
                summaryRow("Total Income", value: totalIncome, color: .green)
                summaryRow("Total Expenses", value: totalExpenses, color: .red)
                summaryRow("Net Balance", value: netBalance, color: netBalance >= 0 ? .barnGreen : .red)
            }

            if !incomeByCategory.isEmpty {
                Section("Income by Category") {
                    ForEach(incomeByCategory, id: \.0) { category, amount in
                        categoryRow(category, amount: amount, total: totalIncome)
                    }
                }
            }

            if !expensesByCategory.isEmpty {
                Section("Expenses by Category") {
                    ForEach(expensesByCategory, id: \.0) { category, amount in
                        categoryRow(category, amount: amount, total: totalExpenses)
                    }
                }
            }

            if transactions.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No Data Yet",
                        subtitle: "Add transactions to see reports"
                    )
                }
            }
        }
        .navigationTitle("Reports")
    }

    private func summaryRow(_ label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.asCurrency)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func categoryRow(_ category: String, amount: Double, total: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category)
                Spacer()
                Text(amount.asCurrency)
                    .fontWeight(.medium)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.barnGreen.opacity(0.3))
                    .frame(width: total > 0 ? geo.size.width * (amount / total) : 0, height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }
}
