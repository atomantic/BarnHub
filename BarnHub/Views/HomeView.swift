import SwiftUI
import SwiftData

enum BalancePeriod: Int, CaseIterable, Identifiable {
    case thisMonth = 0
    case allTime = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .thisMonth: "This Month"
        case .allTime: "All Time"
        }
    }
}

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(\.modelContext) private var modelContext
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
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
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

    private var overdueReminders: [Reminder] {
        incompleteReminders.filter { $0.dueDate.isOverdue }
    }

    private var overdueVetRecords: [VetRecord] {
        vetRecords.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }
    }

    private var overdueFarrierVisits: [FarrierVisit] {
        farrierVisits.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }
    }

    private var totalOverdueCount: Int {
        overdueReminders.count + overdueVetRecords.count + overdueFarrierVisits.count
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
        let overdueRems = overdueReminders
        let overdueVet = overdueVetRecords
        let overdueFarrier = overdueFarrierVisits
        let overdueCount = overdueRems.count + overdueVet.count + overdueFarrier.count
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
                if overdueCount > 0 {
                    overdueAlertsSection(reminders: overdueRems, vetRecords: overdueVet, farrierVisits: overdueFarrier, count: overdueCount)
                }
                if !todayRems.isEmpty {
                    todaySection(reminders: todayRems)
                }
                iconGrid(balance: balance)
            }
        }
        .background(Color.barnOffWhite)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItemGroup(placement: .trailingBar) {
                SyncIndicatorView()
                Button {
                    router.navigate(to: HomeRoute.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        #if os(macOS)
                        .foregroundStyle(.secondary)
                        #else
                        .foregroundStyle(.white)
                        #endif
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Color.barnGreen
                #if os(macOS)
                .frame(height: 200)
                #else
                .frame(height: 260)
                #endif

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
            .padding(.bottom, 30)
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

    // MARK: - Overdue Alerts

    private func overdueAlertsSection(reminders: [Reminder], vetRecords: [VetRecord], farrierVisits: [FarrierVisit], count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Overdue (\(count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(reminders.prefix(3), id: \.persistentModelID) { reminder in
                    Button {
                        router.switchTab(.schedule)
                        router.navigate(to: BarnRoute.reminderEdit(reminder.persistentModelID), tab: .schedule)
                    } label: {
                        overdueRow(
                            icon: "bell.fill",
                            title: reminder.title,
                            subtitle: reminder.horse?.name,
                            date: reminder.dueDate
                        )
                    }
                    .buttonStyle(.plain)
                }
                ForEach(vetRecords.prefix(2), id: \.persistentModelID) { record in
                    overdueRow(
                        icon: "cross.case.fill",
                        title: "Vet: \(record.horse?.name ?? "Unknown")",
                        subtitle: record.vetName,
                        date: record.nextDueDate
                    )
                }
                ForEach(farrierVisits.prefix(2), id: \.persistentModelID) { visit in
                    overdueRow(
                        icon: "hammer.fill",
                        title: "Farrier: \(visit.horse?.name ?? "Unknown")",
                        subtitle: visit.farrierName,
                        date: visit.nextDueDate
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.barnCardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
            .padding(.horizontal, 24)

            Button {
                router.switchTab(.schedule)
            } label: {
                Text("See all")
                    .font(.caption)
                    .foregroundStyle(.barnGreen)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }

    private func overdueRow(icon: String, title: String, subtitle: String?, date: Date?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let date {
                Text(date.relativeDateString)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Today Section

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
            FeatureTile(icon: "figure.equestrian.sports", title: "Horses", color: .barnBrown, badge: "\(horseCount) \(horseCount == 1 ? "Horse" : "Horses")") {
                router.switchTab(.horses)
            }
            FeatureTile(icon: "person.2.fill", title: "Clients", color: .barnBrown, badge: "\(clientCount) \(clientCount == 1 ? "Client" : "Clients")") {
                router.switchTab(.clients)
            }
            FeatureTile(icon: "calendar", title: "Schedule", color: .barnBrown, badge: nextScheduleItemToday) {
                router.switchTab(.schedule)
            }
            FeatureTile(icon: "shippingbox.fill", title: "Supplies", color: .barnBrown, badge: stockAlert > 0 ? "\(stockAlert) Low" : nil, badgeColor: stockAlert > 0 ? .red : nil) {
                router.navigate(to: HomeRoute.supplies)
            }
            FeatureTile(icon: "dollarsign.circle.fill", title: "Accounting", color: .barnBrown, badge: balance.asCurrency, badgeColor: balance >= 0 ? .barnGreen : .red, badgeDetail: balancePeriod.displayName) {
                router.switchTab(.accounting)
            }
            FeatureTile(icon: "chart.bar.fill", title: "Reports", color: .barnBrown) {
                router.navigate(to: HomeRoute.reports)
            }
            FeatureTile(icon: "note.text", title: "Barn Notes", color: .barnBrown) {
                router.navigate(to: HomeRoute.barnNotes)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

struct FeatureTile: View {
    let icon: String
    let title: String
    let color: Color
    var badge: String? = nil
    var badgeColor: Color? = nil
    var badgeDetail: String? = nil
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
