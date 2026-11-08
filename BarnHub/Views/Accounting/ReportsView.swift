import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService

    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @Environment(\.locale) private var locale
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var showFullReports: Bool {
        FeatureGate.canAccessFullReports(storeService.isPro)
    }

    var body: some View {
        // Only the selected period's transactions are fetched (#32).
        QueryContent(FinanceSummary.descriptor(for: selectedPeriod)) { transactions in
            report(FinanceSummary(transactions: transactions))
        }
        .navigationTitle("Reports")
        .inlineNavTitle()
    }

    private func report(_ data: FinanceSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                summaryCards(data: data)
                if data.filteredTransactions.isEmpty {
                    emptyState
                } else {
                    incomeExpenseChart(data: data)
                    if showFullReports {
                        if isWide {
                            wideChartsLayout(data: data)
                        } else {
                            if data.monthlyTotals.count > 1 {
                                monthlyTrendChart(data: data)
                            }
                            if !data.expensesByCategory.isEmpty {
                                categoryBreakdownSection("Expenses by Category", data: data.expensesByCategory, total: data.totalExpenses, colors: expenseCategoryColors)
                            }
                            if !data.incomeByCategory.isEmpty {
                                categoryBreakdownSection("Income by Category", data: data.incomeByCategory, total: data.totalIncome, colors: incomeCategoryColors)
                            }
                        }
                    } else {
                        lockedSection
                    }
                }
            }
            .padding()
            // Keep charts readable on very wide screens (Mac, iPad landscape).
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(Color.barnOffWhite)
    }

    /// macOS always; iOS at regular width (iPad, iPhone Duo inner display).
    private var isWide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    @ViewBuilder
    private func wideChartsLayout(data: FinanceSummary) -> some View {
        let hasTrend = data.monthlyTotals.count > 1
        let hasCategories = !data.expensesByCategory.isEmpty || !data.incomeByCategory.isEmpty

        if hasTrend && hasCategories {
            HStack(alignment: .top, spacing: 16) {
                monthlyTrendChart(data: data)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    if !data.expensesByCategory.isEmpty {
                        categoryBreakdownSection("Expenses by Category", data: data.expensesByCategory, total: data.totalExpenses, colors: expenseCategoryColors)
                    }
                    if !data.incomeByCategory.isEmpty {
                        categoryBreakdownSection("Income by Category", data: data.incomeByCategory, total: data.totalIncome, colors: incomeCategoryColors)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            if hasTrend {
                monthlyTrendChart(data: data)
            }
            // No trend (e.g. a single month): put the two breakdowns side by side.
            HStack(alignment: .top, spacing: 16) {
                if !data.expensesByCategory.isEmpty {
                    categoryBreakdownSection("Expenses by Category", data: data.expensesByCategory, total: data.totalExpenses, colors: expenseCategoryColors)
                        .frame(maxWidth: .infinity)
                }
                if !data.incomeByCategory.isEmpty {
                    categoryBreakdownSection("Income by Category", data: data.incomeByCategory, total: data.totalIncome, colors: incomeCategoryColors)
                        .frame(maxWidth: .infinity)
                }
            }
        }
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

    private func summaryCards(data: FinanceSummary) -> some View {
        HStack(spacing: 12) {
            SummaryCard(title: "Income", amount: data.totalIncome, color: .green, icon: "arrow.down.circle.fill")
            SummaryCard(title: "Expenses", amount: data.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
            SummaryCard(title: "Net", amount: data.netBalance, color: data.netBalance >= 0 ? .barnGreen : .red, icon: "equal.circle.fill")
        }
    }

    // MARK: - Income vs Expense Bar Chart

    private func incomeExpenseChart(data: FinanceSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses")
                .font(.headline)

            Chart {
                BarMark(
                    x: .value(typeLabel, incomeLabel),
                    y: .value(amountLabel, data.totalIncome)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)

                BarMark(
                    x: .value(typeLabel, expensesLabel),
                    y: .value(amountLabel, data.totalExpenses)
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

    private func monthlyTrendChart(data: FinanceSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trend")
                .font(.headline)

            Chart(data.monthlyTotals) { total in
                LineMark(
                    x: .value(monthLabel, total.month, unit: .month),
                    y: .value(incomeLabel, total.income),
                    series: .value(seriesLabel, incomeLabel)
                )
                .foregroundStyle(.green)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value(monthLabel, total.month, unit: .month),
                    y: .value(incomeLabel, total.income),
                    series: .value(seriesLabel, incomeLabel),
                    stacking: .unstacked
                )
                .foregroundStyle(.green.opacity(0.1))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value(monthLabel, total.month, unit: .month),
                    y: .value(expensesLabel, total.expenses),
                    series: .value(seriesLabel, expensesLabel)
                )
                .foregroundStyle(.red)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value(monthLabel, total.month, unit: .month),
                    y: .value(expensesLabel, total.expenses),
                    series: .value(seriesLabel, expensesLabel),
                    stacking: .unstacked
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
        _ title: LocalizedStringKey,
        data: [(category: TransactionCategory, amount: Double)],
        total: Double,
        colors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Chart(Array(data.enumerated()), id: \.element.category) { index, item in
                SectorMark(
                    angle: .value(amountLabel, item.amount),
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

    private func legendDot(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func percentString(_ value: Double, of total: Double) -> String {
        let fraction = total > 0 ? value / total : 0
        return fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    // Chart labels and series names, read by VoiceOver and shown on the bar
    // chart's axis. Charts takes plain strings here, so localize them up front.
    private var typeLabel: String { appLocalized("Type", comment: "Reports chart: label of the income/expenses axis") }
    private var amountLabel: String { appLocalized("Amount", comment: "Reports chart: label of the amount axis") }
    private var monthLabel: String { appLocalized("Month", comment: "Reports chart: label of the month axis") }
    private var seriesLabel: String { appLocalized("Series", comment: "Reports chart: label of the income/expenses lines in the monthly trend") }
    private var incomeLabel: String { appLocalized("Income", comment: "Reports chart: income bar and trend line") }
    private var expensesLabel: String { appLocalized("Expenses", comment: "Reports chart: expenses bar and trend line") }

    private var expenseCategoryColors: [Color] {
        [.red, .orange, .yellow, .pink, .purple, .brown, .indigo, .mint, .teal]
    }

    private var incomeCategoryColors: [Color] {
        [.green, .barnGreen, .teal, .cyan, .mint, .blue, .indigo, .purple, .yellow]
    }
}
