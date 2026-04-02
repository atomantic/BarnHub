import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var transactions: [Transaction]

    @State private var selectedPeriod: ReportPeriod = .thisMonth

    private var reportData: ReportData {
        ReportData(transactions: transactions, period: selectedPeriod)
    }

    private var showFullReports: Bool {
        FeatureGate.canAccessFullReports(storeService.isPro)
    }

    var body: some View {
        let data = reportData
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                summaryCards(data: data)
                if data.filteredTransactions.isEmpty {
                    emptyState
                } else {
                    incomeExpenseChart(data: data)
                    if showFullReports {
                        if data.monthlyTotals.count > 1 {
                            monthlyTrendChart(data: data)
                        }
                        if !data.expensesByCategory.isEmpty {
                            categoryBreakdownSection("Expenses by Category", data: data.expensesByCategory, total: data.totalExpenses, colors: expenseCategoryColors)
                        }
                        if !data.incomeByCategory.isEmpty {
                            categoryBreakdownSection("Income by Category", data: data.incomeByCategory, total: data.totalIncome, colors: incomeCategoryColors)
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
        .inlineNavTitle()
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

    private func summaryCards(data: ReportData) -> some View {
        HStack(spacing: 12) {
            SummaryCard(title: "Income", amount: data.totalIncome, color: .green, icon: "arrow.down.circle.fill")
            SummaryCard(title: "Expenses", amount: data.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
            SummaryCard(title: "Net", amount: data.netBalance, color: data.netBalance >= 0 ? .barnGreen : .red, icon: "equal.circle.fill")
        }
    }

    // MARK: - Income vs Expense Bar Chart

    private func incomeExpenseChart(data: ReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses")
                .font(.headline)

            Chart {
                BarMark(
                    x: .value("Type", "Income"),
                    y: .value("Amount", data.totalIncome)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)

                BarMark(
                    x: .value("Type", "Expenses"),
                    y: .value("Amount", data.totalExpenses)
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
        .barnCard()
    }

    // MARK: - Monthly Trend

    private func monthlyTrendChart(data: ReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trend")
                .font(.headline)

            Chart(data.monthlyTotals) { total in
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
        .barnCard()
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
        .barnCard()
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
                .font(.largeTitle)
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

// MARK: - Report Data

struct ReportData {
    let filteredTransactions: [Transaction]
    let totalIncome: Double
    let totalExpenses: Double
    let netBalance: Double
    let expensesByCategory: [(category: TransactionCategory, amount: Double)]
    let incomeByCategory: [(category: TransactionCategory, amount: Double)]
    let monthlyTotals: [MonthlyTotal]

    init(transactions: [Transaction], period: ReportPeriod) {
        let filtered = Self.filterByPeriod(transactions, period: period)
        self.filteredTransactions = filtered

        var income: Double = 0
        var expenses: Double = 0
        var expenseGroups: [TransactionCategory: Double] = [:]
        var incomeGroups: [TransactionCategory: Double] = [:]
        var monthGroups: [Date: (income: Double, expenses: Double)] = [:]
        let calendar = Calendar.current

        for t in filtered {
            if t.type == .income {
                income += t.amount
                incomeGroups[t.category, default: 0] += t.amount
            } else {
                expenses += t.amount
                expenseGroups[t.category, default: 0] += t.amount
            }
            let components = calendar.dateComponents([.year, .month], from: t.date)
            let monthStart = calendar.date(from: components) ?? t.date
            var entry = monthGroups[monthStart, default: (income: 0, expenses: 0)]
            if t.type == .income { entry.income += t.amount } else { entry.expenses += t.amount }
            monthGroups[monthStart] = entry
        }

        self.totalIncome = income
        self.totalExpenses = expenses
        self.netBalance = income - expenses
        self.expensesByCategory = expenseGroups.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
        self.incomeByCategory = incomeGroups.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
        self.monthlyTotals = monthGroups.map { MonthlyTotal(month: $0.key, income: $0.value.income, expenses: $0.value.expenses) }.sorted { $0.month < $1.month }
    }

    private static func filterByPeriod(_ transactions: [Transaction], period: ReportPeriod) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date.now
        switch period {
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

