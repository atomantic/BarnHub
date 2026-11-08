import SwiftUI
import SwiftData

// Home's dashboard widgets (Mac and iPad), each built from one HomeSummary.

/// Lessons, care visits and reminders for today and tomorrow.
struct HomeTodayWidget: View {
    let summary: HomeSummary
    @Environment(Router.self) private var router

    var body: some View {
        let events = makeEvents()
        return DashboardWidget(
            title: "Today & Tomorrow",
            icon: "calendar",
            accent: .blue,
            seeAll: { router.switchTab(.schedule) }
        ) {
            if events.isEmpty {
                DashboardEmptyRow(
                    icon: "calendar",
                    text: appLocalized("No events in the next 2 days", comment: "Dashboard empty state")
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(events) { event in
                        DashboardEventRow(event: event)
                    }
                }
            }
        }
    }

    private func makeEvents() -> [DashboardEvent] {
        let routerRef = router
        return summary.upcoming.prefix(6).map { item in
            let modelID = item.id.modelID
            let icon: String
            let color: Color
            let action: () -> Void
            switch item.kind {
            case .lesson:
                icon = "book.fill"
                color = .blue
                action = { routerRef.navigate(to: BarnRoute.lessonEdit(modelID), tab: .schedule) }
            case .vet:
                icon = "cross.case.fill"
                color = .red
                action = { routerRef.navigate(to: BarnRoute.vetSchedule, tab: .schedule) }
            case .farrier:
                icon = "hammer.fill"
                color = .orange
                action = { routerRef.navigate(to: BarnRoute.farrierSchedule, tab: .schedule) }
            case .reminder:
                icon = "bell.fill"
                color = .barnGreen
                action = { routerRef.navigate(to: BarnRoute.reminderEdit(modelID), tab: .schedule) }
            }
            return DashboardEvent(
                id: item.id, date: item.date, icon: icon, iconColor: color,
                title: item.title, subtitle: item.subtitle, action: action
            )
        }
    }
}

/// Overdue reminders and unpaid lessons.
struct HomeActionItemsWidget: View {
    let summary: HomeSummary
    @Environment(Router.self) private var router

    var body: some View {
        let reminders = summary.overdueReminders
        let unpaid = summary.unpaidLessons
        let hasItems = !reminders.isEmpty || !unpaid.isEmpty
        return DashboardWidget(
            title: "Action Items",
            icon: "checklist",
            accent: .orange,
            seeAll: nil
        ) {
            if !hasItems {
                DashboardEmptyRow(
                    icon: "checkmark.circle",
                    text: appLocalized("Nothing needs attention", comment: "Dashboard empty state")
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(reminders.prefix(4), id: \.persistentModelID) { reminder in
                        DashboardActionRow(
                            icon: "bell.badge.fill",
                            iconColor: .red,
                            title: reminder.title.isEmpty ? appLocalized("Reminder", comment: "Reminder fallback title") : reminder.title,
                            subtitle: appLocalized("Overdue · \(reminder.dueDate.shortFormatted)", comment: "Action Items subtitle for an overdue reminder: its due date")
                        ) {
                            router.navigate(to: BarnRoute.reminderEdit(reminder.persistentModelID), tab: .schedule)
                        }
                    }
                    ForEach(unpaid.prefix(4), id: \.persistentModelID) { lesson in
                        let name = lesson.client?.fullName ?? appLocalized("Unknown client", comment: "Unknown client fallback")
                        DashboardActionRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: .orange,
                            title: appLocalized("Unpaid: \(name)", comment: "Unpaid lesson row title"),
                            subtitle: appLocalized("\(lesson.cost.asCurrency) · \(lesson.date.shortFormatted)", comment: "Action Items subtitle for an unpaid lesson: the amount owed, then the lesson date")
                        ) {
                            router.navigate(to: BarnRoute.lessonEdit(lesson.persistentModelID), tab: .schedule)
                        }
                    }
                }
            }
        }
    }
}

/// Low stock and vet or farrier visits coming due.
struct HomeAlertsWidget: View {
    let summary: HomeSummary
    @Environment(Router.self) private var router

    var body: some View {
        let lowStock = summary.lowStock
        let vet = summary.upcomingVet
        let farrier = summary.upcomingFarrier
        let hasAlerts = !lowStock.isEmpty || !vet.isEmpty || !farrier.isEmpty
        return DashboardWidget(
            title: "Alerts",
            icon: "exclamationmark.triangle.fill",
            accent: .red,
            seeAll: nil
        ) {
            if !hasAlerts {
                DashboardEmptyRow(
                    icon: "checkmark.shield.fill",
                    text: appLocalized("All clear", comment: "Dashboard empty alerts state")
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(lowStock.prefix(3), id: \.persistentModelID) { item in
                        DashboardActionRow(
                            icon: "shippingbox.fill",
                            iconColor: .red,
                            title: appLocalized("\(item.name) low", comment: "Low stock alert title"),
                            subtitle: item.lowStockDetail
                        ) {
                            router.navigate(to: HomeRoute.supplies)
                        }
                    }
                    ForEach(vet.prefix(2), id: \.persistentModelID) { record in
                        let name = record.horse?.name ?? appLocalized("Horse", comment: "Horse fallback")
                        DashboardActionRow(
                            icon: "cross.case.fill",
                            iconColor: .orange,
                            title: appLocalized("Vet due: \(name)", comment: "Vet due alert"),
                            subtitle: record.nextDueDate?.shortFormatted ?? ""
                        ) {
                            router.navigate(to: BarnRoute.vetSchedule, tab: .schedule)
                        }
                    }
                    ForEach(farrier.prefix(2), id: \.persistentModelID) { visit in
                        let name = visit.horse?.name ?? appLocalized("Horse", comment: "Horse fallback")
                        DashboardActionRow(
                            icon: "hammer.fill",
                            iconColor: .orange,
                            title: appLocalized("Farrier due: \(name)", comment: "Farrier due alert"),
                            subtitle: visit.nextDueDate?.shortFormatted ?? ""
                        ) {
                            router.navigate(to: BarnRoute.farrierSchedule, tab: .schedule)
                        }
                    }
                }
            }
        }
    }
}

/// This month's income, expenses and balance.
struct HomeFinanceWidget: View {
    let summary: HomeSummary
    @Environment(Router.self) private var router

    var body: some View {
        let income = summary.month.income
        let expenses = summary.month.expenses
        let balance = income - expenses
        return DashboardWidget(
            title: "Finance · This Month",
            icon: "chart.line.uptrend.xyaxis",
            accent: .barnGreen,
            seeAll: { router.switchTab(.accounting) }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    FinanceMetric(
                        label: appLocalized("Income", comment: "Finance label"),
                        amount: income,
                        color: .barnGreen
                    )
                    FinanceMetric(
                        label: appLocalized("Expenses", comment: "Finance label"),
                        amount: expenses,
                        color: .red
                    )
                    FinanceMetric(
                        label: appLocalized("Balance", comment: "Finance label"),
                        amount: balance,
                        color: balance >= 0 ? .barnGreen : .red
                    )
                }
                IncomeExpenseBar(income: income, expenses: expenses)
            }
        }
    }
}

extension SupplyItem {
    /// The Alerts widget's low-stock subtitle, e.g. "3 bags · reorder at 5".
    var lowStockDetail: String {
        Self.lowStockDetail(quantity: quantity, unit: unit, reorderAt: reorderThreshold, locale: .app)
    }

    static func lowStockDetail(quantity: Double, unit: String, reorderAt threshold: Double, locale: Locale) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1)).locale(locale)
        let qty = quantity.formatted(style)
        let reorder = threshold.formatted(style)
        let unit = unit.trimmingCharacters(in: .whitespaces)
        if unit.isEmpty {
            return appLocalized("\(qty) · reorder at \(reorder)", comment: "Low stock alert subtitle: quantity on hand, then the reorder level")
        }
        return appLocalized("\(qty) \(unit) · reorder at \(reorder)", comment: "Low stock alert subtitle: quantity on hand, its unit (typed by the user, e.g. 'bags'), then the reorder level")
    }
}
