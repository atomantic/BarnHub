import SwiftUI
import SwiftData

@main
struct BarnHubApp: App {
    @State private var router = Router()
    @State private var storeService = StoreService()
    @State private var appearanceManager = AppearanceManager()

    private var modelContainer: ModelContainer = {
        let isSeedMode = ProcessInfo.processInfo.arguments.contains("-SeedSampleData")
        let config = isSeedMode
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration()
        let container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            configurations: config
        )
        #if DEBUG
        if isSeedMode {
            PreviewSampleData.populate(container: container)
        }
        #endif
        return container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
                .environment(router)
                .environment(storeService)
                .environment(appearanceManager)
                .onOpenURL { url in
                    DeepLinkHandler.handle(url: url, router: router)
                }
        }
        .modelContainer(modelContainer)
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1024, height: 768)
        #endif
    }
}

struct ContentView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .withRouteDestinations()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Router.AppTab.home)

            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
            }
            .tabItem { Label("Horses", systemImage: "figure.equestrian.sports") }
            .tag(Router.AppTab.horses)

            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
            }
            .tabItem { Label("Clients", systemImage: "person.2.fill") }
            .tag(Router.AppTab.clients)

            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
            }
            .tabItem { Label("Schedule", systemImage: "calendar") }
            .tag(Router.AppTab.schedule)

            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
            }
            .tabItem { Label("Accounting", systemImage: "dollarsign.circle.fill") }
            .tag(Router.AppTab.accounting)
        }
        .tint(.barnGreen)
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
                }
            }
            .navigationDestination(for: ClientRoute.self) { route in
                switch route {
                case .list: ClientListView()
                case .detail(let id): ClientDetailView(clientID: id)
                case .edit(let id): ClientEditView(clientID: id)
                case .manageHorses(let id): ClientHorsesView(clientID: id)
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
                case .vetSchedule: VetScheduleView()
                case .addVetRecord: VetRecordEditView(horseID: nil)
                case .farrierSchedule: FarrierScheduleView()
                case .addFarrierVisit: FarrierVisitEditView(horseID: nil)
                }
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .paywall: PaywallView()
                }
            }
    }
}
