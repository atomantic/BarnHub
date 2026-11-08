import SwiftUI
import SwiftData

enum BalancePeriod: Int, CaseIterable, Identifiable {
    case thisMonth = 0
    case allTime = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .thisMonth: return appLocalized("This Month", comment: "Balance period")
        case .allTime:   return appLocalized("All Time",   comment: "Balance period")
        }
    }
}

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(\.modelContext) private var modelContext
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @AppStorage("net.shadowpuppet.BarnBook.balancePeriod") private var balancePeriodRaw: Int = BalancePeriod.thisMonth.rawValue

    private var balancePeriod: BalancePeriod {
        BalancePeriod(rawValue: balancePeriodRaw) ?? .thisMonth
    }

    @Query(filter: #Predicate<Horse> { $0.isActive }) private var activeHorses: [Horse]
    @Query(filter: #Predicate<Client> { $0.isActive }) private var activeClients: [Client]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]
    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]
    @Query(sort: \DentistVisit.date, order: .reverse) private var dentistVisits: [DentistVisit]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Lesson.date) private var lessons: [Lesson]
    @Query private var supplyItems: [SupplyItem]

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    #else
    private var columns: [GridItem] {
        if sizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }
    #endif

    private var monthlyBalance: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: .now)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return 0 }
        return transactions.reduce(0) { result, txn in
            guard txn.date >= monthStart && txn.date < monthEnd else { return result }
            return txn.type == .income ? result + txn.amount : result - txn.amount
        }
    }

    private var allTimeBalance: Double {
        transactions.reduce(0) { result, txn in
            txn.type == .income ? result + txn.amount : result - txn.amount
        }
    }

    private var displayBalance: Double {
        balancePeriod == .thisMonth ? monthlyBalance : allTimeBalance
    }


    private var nextScheduleItemToday: String? {
        let calendar = Calendar.current
        let now = Date.now
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"

        struct ScheduleItem: Comparable {
            let date: Date
            let label: String
            static func < (lhs: ScheduleItem, rhs: ScheduleItem) -> Bool { lhs.date < rhs.date }
        }

        var items: [ScheduleItem] = []

        for lesson in lessons where calendar.isDateInToday(lesson.date) && lesson.date >= now {
            items.append(ScheduleItem(date: lesson.date, label: "\(timeFormatter.string(from: lesson.date)) Lesson"))
        }
        for record in vetRecords {
            guard let due = record.nextDueDate, calendar.isDateInToday(due), due >= now else { continue }
            items.append(ScheduleItem(date: due, label: "\(timeFormatter.string(from: due)) Vet"))
        }
        for visit in farrierVisits {
            guard let due = visit.nextDueDate, calendar.isDateInToday(due), due >= now else { continue }
            items.append(ScheduleItem(date: due, label: "\(timeFormatter.string(from: due)) Farrier"))
        }
        for visit in dentistVisits {
            guard let due = visit.nextDueDate, calendar.isDateInToday(due), due >= now else { continue }
            items.append(ScheduleItem(date: due, label: "\(timeFormatter.string(from: due)) Dentist"))
        }

        return items.sorted().first?.label
    }

    private var lowStockCount: Int {
        supplyItems.filter { $0.isLowStock }.count
    }

    private var todayReminders: [Reminder] {
        let calendar = Calendar.current
        return Array(
            incompleteReminders
                .filter { !$0.dueDate.isOverdue && (calendar.isDateInToday($0.dueDate) || calendar.isDateInTomorrow($0.dueDate)) }
                .prefix(3)
        )
    }

    var body: some View {
        let balance = displayBalance
        let todayRems = todayReminders
        return ScrollView {
            VStack(spacing: 0) {
                headerSection
                Spacer()
                    #if os(macOS)
                    .frame(height: 12)
                    #else
                    .frame(height: 20)
                    #endif
                if !storeService.isPro {
                    upgradeBar
                }
                #if os(macOS)
                macDashboard(balance: balance)
                #else
                if sizeClass == .regular {
                    iPadDashboard(balance: balance)
                } else {
                    if !todayRems.isEmpty {
                        todaySection(reminders: todayRems)
                    }
                    iconGrid(balance: balance)
                }
                #endif
            }
        }
        .background(Color.barnOffWhite)
        .ignoresSafeArea(edges: .top)
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Color.barnGreen
                #if os(macOS)
                .frame(height: 200)
                #else
                // Scale with the container instead of a fixed iPhone height, so the
                // short, wide iPhone Duo outer display (and landscape) keeps room for content.
                .containerRelativeFrame(.vertical) { height, _ in
                    // Shorter on iPad-sized screens, where the dashboard needs the room.
                    sizeClass == .regular
                        ? min(200, max(160, height * 0.2))
                        : min(260, max(210, height * 0.32))
                }
                #endif
                // Let the green run under the vertical tab bar / side toolbar.
                .barnBackgroundExtension()

            VStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    #if os(macOS)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    #else
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    #endif
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .accessibilityLabel("BarnHub logo")

                HStack(spacing: 8) {
                    Text("BarnHub")
                        #if os(macOS)
                        .font(.title3.weight(.bold))
                        #else
                        .font(.title.weight(.bold))
                        #endif
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                    if storeService.isPro {
                        ProBadgeView()
                    }
                }
            }
            #if os(macOS)
            .padding(.bottom, 44)
            #else
            .padding(.bottom, 50)
            #endif

            SwooshShape()
                .fill(Color.barnOffWhite)
                #if os(macOS)
                .frame(height: 28)
                #else
                .frame(height: 50)
                #endif
        }
    }

    private var upgradeBar: some View {
        Button {
            router.navigate(to: SubscriptionRoute.paywall)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.barnGreen)
                Text("Upgrade to BarnHub Pro")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.barnBrown)
                Spacer()
                ProBadgeView()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.barnCardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    // MARK: - Today Section (iOS)

    private func todaySection(reminders: [Reminder]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coming Up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.barnBrown)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(reminders, id: \.persistentModelID) { reminder in
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.barnGreen)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reminder.title)
                                .font(.subheadline)
                            if let horse = reminder.horse {
                                Text(horse.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(reminder.dueDate.shortFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.barnCardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }

    private func iconGrid(balance: Double) -> some View {
        let horseCount = activeHorses.count
        let clientCount = activeClients.count
        let stockAlert = lowStockCount

        #if os(macOS)
        let vSpacing: CGFloat = 12
        #else
        let vSpacing: CGFloat = 20
        #endif
        return LazyVGrid(columns: columns, spacing: vSpacing) {
            FeatureTile(icon: "figure.equestrian.sports", title: "Horses", color: .barnBrown, badge: appLocalized("^[\(horseCount) horse](inflect: true)", comment: "Horse count badge"), tag: "tile_horses") {
                router.switchTab(.horses)
            }
            FeatureTile(icon: "person.2.fill", title: "Clients", color: .barnBrown, badge: appLocalized("^[\(clientCount) client](inflect: true)", comment: "Client count badge"), tag: "tile_clients") {
                router.switchTab(.clients)
            }
            FeatureTile(icon: "calendar", title: "Schedule", color: .barnBrown, badge: nextScheduleItemToday, tag: "tile_schedule") {
                router.switchTab(.schedule)
            }
            FeatureTile(icon: "shippingbox.fill", title: "Supplies", color: .barnBrown, badge: stockAlert > 0 ? "\(stockAlert) Low" : nil, badgeColor: stockAlert > 0 ? .red : nil, tag: "tile_supplies") {
                router.navigate(to: HomeRoute.supplies)
            }
            FeatureTile(icon: "dollarsign.circle.fill", title: "Accounting", color: .barnBrown, badge: balance.asCurrency, badgeColor: balance >= 0 ? .barnGreen : .red, badgeDetail: balancePeriod.displayName, tag: "tile_accounting") {
                router.switchTab(.accounting)
            }
            FeatureTile(icon: "chart.bar.fill", title: "Reports", color: .barnBrown, tag: "tile_reports") {
                router.navigate(to: HomeRoute.reports)
            }
            FeatureTile(icon: "note.text", title: "Barn Notes", color: .barnBrown, tag: "tile_notes") {
                router.navigate(to: HomeRoute.barnNotes)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Dashboard

    private func macDashboard(balance: Double) -> some View {
        // No tile grid on the Mac: every tile's destination is already in the
        // sidebar, so the space goes to the dashboard widgets.
        VStack(spacing: 16) {
            statsStrip
            widgetGrid
        }
        .padding(.bottom, 24)
    }

    #if !os(macOS)
    private func iPadDashboard(balance: Double) -> some View {
        VStack(spacing: 20) {
            statsStrip
            widgetGrid
            iconGrid(balance: balance)
        }
        .padding(.bottom, 32)
    }
    #endif

    private var statsStrip: some View {
        HStack(spacing: 12) {
            DashboardStatCard(
                icon: "figure.equestrian.sports",
                title: appLocalized("Horses", comment: "Dashboard stat"),
                value: "\(activeHorses.count)",
                accent: .barnBrown
            ) { router.switchTab(.horses) }
            DashboardStatCard(
                icon: "person.2.fill",
                title: appLocalized("Clients", comment: "Dashboard stat"),
                value: "\(activeClients.count)",
                accent: .barnBrown
            ) { router.switchTab(.clients) }
            DashboardStatCard(
                icon: "dollarsign.circle.fill",
                title: appLocalized("This Month", comment: "Dashboard stat"),
                value: monthlyBalance.asCurrency,
                accent: monthlyBalance >= 0 ? .barnGreen : .red
            ) { router.switchTab(.accounting) }
            DashboardStatCard(
                icon: "shippingbox.fill",
                title: appLocalized("Low Stock", comment: "Dashboard stat"),
                value: "\(lowStockCount)",
                accent: lowStockCount > 0 ? .red : .secondary
            ) { router.navigate(to: HomeRoute.supplies) }
        }
        .padding(.horizontal, 24)
    }

    private var widgetGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            todayWidget
            actionItemsWidget
            alertsWidget
            financeWidget
        }
        .padding(.horizontal, 24)
    }

    // MARK: Today Widget

    private var upcomingEvents: [DashboardEvent] {
        let cal = Calendar.current
        let now = Date.now
        guard let cutoff = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now)) else { return [] }
        let routerRef = router
        var events: [DashboardEvent] = []

        for lesson in lessons where lesson.date >= now && lesson.date < cutoff {
            let subtitle = [lesson.client?.fullName, lesson.horse?.name]
                .compactMap { $0 }.joined(separator: " • ")
            let lessonID = lesson.persistentModelID
            events.append(DashboardEvent(
                id: "lesson-\(lessonID.hashValue)",
                date: lesson.date,
                icon: "book.fill",
                iconColor: .blue,
                title: appLocalized("Lesson", comment: "Dashboard event type"),
                subtitle: subtitle.isEmpty ? nil : subtitle,
                action: {
                    routerRef.navigate(to: BarnRoute.lessonEdit(lessonID), tab: .schedule)
                }
            ))
        }

        for record in vetRecords {
            guard let due = record.nextDueDate, due >= now, due < cutoff else { continue }
            let recordHash = record.persistentModelID.hashValue
            events.append(DashboardEvent(
                id: "vet-\(recordHash)",
                date: due,
                icon: "cross.case.fill",
                iconColor: .red,
                title: appLocalized("Vet", comment: "Dashboard event type"),
                subtitle: record.horse?.name,
                action: {
                    routerRef.navigate(to: BarnRoute.vetSchedule, tab: .schedule)
                }
            ))
        }

        for visit in farrierVisits {
            guard let due = visit.nextDueDate, due >= now, due < cutoff else { continue }
            let visitHash = visit.persistentModelID.hashValue
            events.append(DashboardEvent(
                id: "far-\(visitHash)",
                date: due,
                icon: "hammer.fill",
                iconColor: .orange,
                title: appLocalized("Farrier", comment: "Dashboard event type"),
                subtitle: visit.horse?.name,
                action: {
                    routerRef.navigate(to: BarnRoute.farrierSchedule, tab: .schedule)
                }
            ))
        }

        for reminder in incompleteReminders where reminder.dueDate >= now && reminder.dueDate < cutoff {
            let reminderID = reminder.persistentModelID
            events.append(DashboardEvent(
                id: "rem-\(reminderID.hashValue)",
                date: reminder.dueDate,
                icon: "bell.fill",
                iconColor: .barnGreen,
                title: reminder.title.isEmpty ? appLocalized("Reminder", comment: "Dashboard event type") : reminder.title,
                subtitle: reminder.horse?.name,
                action: {
                    routerRef.navigate(to: BarnRoute.reminderEdit(reminderID), tab: .schedule)
                }
            ))
        }

        return events.sorted { $0.date < $1.date }
    }

    private var todayWidget: some View {
        let events = upcomingEvents
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
                    ForEach(events.prefix(6)) { event in
                        DashboardEventRow(event: event)
                    }
                }
            }
        }
    }

    // MARK: Action Items Widget

    private var overdueReminders: [Reminder] {
        incompleteReminders.filter { $0.dueDate.isOverdue }
    }

    private var unpaidLessons: [Lesson] {
        lessons.filter { !$0.isPaid && $0.date <= .now && $0.cost > 0 }
            .sorted { $0.date > $1.date }
    }

    private var actionItemsWidget: some View {
        let reminders = overdueReminders
        let unpaid = unpaidLessons
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
                            subtitle: "\(appLocalized("Overdue", comment: "Dashboard overdue label")) · \(reminder.dueDate.shortFormatted)"
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
                            subtitle: "\(lesson.cost.asCurrency) · \(lesson.date.shortFormatted)"
                        ) {
                            router.navigate(to: BarnRoute.lessonEdit(lesson.persistentModelID), tab: .schedule)
                        }
                    }
                }
            }
        }
    }

    // MARK: Alerts Widget

    private var lowStockSupplies: [SupplyItem] {
        supplyItems.filter { $0.isLowStock }
    }

    private var upcomingVet: [VetRecord] {
        let cal = Calendar.current
        let now = Date.now
        guard let cutoff = cal.date(byAdding: .day, value: 7, to: now) else { return [] }
        return vetRecords
            .filter { $0.nextDueDate.map { $0 >= now && $0 <= cutoff } ?? false }
            .sorted { ($0.nextDueDate ?? .now) < ($1.nextDueDate ?? .now) }
    }

    private var upcomingFarrier: [FarrierVisit] {
        let cal = Calendar.current
        let now = Date.now
        guard let cutoff = cal.date(byAdding: .day, value: 7, to: now) else { return [] }
        return farrierVisits
            .filter { $0.nextDueDate.map { $0 >= now && $0 <= cutoff } ?? false }
            .sorted { ($0.nextDueDate ?? .now) < ($1.nextDueDate ?? .now) }
    }

    private var alertsWidget: some View {
        let lowStock = lowStockSupplies
        let vet = upcomingVet
        let farrier = upcomingFarrier
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
                        let qty = item.quantity.formatted(.number.precision(.fractionLength(0...1)))
                        let unit = item.unit.isEmpty ? "" : " \(item.unit)"
                        DashboardActionRow(
                            icon: "shippingbox.fill",
                            iconColor: .red,
                            title: appLocalized("\(item.name) low", comment: "Low stock alert title"),
                            subtitle: "\(qty)\(unit) · \(appLocalized("reorder at", comment: "reorder threshold label")) \(item.reorderThreshold.formatted(.number.precision(.fractionLength(0...1))))"
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

    // MARK: Finance Widget

    private var monthlyIncome: Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: .now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return transactions
            .filter { $0.date >= start && $0.date < end && $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpenses: Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: .now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return transactions
            .filter { $0.date >= start && $0.date < end && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var financeWidget: some View {
        let income = monthlyIncome
        let expenses = monthlyExpenses
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

// MARK: - Feature Tile (iOS + macOS quick nav)

struct FeatureTile: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    var badge: String? = nil
    var badgeColor: Color? = nil
    var badgeDetail: String? = nil
    var tag: String? = nil
    let action: () -> Void

    #if os(macOS)
    private var tileSpacing: CGFloat { 6 }
    private var tileRadius: CGFloat { 10 }
    private var tileIconFont: Font { .body }
    #else
    private var tileSpacing: CGFloat { 10 }
    private var tileRadius: CGFloat { 16 }
    private var tileIconFont: Font { .title }
    #endif

    var body: some View {
        Button(action: action) {
            VStack(spacing: tileSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: tileRadius)
                        .fill(.barnCardBackground)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(tileIconFont)
                            .foregroundStyle(color)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(badgeColor ?? .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if let badgeDetail {
                            Text(badgeDetail)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #if os(macOS)
                .frame(height: 72)
                #else
                .aspectRatio(1, contentMode: .fit)
                #endif

                Text(title)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.barnBrown)
            }
        }
        .buttonStyle(.plain)
        .modifier(OptionalAccessibilityID(tag))
    }
}

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

struct SwooshShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: -rect.height * 0.6)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dashboard Widget Primitives

struct DashboardEvent: Identifiable {
    let id: String
    let date: Date
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
}

struct DashboardWidget<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let accent: Color
    var seeAll: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.barnBrown)
                Spacer()
                if let seeAll {
                    Button(action: seeAll) {
                        HStack(spacing: 2) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.barnGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
            content
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.barnCardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }
}

struct DashboardStatCard: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.barnBrown)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.barnCardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DashboardEventRow: View {
    let event: DashboardEvent

    var body: some View {
        Button(action: event.action) {
            HStack(spacing: 10) {
                Image(systemName: event.icon)
                    .font(.caption)
                    .foregroundStyle(event.iconColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let subtitle = event.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Text(event.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DashboardActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DashboardEmptyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

struct FinanceMetric: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IncomeExpenseBar: View {
    let income: Double
    let expenses: Double

    var body: some View {
        let total = max(income + expenses, 0.0001)
        let incomeFraction = income / total
        return GeometryReader { geo in
            HStack(spacing: 2) {
                Rectangle()
                    .fill(Color.barnGreen)
                    .frame(width: max(0, geo.size.width * incomeFraction))
                Rectangle()
                    .fill(Color.red.opacity(0.85))
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .opacity(income + expenses > 0 ? 1 : 0.15)
    }
}
