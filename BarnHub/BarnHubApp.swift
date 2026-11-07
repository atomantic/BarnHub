import SwiftUI
import SwiftData
import StoreKit

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
        StorageMode.current = isSeedMode ? .inMemorySeed : .cloudKit
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
                StorageMode.current = .inMemoryFallback
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
        #elseif targetEnvironment(macCatalyst)
        .defaultSize(width: 1024, height: 768)
        #endif
        .commands {
            SidebarCommands()

            CommandMenu("Go") {
                ForEach(Router.AppTab.allCases, id: \.self) { tab in
                    Button {
                        // Match iOS tab-bar semantics: switch preserves the stack;
                        // re-pressing the current tab's shortcut pops to root.
                        if router.selectedTab == tab {
                            router.popToRoot(tab: tab)
                        } else {
                            router.selectedTab = tab
                        }
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .keyboardShortcut(tab.keyboardShortcut, modifiers: .command)
                }
            }

            #if os(macOS)
            CommandGroup(replacing: .appTermination) {
                Button("Quit BarnHub") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            #endif
        }

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
            handleScreenshotRouteFromLaunchArgs()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(isPresented: $showFirstLaunchSheet) {
            FirstLaunchSheet()
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "barnhub", url.host() == "screenshot" {
            let page = url.pathComponents.filter { $0 != "/" }.first ?? ""
            navigateToScreenshotPage(page)
        } else {
            DeepLinkHandler.handle(url: url, router: router)
        }
    }

    private func handleScreenshotRouteFromLaunchArgs() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-screenshotRoute"),
              idx + 1 < args.count else { return }
        navigateToScreenshotPage(args[idx + 1])
    }

    private func navigateToScreenshotPage(_ page: String) {
        // Set the tab synchronously; defer detail-level navigation so
        // SidebarView's own cascade (onChange → handleSelection → popToRoot)
        // doesn't wipe our nav path on first render.
        let tab: Router.AppTab
        switch page {
        case "home": tab = .home
        case "horses", "horseDetail": tab = .horses
        case "clients", "clientDetail": tab = .clients
        case "schedule", "feedProducts", "dentistSchedule", "reminders": tab = .schedule
        case "accounting": tab = .accounting
        default: return
        }
        router.selectedTab = tab
        router.popToRoot(tab: tab)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            switch page {
            case "horseDetail":
                let d = FetchDescriptor<Horse>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.name)])
                if let h = try? modelContext.fetch(d).first {
                    router.navigate(to: HorseRoute.detail(h.persistentModelID), tab: .horses)
                }
            case "clientDetail":
                let d = FetchDescriptor<Client>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.lastName)])
                if let c = try? modelContext.fetch(d).first {
                    router.navigate(to: ClientRoute.detail(c.persistentModelID), tab: .clients)
                }
            case "feedProducts":
                router.navigate(to: BarnRoute.feedProducts, tab: .schedule)
            case "dentistSchedule":
                router.navigate(to: BarnRoute.dentistSchedule, tab: .schedule)
            case "reminders":
                router.navigate(to: BarnRoute.reminders, tab: .schedule)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var sidebarLayout: some View {
        @Bindable var router = router
        NavigationSplitView {
            SidebarView()
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
                case .editVetRecord(let id): VetRecordEditView(horseID: nil, recordID: id)
                case .editFarrierVisit(let id): FarrierVisitEditView(horseID: nil, visitID: id)
                case .editDentistVisit(let id): DentistVisitEditView(horseID: nil, visitID: id)
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

/// Multi-page introductory sheet shown the first time the app is launched.
/// - `welcome`: brand privacy promise (no accounts, iCloud sync, export anytime)
/// - `notification`: primes the iOS notification permission so it never fires cold
/// - `firstHorse`: captures the user's first horse (honest value-delivery)
/// - `hasClients`: routes to Pro offer if the user manages clients
/// - `proOffer`: compact paywall with 7-day trial on subscription plans + lifetime
/// `interactiveDismissDisabled` blocks swipe-to-dismiss so `hasCompletedFirstLaunch`
/// is only set via an explicit button press.
struct FirstLaunchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("net.shadowpuppet.BarnBook.hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false

    private enum Page { case welcome, notification, firstHorse, hasClients, proOffer }
    @State private var page: Page = .welcome

    @State private var horseName = ""
    @State private var horseBreed = ""
    @State private var selectedProduct: Product?
    @State private var toast = ToastState()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    switch page {
                    case .welcome: welcomePage
                    case .notification: notificationPage
                    case .firstHorse: firstHorsePage
                    case .hasClients: hasClientsPage
                    case .proOffer: proOfferPage
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
        .frame(minWidth: 480, minHeight: 620)
        #endif
        .interactiveDismissDisabled(true)
        .toast(toast)
        .task {
            if storeService.products.isEmpty {
                await storeService.loadProducts()
            }
            selectedProduct = storeService.annualProduct ?? storeService.lifetimeProduct ?? storeService.monthlyProduct
        }
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
    private var firstHorsePage: some View {
        Image(systemName: "figure.equestrian.sports")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Meet your first horse"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("Add one now so your barn isn't empty. You can add more — and edit this one — anytime."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appLocalized("Name"))
                    .font(.caption).foregroundStyle(.secondary)
                TextField(appLocalized("e.g. Starfire"), text: $horseName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(appLocalized("Breed (optional)"))
                    .font(.caption).foregroundStyle(.secondary)
                TextField(appLocalized("e.g. Thoroughbred"), text: $horseBreed)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var hasClientsPage: some View {
        Image(systemName: "person.2.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Do you manage clients?"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("If you board horses for others, teach lessons, or invoice clients, BarnHub Pro unlocks the client tools."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "person.crop.circle.badge.checkmark",
                title: appLocalized("Client profiles & horses"),
                detail: appLocalized("Link horses to clients, track contact info, and see everything in one place.")
            )
            privacyBullet(
                icon: "doc.text.fill",
                title: appLocalized("Contracts & invoices"),
                detail: appLocalized("Generate PDFs for boarding agreements and bill clients from your accounting.")
            )
            privacyBullet(
                icon: "chart.bar.fill",
                title: appLocalized("Full reports"),
                detail: appLocalized("Income by client, outstanding balances, and deeper accounting analytics.")
            )
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var proOfferPage: some View {
        Image(systemName: "star.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Try BarnHub Pro free for 7 days"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        VStack(spacing: 6) {
            Text(appLocalized("Full access to clients, contracts, invoices, and reports."))
            Text(appLocalized("Cancel anytime during the trial."))
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

        VStack(spacing: 10) {
            if storeService.products.isEmpty {
                if storeService.productsLoadFailed {
                    Text(appLocalized("Unable to load subscription plans"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(appLocalized("Try Again")) {
                        Task { await storeService.loadProducts() }
                    }
                    .foregroundStyle(.barnGreen)
                } else {
                    ProgressView().padding(.vertical, 16)
                }
            } else {
                if let monthly = storeService.monthlyProduct {
                    planCard(product: monthly, title: appLocalized("Monthly"),
                             subtitle: monthly.displayPrice + appLocalized("/month"),
                             badge: monthly.subscription?.introductoryOffer != nil ? appLocalized("7-day free trial") : nil)
                }
                if let annual = storeService.annualProduct {
                    planCard(product: annual, title: appLocalized("Annual"),
                             subtitle: annual.displayPrice + appLocalized("/year"),
                             badge: annual.subscription?.introductoryOffer != nil ? appLocalized("7-day free trial") : appLocalized("Best value"))
                }
                if let lifetime = storeService.lifetimeProduct {
                    planCard(product: lifetime, title: appLocalized("Lifetime"),
                             subtitle: lifetime.displayPrice + appLocalized(" once"),
                             badge: appLocalized("One-time purchase"))
                }
            }
        }
        .padding(.top, 8)

        Text(appLocalized("Auto-renews unless cancelled. Manage in App Store settings."))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func planCard(product: Product, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id
        Button { selectedProduct = product } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .barnGreen : .secondary)
                    .font(.title3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.barnGreen : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            Divider()

            switch page {
            case .welcome:
                primaryButton(appLocalized("Continue")) {
                    withAnimation(.easeInOut(duration: 0.25)) { page = .notification }
                }

            case .notification:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Turn on reminders")) {
                        Task {
                            await notificationService.requestAuthorization()
                            withAnimation(.easeInOut(duration: 0.25)) { page = .firstHorse }
                        }
                    }
                    Button(appLocalized("Not now")) {
                        withAnimation(.easeInOut(duration: 0.25)) { page = .firstHorse }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .firstHorse:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Add Horse")) {
                        addHorseIfNamed()
                        withAnimation(.easeInOut(duration: 0.25)) { page = .hasClients }
                    }
                    .disabled(horseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(appLocalized("Skip")) {
                        withAnimation(.easeInOut(duration: 0.25)) { page = .hasClients }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .hasClients:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Yes, I manage clients")) {
                        if storeService.isPro {
                            complete()
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) { page = .proOffer }
                        }
                    }
                    Button(appLocalized("No, just my own horses")) {
                        complete()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .proOffer:
                VStack(spacing: 8) {
                    primaryButton(purchaseLabel) {
                        Task { await handlePurchase() }
                    }
                    .disabled(selectedProduct == nil || storeService.purchaseInProgress)
                    Button(appLocalized("Maybe later")) {
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

    private var purchaseLabel: String {
        if storeService.purchaseInProgress { return appLocalized("Starting…") }
        guard let product = selectedProduct else { return appLocalized("Start 7-day Free Trial") }
        if product.id == StoreService.lifetimeID { return appLocalized("Buy Lifetime") }
        if product.subscription?.introductoryOffer != nil { return appLocalized("Start 7-day Free Trial") }
        return appLocalized("Subscribe")
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if storeService.purchaseInProgress && page == .proOffer {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.barnGreen)
        .padding(.horizontal, page == .welcome ? 24 : 0)
    }

    private func addHorseIfNamed() {
        let trimmedName = horseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let horse = Horse(
            name: trimmedName,
            breed: horseBreed.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(horse)
        BarnHubLogger.success("First horse added during onboarding: \(trimmedName)")
    }

    @MainActor
    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        let success = await storeService.purchase(product)
        if success {
            toast.show(appLocalized("Welcome to BarnHub Pro!"))
            try? await Task.sleep(for: .seconds(1))
            complete()
        } else if !storeService.purchaseInProgress {
            toast.show(appLocalized("Purchase didn't complete"), isError: true)
        }
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
