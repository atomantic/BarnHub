import Foundation
import SwiftData

// Report periods and the totals Reports shows for one. Home and Accounting use
// the same `ReportPeriod.thisMonth` interval for their "This Month" figures, so
// all three agree on what "this month" means.

/// A Reports period. "This" periods are the whole calendar month, quarter or
/// year containing now, including transactions dated later in it (a boarding
/// fee entered ahead for the 28th counts toward this month on the 3rd).
enum ReportPeriod: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, thisQuarter, thisYear, allTime
    var id: String { rawValue }

    /// Short label for the segmented control.
    var label: String {
        switch self {
        case .thisMonth:   return appLocalized("Month",   comment: "Report period: the current calendar month (short, segmented control)")
        case .lastMonth:   return appLocalized("Last Mo", comment: "Report period: the previous calendar month (short, segmented control)")
        case .thisQuarter: return appLocalized("Quarter", comment: "Report period: the current calendar quarter (short, segmented control)")
        case .thisYear:    return appLocalized("Year",    comment: "Report period: the current calendar year (short, segmented control)")
        case .allTime:     return appLocalized("All",     comment: "Report period: every transaction (short, segmented control)")
        }
    }

    /// The period containing `now`, as `[start, end)`; nil for All Time.
    func interval(asOf now: Date, calendar: Calendar = .current) -> DateInterval? {
        let month = FinanceSummary.currentMonth(asOf: now, calendar: calendar)
        switch self {
        case .thisMonth:
            return month
        case .lastMonth:
            guard let start = calendar.date(byAdding: .month, value: -1, to: month.start) else { return nil }
            return DateInterval(start: start, end: month.start)
        case .thisQuarter:
            let monthOfQuarter = (calendar.component(.month, from: now) - 1) % 3
            guard let start = calendar.date(byAdding: .month, value: -monthOfQuarter, to: month.start),
                  let end = calendar.date(byAdding: .month, value: 3, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .thisYear:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            guard let start = calendar.date(from: components),
                  let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .allTime:
            return nil
        }
    }
}

/// Income, expenses and their breakdowns for the transactions of one period.
struct FinanceSummary {
    let filteredTransactions: [Transaction]
    let totalIncome: Double
    let totalExpenses: Double
    let netBalance: Double
    let expensesByCategory: [(category: TransactionCategory, amount: Double)]
    let incomeByCategory: [(category: TransactionCategory, amount: Double)]
    let monthlyTotals: [MonthlyTotal]

    /// Totals for `filtered`, the transactions of one period (see `descriptor(for:)`).
    /// `calendar` decides which month each transaction falls in for the trend.
    init(transactions filtered: [Transaction], calendar: Calendar = .current) {
        self.filteredTransactions = filtered

        let totals = TransactionTotals(filtered)
        var expenseGroups: [TransactionCategory: Double] = [:]
        var incomeGroups: [TransactionCategory: Double] = [:]
        var monthGroups: [Date: (income: Double, expenses: Double)] = [:]

        for t in filtered {
            let monthStart = calendar.monthInterval(containing: t.date).start
            var entry = monthGroups[monthStart, default: (income: 0, expenses: 0)]
            if t.type == .income {
                incomeGroups[t.category, default: 0] += t.amount
                entry.income += t.amount
            } else {
                expenseGroups[t.category, default: 0] += t.amount
                entry.expenses += t.amount
            }
            monthGroups[monthStart] = entry
        }

        self.totalIncome = totals.income
        self.totalExpenses = totals.expenses
        self.netBalance = totals.balance
        self.expensesByCategory = expenseGroups.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
        self.incomeByCategory = incomeGroups.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
        self.monthlyTotals = monthGroups.map { MonthlyTotal(month: $0.key, income: $0.value.income, expenses: $0.value.expenses) }.sorted { $0.month < $1.month }
    }

    /// The calendar month containing `now`: Reports' Month period and the "This
    /// Month" totals on Home and Accounting.
    static func currentMonth(asOf now: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.monthInterval(containing: now)
    }

    /// Fetches the transactions in `period` as of `now` (see `ReportPeriod.interval`).
    static func descriptor(for period: ReportPeriod, now: Date = .now, calendar: Calendar = .current) -> FetchDescriptor<Transaction> {
        guard let interval = period.interval(asOf: now, calendar: calendar) else { return FetchDescriptor() }
        return FetchDescriptor(predicate: Transaction.dated(from: interval.start, before: interval.end))
    }
}

struct MonthlyTotal: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expenses: Double
}
