import SwiftUI
import SwiftData
import Combine

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

/// Home. Holds the moment Home's queries are anchored to and moves it forward
/// when Home reappears, the app returns to the foreground or the date changes,
/// so "today", "this month" and the upcoming windows never go stale.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var anchor = Date.now

    var body: some View {
        HomeDashboard(window: HomeSummary.Window(anchor: anchor))
            .onAppear { reanchor() }
            .onChange(of: scenePhase) {
                if scenePhase == .active { reanchor() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                reanchor()
            }
    }

    /// Re-anchoring rebuilds the queries, so skip it within a minute of the last time.
    private func reanchor() {
        let now = Date.now
        if now.timeIntervalSince(anchor) > 60 || !Calendar.current.isDate(anchor, inSameDayAs: now) {
            anchor = now
        }
    }
}

private struct HomeDashboard: View {
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

    // Each query fetches only what Home shows (see HomeSummary.Window).
    @Query private var monthTransactions: [Transaction]
    @Query private var reminders: [Reminder]
    @Query private var lessons: [Lesson]
    @Query private var unpaidLessons: [Lesson]
    @Query private var vetRecords: [VetRecord]
    @Query private var farrierVisits: [FarrierVisit]
    @Query private var dentistVisits: [DentistVisit]
    @Query private var lowStockSupplies: [SupplyItem]

    /// Bumped on every save (any context) and CloudKit import, so the counts, the
    /// all-time balance and the newest care records, which aren't backed by a
    /// `@Query`, refresh too.
    @State private var dataVersion = 0
    @State private var allTimeBalance = AllTimeBalanceCache()
    @State private var newestCare = NewestCareRecordsCache()

    init(window: HomeSummary.Window) {
        _monthTransactions = Query(DashboardQueries.transactions(in: window.month))
        _reminders = Query(DashboardQueries.reminders(before: window.soonEnd))
        _lessons = Query(DashboardQueries.homeLessons(from: window.today, before: window.soonEnd))
        _unpaidLessons = Query(DashboardQueries.unpaidLessons(through: window.anchor, limit: HomeSummary.unpaidLimit))
        _vetRecords = Query(DashboardQueries.vetDue(from: window.today, through: window.dueEnd))
        _farrierVisits = Query(DashboardQueries.farrierDue(from: window.today, through: window.dueEnd))
        _dentistVisits = Query(DashboardQueries.dentistDue(from: window.today, through: window.dueEnd))
        _lowStockSupplies = Query(DashboardQueries.lowStockSupplies)
    }

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

    /// What one render shows, computed once.
    private struct Snapshot {
        let summary: HomeSummary
        let horseCount: Int
        let clientCount: Int
        let displayBalance: Double
    }

    private func makeSnapshot() -> Snapshot {
        let version = dataVersion
        let summary = HomeSummary(HomeSummary.Inputs(
            monthTransactions: monthTransactions,
            reminders: reminders,
            lessons: lessons,
            unpaidLessons: unpaidLessons,
            vetRecords: vetRecords,
            farrierVisits: farrierVisits,
            dentistVisits: dentistVisits,
            lowStock: lowStockSupplies,
            newest: newestCare.value(version: version, context: modelContext)
        ))
        let horseCount = (try? modelContext.fetchCount(FetchDescriptor<Horse>(predicate: #Predicate { $0.isActive }))) ?? 0
        let clientCount = (try? modelContext.fetchCount(FetchDescriptor<Client>(predicate: #Predicate { $0.isActive }))) ?? 0
        let balance = balancePeriod == .thisMonth
            ? summary.month.balance
            : allTimeBalance.balance(version: version, context: modelContext)
        return Snapshot(summary: summary, horseCount: horseCount, clientCount: clientCount, displayBalance: balance)
    }

    var body: some View {
        let snapshot = makeSnapshot()
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
                macDashboard(snapshot)
                #else
                if sizeClass == .regular {
                    iPadDashboard(snapshot)
                } else {
                    if !snapshot.summary.todayReminders.isEmpty {
                        todaySection(reminders: snapshot.summary.todayReminders)
                    }
                    iconGrid(snapshot)
                }
                #endif
            }
        }
        .background(Color.barnOffWhite)
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
            dataVersion &+= 1
        }
        .onChange(of: syncMonitor.lastSuccessfulSync) { dataVersion &+= 1 }
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
                    min(260, max(210, height * 0.32))
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

    private func iconGrid(_ snapshot: Snapshot) -> some View {
        let horseCount = snapshot.horseCount
        let clientCount = snapshot.clientCount
        let stockAlert = snapshot.summary.lowStock.count
        let balance = snapshot.displayBalance

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
            FeatureTile(icon: "calendar", title: "Schedule", color: .barnBrown, badge: snapshot.summary.nextScheduleItemToday, tag: "tile_schedule") {
                router.switchTab(.schedule)
            }
            FeatureTile(icon: "shippingbox.fill", title: "Supplies", color: .barnBrown, badge: stockAlert > 0 ? appLocalized("\(stockAlert) Low", comment: "Home Supplies tile badge: number of supplies at or below their reorder level") : nil, badgeColor: stockAlert > 0 ? .red : nil, tag: "tile_supplies") {
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

    private func macDashboard(_ snapshot: Snapshot) -> some View {
        // No tile grid on the Mac: every tile's destination is already in the
        // sidebar, so the space goes to the dashboard widgets.
        VStack(spacing: 16) {
            statsStrip(snapshot)
            widgetGrid(snapshot.summary)
        }
        .padding(.bottom, 24)
    }

    #if !os(macOS)
    private func iPadDashboard(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 20) {
            statsStrip(snapshot)
            widgetGrid(snapshot.summary)
            iconGrid(snapshot)
        }
        .padding(.bottom, 32)
    }
    #endif

    private func statsStrip(_ snapshot: Snapshot) -> some View {
        let monthlyBalance = snapshot.summary.month.balance
        let lowStockCount = snapshot.summary.lowStock.count
        return HStack(spacing: 12) {
            DashboardStatCard(
                icon: "figure.equestrian.sports",
                title: appLocalized("Horses", comment: "Dashboard stat"),
                value: "\(snapshot.horseCount)",
                accent: .barnBrown
            ) { router.switchTab(.horses) }
            DashboardStatCard(
                icon: "person.2.fill",
                title: appLocalized("Clients", comment: "Dashboard stat"),
                value: "\(snapshot.clientCount)",
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

    private func widgetGrid(_ summary: HomeSummary) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            HomeTodayWidget(summary: summary)
            HomeActionItemsWidget(summary: summary)
            HomeAlertsWidget(summary: summary)
            HomeFinanceWidget(summary: summary)
        }
        .padding(.horizontal, 24)
    }
}
