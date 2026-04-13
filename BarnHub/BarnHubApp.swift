import SwiftUI
import SwiftData

#if os(macOS)
@MainActor
final class BarnHubMacAppDelegate: NSObject, NSApplicationDelegate {
    static var reopenWindow: (() -> Void)?

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            DispatchQueue.main.async { Self.showOrCreateMainWindow() }
        }
        return true
    }

    static func showOrCreateMainWindow() {
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        reopenWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif

@main
struct BarnHubApp: App {
    @State private var router = Router()
    @State private var storeService = StoreService()
    @State private var appearanceManager = AppearanceManager()
    @State private var notificationService = NotificationService()
    @State private var syncMonitor = SyncMonitor()
    @AppStorage("net.shadowpuppet.BarnBook.appLocale") private var appLocaleID: String = ""

    private var appLocale: Locale {
        appLocaleID.isEmpty ? .current : Locale(identifier: appLocaleID)
    }

    #if os(macOS)
    @NSApplicationDelegateAdaptor(BarnHubMacAppDelegate.self) private var appDelegate
    #endif

    private var modelContainer: ModelContainer = {
        let isSeedMode = ProcessInfo.processInfo.arguments.contains("-SeedSampleData")
        let config = isSeedMode
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            let container = try ModelContainer(
                for: Horse.self, Client.self, Transaction.self,
                VetRecord.self, FarrierVisit.self, DentistVisit.self, SupplyItem.self, Reminder.self,
                Invoice.self, WeightEntry.self, ClientDocument.self, HorseDocument.self, FeedProduct.self, FeedPlanEntry.self, BarnNote.self, Lesson.self,
                configurations: config
            )
            #if DEBUG
            if isSeedMode {
                PreviewSampleData.populate(container: container)
            }
            #endif
            return container
        } catch {
            BarnHubLogger.error("ModelContainer init failed: \(error.localizedDescription) — falling back to in-memory store")
            do {
                let fallback = try ModelContainer(
                    for: Horse.self, Client.self, Transaction.self,
                    VetRecord.self, FarrierVisit.self, DentistVisit.self, SupplyItem.self, Reminder.self,
                    Invoice.self, WeightEntry.self, ClientDocument.self, HorseDocument.self, FeedProduct.self, FeedPlanEntry.self, BarnNote.self, Lesson.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                return fallback
            } catch {
                BarnHubLogger.error("Fallback in-memory ModelContainer init also failed: \(error.localizedDescription)")
                fatalError("Unable to initialize SwiftData ModelContainer (both persistent and in-memory initializations failed).")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
                .environment(\.locale, appLocale)
                .environment(router)
                .environment(storeService)
                .environment(appearanceManager)
                .environment(notificationService)
                .environment(syncMonitor)
                .onOpenURL { url in
                    DeepLinkHandler.handle(url: url, router: router)
                }
                .task {
                    // Refresh status only — never request cold. The actual permission
                    // request happens after the user opts in via FirstLaunchSheet.
                    await notificationService.refreshAuthorizationStatus()
                }
                #if os(macOS)
                .onAppear {
                    BarnHubMacAppDelegate.reopenWindow = nil
                }
                #endif
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit BarnHub") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        #elseif targetEnvironment(macCatalyst)
        .defaultSize(width: 1024, height: 768)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(storeService)
                .environment(appearanceManager)
                .environment(syncMonitor)
                .modelContainer(modelContainer)
        }
        #endif
    }
}

struct ContentView: View {
    @Environment(Router.self) private var router
    @Environment(SyncMonitor.self) private var syncMonitor
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("net.shadowpuppet.BarnBook.hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false
    @State private var showFirstLaunchSheet = false

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]
    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]
    @Query(sort: \DentistVisit.date, order: .reverse) private var dentistVisits: [DentistVisit]

    var body: some View {
        @Bindable var router = router
        Group {
            #if os(macOS)
            sidebarLayout
            #else
            if sizeClass == .regular {
                sidebarLayout
            } else {
                tabBarLayout
            }
            #endif
        }
        .task {
            if !hasCompletedFirstLaunch {
                showFirstLaunchSheet = true
            }
            notificationService.scheduleAllPending(context: modelContext)
            let overdueRems = incompleteReminders.filter { $0.dueDate.isOverdue }.count
            let overdueVet = vetRecords.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }.count
            let overdueFarrier = farrierVisits.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }.count
            let overdueDentist = dentistVisits.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }.count
            let overdueCount = overdueRems + overdueVet + overdueFarrier + overdueDentist
            let todayCount = incompleteReminders.filter { Calendar.current.isDateInToday($0.dueDate) }.count
            notificationService.scheduleMorningSummary(overdueCount: overdueCount, todayCount: todayCount)
        }
        .sheet(isPresented: $showFirstLaunchSheet) {
            FirstLaunchSheet()
        }
    }

    @ViewBuilder
    private var sidebarLayout: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(Router.AppTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                        .accessibilityIdentifier("sidebar_\(tab.rawValue)")
                }
            }
            .navigationTitle("BarnHub")
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sidebarFooter
            }
        } detail: {
            sidebarDetailView
                .id(router.selectedTab)
        }
        .tint(.barnGreen)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                SyncIndicatorView()
                Text(syncMonitor.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    router.navigate(to: HomeRoute.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLocalized("Settings"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    #if os(iOS)
    @ViewBuilder
    private var tabBarLayout: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .withRouteDestinations()
            }
            .withNavControls(router: router)
            .tabItem { Label(Router.AppTab.home.title, systemImage: Router.AppTab.home.icon) }
            .tag(Router.AppTab.home)

            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
            }
            .withNavControls(router: router)
            .tabItem { Label(Router.AppTab.horses.title, systemImage: Router.AppTab.horses.icon) }
            .tag(Router.AppTab.horses)

            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
            }
            .withNavControls(router: router)
            .tabItem { Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon) }
            .tag(Router.AppTab.clients)

            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
            }
            .withNavControls(router: router)
            .tabItem { Label(Router.AppTab.schedule.title, systemImage: Router.AppTab.schedule.icon) }
            .tag(Router.AppTab.schedule)

            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
            }
            .withNavControls(router: router)
            .tabItem { Label(Router.AppTab.accounting.title, systemImage: Router.AppTab.accounting.icon) }
            .tag(Router.AppTab.accounting)
        }
        .tint(.barnGreen)
    }
    #endif

    private var sidebarSelection: Binding<Router.AppTab?> {
        Binding(
            get: { router.selectedTab },
            set: { if let tab = $0 { router.selectedTab = tab } }
        )
    }

    @ViewBuilder
    private var sidebarDetailView: some View {
        @Bindable var router = router
        switch router.selectedTab {
        case .home:
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .withRouteDestinations()
            }
        case .horses:
            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
            }
        case .clients:
            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
            }
        case .schedule:
            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
            }
        case .accounting:
            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
            }
        }
    }
}

private extension View {
    #if os(iOS)
    func withNavControls(router: Router) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                SyncIndicatorView()
                Button {
                    router.navigate(to: HomeRoute.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(appLocalized("Settings"))
            }
        }
    }
    #endif

    func withRouteDestinations() -> some View {
        self
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .horses: HorseListView()
                case .clients: ClientListView()
                case .schedule: BarnDashboardView()
                case .supplies: SupplyListView()
                case .accounting: AccountingDashboardView()
                case .reports: ReportsView()
                case .barnNotes: BarnNoteListView()
                case .settings: SettingsView()
                case .dataManagement: DataManagementView()
                }
            }
            .navigationDestination(for: HorseRoute.self) { route in
                switch route {
                case .list: HorseListView()
                case .detail(let id): HorseDetailView(horseID: id)
                case .edit(let id): HorseEditView(horseID: id)
                case .addVetRecord(let id): VetRecordEditView(horseID: id)
                case .addFarrierVisit(let id): FarrierVisitEditView(horseID: id)
                case .addDentistVisit(let id): DentistVisitEditView(horseID: id)
                case .healthTimeline(let id): HealthTimelineView(horseID: id)
                case .weightChart(let id): WeightChartView(horseID: id)
                case .documents(let id): HorseDocumentsView(horseID: id)
                case .feedPlan(let id): HorseFeedPlanView(horseID: id)
                case .editFeedEntry(let horseID, let entryID): FeedPlanEntryEditView(horseID: horseID, entryID: entryID)
                }
            }
            .navigationDestination(for: ClientRoute.self) { route in
                switch route {
                case .list: ClientListView()
                case .detail(let id): ClientDetailView(clientID: id)
                case .edit(let id): ClientEditView(clientID: id)
                case .manageHorses(let id): ClientHorsesView(clientID: id)
                case .invoiceHistory(let id): InvoiceHistoryView(clientID: id)
                case .paymentHistory(let id): ClientPaymentHistoryView(clientID: id)
                case .documents(let id): ClientDocumentsView(clientID: id)
                }
            }
            .navigationDestination(for: AccountingRoute.self) { route in
                switch route {
                case .list: TransactionListView()
                case .edit(let id): TransactionEditView(transactionID: id)
                }
            }
            .navigationDestination(for: BarnRoute.self) { route in
                switch route {
                case .supplies: SupplyListView()
                case .supplyEdit(let id): SupplyEditView(supplyItemID: id)
                case .reminders: ReminderListView()
                case .reminderEdit(let id): ReminderEditView(reminderID: id)
                case .barnNotes: BarnNoteListView()
                case .barnNoteEdit(let id): BarnNoteEditView(noteID: id)
                case .vetSchedule: VetScheduleView()
                case .addVetRecord: VetRecordEditView(horseID: nil)
                case .farrierSchedule: FarrierScheduleView()
                case .addFarrierVisit: FarrierVisitEditView(horseID: nil)
                case .dentistSchedule: DentistScheduleView()
                case .addDentistVisit: DentistVisitEditView(horseID: nil)
                case .lessons: LessonListView()
                case .lessonEdit(let id): LessonEditView(lessonID: id)
                case .feedProducts: FeedProductListView()
                case .feedProductEdit(let id): FeedProductEditView(productID: id)
                }
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .paywall: PaywallView()
                }
            }
    }
}

// MARK: - First Launch Sheet

/// Two-page introductory sheet shown the first time the app is launched.
/// Page 1 surfaces the privacy promise (no accounts, iCloud sync, export anytime).
/// Page 2 primes the notification permission so the iOS dialog never fires cold.
/// Both pages can be skipped, but the user must dismiss the sheet explicitly via
/// one of the buttons — `interactiveDismissDisabled` blocks swipe-to-dismiss to
/// guarantee `hasCompletedFirstLaunch` is set before the sheet goes away.
struct FirstLaunchSheet: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("net.shadowpuppet.BarnBook.hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false

    private enum Page { case welcome, notification }
    @State private var page: Page = .welcome

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    switch page {
                    case .welcome: welcomePage
                    case .notification: notificationPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            footer
        }
        .background(Color.systemBackground)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 580)
        #endif
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private var welcomePage: some View {
        Image(systemName: "house.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Welcome to BarnHub"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("Your barn, in your pocket — and your iCloud."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "lock.shield.fill",
                title: appLocalized("Private by design"),
                detail: appLocalized("No accounts, no servers, no telemetry. Your horse and client data is yours alone.")
            )
            privacyBullet(
                icon: "icloud.fill",
                title: appLocalized("Synced through your iCloud"),
                detail: appLocalized("Encrypted by Apple and shared only with your other Apple devices — your iPhone, iPad, and Mac stay in sync automatically.")
            )
            privacyBullet(
                icon: "square.and.arrow.up",
                title: appLocalized("Export anytime"),
                detail: appLocalized("Take your data with you. It never leaves your devices unless you explicitly share it.")
            )
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var notificationPage: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Stay on top of the barn"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("BarnHub can quietly remind you about what's coming up."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "stethoscope",
                title: appLocalized("Vet, farrier & dentist visits"),
                detail: appLocalized("Get a heads-up before each scheduled appointment so nothing slips.")
            )
            privacyBullet(
                icon: "checklist",
                title: appLocalized("Reminders & lessons"),
                detail: appLocalized("A small nudge for the day's chores, lessons, and overdue tasks.")
            )
            privacyBullet(
                icon: "lock.fill",
                title: appLocalized("Stays on your device"),
                detail: appLocalized("Reminders are scheduled by iOS itself. Nothing leaves your device.")
            )
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            Divider()

            switch page {
            case .welcome:
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { page = .notification }
                } label: {
                    Text(appLocalized("Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.barnGreen)
                .padding(.horizontal, 24)

            case .notification:
                VStack(spacing: 8) {
                    Button {
                        Task {
                            await notificationService.requestAuthorization()
                            complete()
                        }
                    } label: {
                        Text(appLocalized("Turn on reminders"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.barnGreen)

                    Button(appLocalized("Not now")) {
                        complete()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func privacyBullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.barnGreen)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func complete() {
        hasCompletedFirstLaunch = true
        dismiss()
    }
}
