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
                VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
                Invoice.self, WeightEntry.self, ClientDocument.self, BarnNote.self, Lesson.self,
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
                    VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
                    Invoice.self, WeightEntry.self, ClientDocument.self, BarnNote.self, Lesson.self,
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
                .environment(router)
                .environment(storeService)
                .environment(appearanceManager)
                .environment(notificationService)
                .environment(syncMonitor)
                .onOpenURL { url in
                    DeepLinkHandler.handle(url: url, router: router)
                }
                .task {
                    await notificationService.requestAuthorization()
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
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]
    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]

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
            notificationService.scheduleAllPending(context: modelContext)
            let overdueRems = incompleteReminders.filter { $0.dueDate.isOverdue }.count
            let overdueVet = vetRecords.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }.count
            let overdueFarrier = farrierVisits.filter { ($0.nextDueDate ?? .distantFuture).isOverdue }.count
            let overdueCount = overdueRems + overdueVet + overdueFarrier
            let todayCount = incompleteReminders.filter { Calendar.current.isDateInToday($0.dueDate) }.count
            notificationService.scheduleMorningSummary(overdueCount: overdueCount, todayCount: todayCount)
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
                }
            }
            .navigationTitle("BarnHub")
            .listStyle(.sidebar)
        } detail: {
            sidebarDetailView
                .id(router.selectedTab)
        }
        .tint(.barnGreen)
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
            .tabItem { Label(Router.AppTab.home.title, systemImage: Router.AppTab.home.icon) }
            .tag(Router.AppTab.home)

            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
            }
            .tabItem { Label(Router.AppTab.horses.title, systemImage: Router.AppTab.horses.icon) }
            .tag(Router.AppTab.horses)

            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
            }
            .tabItem { Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon) }
            .tag(Router.AppTab.clients)

            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
            }
            .tabItem { Label(Router.AppTab.schedule.title, systemImage: Router.AppTab.schedule.icon) }
            .tag(Router.AppTab.schedule)

            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
            }
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
                case .healthTimeline(let id): HealthTimelineView(horseID: id)
                case .weightChart(let id): WeightChartView(horseID: id)
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
                case .lessons: LessonListView()
                case .lessonEdit(let id): LessonEditView(lessonID: id)
                }
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .paywall: PaywallView()
                }
            }
    }
}
