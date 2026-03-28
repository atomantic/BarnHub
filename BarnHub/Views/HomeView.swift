import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Horse> { $0.isActive }) private var activeHorses: [Horse]
    @Query(filter: #Predicate<Client> { $0.isActive }) private var activeClients: [Client]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]
    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

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

    private var todayReminders: [Reminder] {
        let calendar = Calendar.current
        return Array(
            incompleteReminders
                .filter { !$0.dueDate.isOverdue && (calendar.isDateInToday($0.dueDate) || calendar.isDateInTomorrow($0.dueDate)) }
                .prefix(3)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                Spacer()
                    .frame(height: 20)
                if !storeService.isPro {
                    upgradeBar
                }
                statsBar
                if totalOverdueCount > 0 {
                    overdueAlertsSection
                }
                if !todayReminders.isEmpty {
                    todaySection
                }
                iconGrid
            }
        }
        .background(Color.barnOffWhite)
        .ignoresSafeArea(edges: .top)
        .task {
            notificationService.scheduleAllPending(context: modelContext)
            let todayCount = incompleteReminders.filter { Calendar.current.isDateInToday($0.dueDate) }.count
            notificationService.scheduleMorningSummary(overdueCount: totalOverdueCount, todayCount: todayCount)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    SyncIndicatorView()
                    Button {
                        router.navigate(to: HomeRoute.settings)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Color.barnGreen
                .frame(height: 260)

            VStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .accessibilityLabel("BarnHub logo")

                HStack(spacing: 8) {
                    Text("BarnHub")
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                    if storeService.isPro {
                        ProBadgeView()
                    }
                }
            }
            .padding(.bottom, 50)

            SwooshShape()
                .fill(Color.barnOffWhite)
                .frame(height: 50)
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

    // MARK: - Stats Bar

    private var statsBar: some View {
        let balance = monthlyBalance
        return HStack(spacing: 12) {
            statCard(value: "\(activeHorses.count)", label: "Horses", icon: "figure.equestrian.sports", color: .barnBrown)
            statCard(value: "\(activeClients.count)", label: "Clients", icon: "person.2.fill", color: .barnBrown)
            statCard(value: balance.asCurrency, label: "This Month", icon: "dollarsign.circle.fill", color: balance >= 0 ? .barnGreen : .red)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.barnCardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }

    // MARK: - Overdue Alerts

    private var overdueAlertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Overdue (\(totalOverdueCount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(overdueReminders.prefix(3), id: \.persistentModelID) { reminder in
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
                ForEach(overdueVetRecords.prefix(2), id: \.persistentModelID) { record in
                    overdueRow(
                        icon: "cross.case.fill",
                        title: "Vet: \(record.horse?.name ?? "Unknown")",
                        subtitle: record.vetName,
                        date: record.nextDueDate
                    )
                }
                ForEach(overdueFarrierVisits.prefix(2), id: \.persistentModelID) { visit in
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

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coming Up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.barnBrown)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(todayReminders, id: \.persistentModelID) { reminder in
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

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            FeatureTile(icon: "figure.equestrian.sports", title: "Horses", color: .barnBrown) {
                router.switchTab(.horses)
            }
            FeatureTile(icon: "person.2.fill", title: "Clients", color: .barnBrown) {
                router.switchTab(.clients)
            }
            FeatureTile(icon: "calendar", title: "Schedule", color: .barnBrown) {
                router.switchTab(.schedule)
            }
            FeatureTile(icon: "shippingbox.fill", title: "Supplies", color: .barnBrown) {
                router.navigate(to: HomeRoute.supplies)
            }
            FeatureTile(icon: "dollarsign.circle.fill", title: "Accounting", color: .barnBrown) {
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.barnCardBackground)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(color)
                }
                .aspectRatio(1, contentMode: .fit)

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
