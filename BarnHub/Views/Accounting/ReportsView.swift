import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var transactions: [Transaction]

    @State private var selectedPeriod: ReportPeriod = .thisMonth

    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date.now
        switch selectedPeriod {
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let start = calendar.date(from: components) else { return transactions }
            return transactions.filter { $0.date >= start && $0.date <= now }
        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let thisMonthStart = calendar.date(from: components),
                  let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)
            else { return transactions }
            return transactions.filter { $0.date >= start && $0.date < thisMonthStart }
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            guard let start = calendar.date(from: components) else { return transactions }
            return transactions.filter { $0.date >= start && $0.date <= now }
        case .thisYear:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            guard let start = calendar.date(from: components) else { return transactions }
            return transactions.filter { $0.date >= start && $0.date <= now }
        case .allTime:
            return transactions
        }
    }

    private var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { totalIncome - totalExpenses }

    private var expensesByCategory: [(category: TransactionCategory, amount: Double)] {
        var grouped: [TransactionCategory: Double] = [:]
        for t in filteredTransactions where t.type == .expense {
            grouped[t.category, default: 0] += t.amount
        }
        return grouped.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private var incomeByCategory: [(category: TransactionCategory, amount: Double)] {
        var grouped: [TransactionCategory: Double] = [:]
        for t in filteredTransactions where t.type == .income {
            grouped[t.category, default: 0] += t.amount
        }
        return grouped.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private var monthlyTotals: [MonthlyTotal] {
        let calendar = Calendar.current
        var grouped: [Date: (income: Double, expenses: Double)] = [:]
        for t in filteredTransactions {
            let components = calendar.dateComponents([.year, .month], from: t.date)
            let monthStart = calendar.date(from: components) ?? t.date
            var entry = grouped[monthStart, default: (income: 0, expenses: 0)]
            if t.type == .income {
                entry.income += t.amount
            } else {
                entry.expenses += t.amount
            }
            grouped[monthStart] = entry
        }
        return grouped.map { MonthlyTotal(month: $0.key, income: $0.value.income, expenses: $0.value.expenses) }
            .sorted { $0.month < $1.month }
    }

    private var showFullReports: Bool {
        FeatureGate.canAccessFullReports(storeService.isPro)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                summaryCards
                if filteredTransactions.isEmpty {
                    emptyState
                } else {
                    incomeExpenseChart
                    if showFullReports {
                        if monthlyTotals.count > 1 {
                            monthlyTrendChart
                        }
                        if !expensesByCategory.isEmpty {
                            categoryBreakdownSection("Expenses by Category", data: expensesByCategory, total: totalExpenses, colors: expenseCategoryColors)
                        }
                        if !incomeByCategory.isEmpty {
                            categoryBreakdownSection("Income by Category", data: incomeByCategory, total: totalIncome, colors: incomeCategoryColors)
                        }
                    } else {
                        lockedSection
                    }
                }
            }
            .padding()
        }
        .background(Color.barnOffWhite)
        .navigationTitle("Reports")
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Income", amount: totalIncome, icon: "arrow.down.circle.fill", color: .green)
            summaryCard(title: "Expenses", amount: totalExpenses, icon: "arrow.up.circle.fill", color: .red)
            summaryCard(title: "Net", amount: netBalance, icon: "equal.circle.fill", color: netBalance >= 0 ? .barnGreen : .red)
        }
    }

    private func summaryCard(title: String, amount: Double, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Income vs Expense Bar Chart

    private var incomeExpenseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses")
                .font(.headline)

            Chart {
                BarMark(
                    x: .value("Type", "Income"),
                    y: .value("Amount", totalIncome)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)

                BarMark(
                    x: .value("Type", "Expenses"),
                    y: .value("Amount", totalExpenses)
                )
                .foregroundStyle(Color.red.gradient)
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.asShortCurrency)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Monthly Trend

    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trend")
                .font(.headline)

            Chart(monthlyTotals) { total in
                LineMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value("Income", total.income)
                )
                .foregroundStyle(.green)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value("Income", total.income)
                )
                .foregroundStyle(.green.opacity(0.1))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value("Expenses", total.expenses)
                )
                .foregroundStyle(.red)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value("Expenses", total.expenses)
                )
                .foregroundStyle(.red.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.asShortCurrency)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                    AxisGridLine()
                }
            }
            .chartLegend(position: .bottom)
            .frame(height: 220)

            HStack(spacing: 16) {
                legendDot(color: .green, label: "Income")
                legendDot(color: .red, label: "Expenses")
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Category Breakdown

    private func categoryBreakdownSection(
        _ title: String,
        data: [(category: TransactionCategory, amount: Double)],
        total: Double,
        colors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Chart(Array(data.enumerated()), id: \.element.category) { index, item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(colors[index % colors.count])
                .cornerRadius(4)
            }
            .frame(height: 200)

            VStack(spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.element.category) { index, item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 10, height: 10)
                        Text(item.category.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(item.amount.asCurrency)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(percentString(item.amount, of: total))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Locked Section

    private var lockedSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category Breakdowns")
                    .font(.headline)

                Chart {
                    SectorMark(angle: .value("A", 40), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color.gray.opacity(0.3))
                    SectorMark(angle: .value("B", 30), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color.gray.opacity(0.2))
                    SectorMark(angle: .value("C", 20), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color.gray.opacity(0.15))
                    SectorMark(angle: .value("D", 10), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color.gray.opacity(0.1))
                }
                .frame(height: 180)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.barnCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
            .redacted(reason: .placeholder)
            .featureLockedOverlay()

            VStack(alignment: .leading, spacing: 12) {
                Text("Monthly Trend")
                    .font(.headline)

                Chart {
                    LineMark(x: .value("M", 1), y: .value("V", 300))
                    LineMark(x: .value("M", 2), y: .value("V", 500))
                    LineMark(x: .value("M", 3), y: .value("V", 400))
                }
                .foregroundStyle(Color.gray.opacity(0.3))
                .frame(height: 140)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.barnCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
            .redacted(reason: .placeholder)
            .featureLockedOverlay()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No Data Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add transactions to see reports")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func percentString(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = (value / total) * 100
        return "\(Int(pct))%"
    }

    private var expenseCategoryColors: [Color] {
        [.red, .orange, .yellow, .pink, .purple, .brown, .indigo, .mint, .teal]
    }

    private var incomeCategoryColors: [Color] {
        [.green, .barnGreen, .teal, .cyan, .mint, .blue, .indigo, .purple, .yellow]
    }
}

// MARK: - Supporting Types

enum ReportPeriod: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, thisQuarter, thisYear, allTime
    var id: String { rawValue }
    var label: String {
        switch self {
        case .thisMonth: return "Month"
        case .lastMonth: return "Last Mo"
        case .thisQuarter: return "Quarter"
        case .thisYear: return "Year"
        case .allTime: return "All"
        }
    }
}

struct MonthlyTotal: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expenses: Double
}

// MARK: - Short Currency Extension

extension Double {
    var asShortCurrency: String {
        if self >= 1000 {
            return "$\(Int(self / 1000))k"
        }
        return "$\(Int(self))"
    }
}
