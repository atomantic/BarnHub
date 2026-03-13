import SwiftUI
import SwiftData

@main
struct BarnBookApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .onOpenURL { url in
                    DeepLinkHandler.handle(url: url, router: router)
                }
        }
        .modelContainer(for: [
            Horse.self,
            Client.self,
            Transaction.self,
            VetRecord.self,
            FarrierVisit.self,
            SupplyItem.self,
            Reminder.self
        ], isAutosaveEnabled: true)
    }
}

struct ContentView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .navigationDestination(for: HorseRoute.self) { route in
                        switch route {
                        case .list: HorseListView()
                        case .detail(let id): HorseDetailView(horseID: id)
                        case .edit(let id): HorseEditView(horseID: id)
                        case .addVetRecord(let id): VetRecordEditView(horseID: id)
                        case .addFarrierVisit(let id): FarrierVisitEditView(horseID: id)
                        }
                    }
            }
            .tabItem { Label("Horses", systemImage: "hare") }
            .tag(Router.AppTab.horses)

            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .navigationDestination(for: ClientRoute.self) { route in
                        switch route {
                        case .list: ClientListView()
                        case .detail(let id): ClientDetailView(clientID: id)
                        case .edit(let id): ClientEditView(clientID: id)
                        case .manageHorses(let id): ClientHorsesView(clientID: id)
                        }
                    }
            }
            .tabItem { Label("Clients", systemImage: "person.2") }
            .tag(Router.AppTab.clients)

            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .navigationDestination(for: AccountingRoute.self) { route in
                        switch route {
                        case .list: TransactionListView()
                        case .edit(let id): TransactionEditView(transactionID: id)
                        }
                    }
            }
            .tabItem { Label("Accounting", systemImage: "dollarsign.circle") }
            .tag(Router.AppTab.accounting)

            NavigationStack(path: $router.barnPath) {
                BarnDashboardView()
                    .navigationDestination(for: BarnRoute.self) { route in
                        switch route {
                        case .supplies: SupplyListView()
                        case .supplyEdit(let id): SupplyEditView(supplyItemID: id)
                        case .reminders: ReminderListView()
                        case .reminderEdit(let id): ReminderEditView(reminderID: id)
                        case .vetSchedule: VetScheduleView()
                        case .farrierSchedule: FarrierScheduleView()
                        }
                    }
            }
            .tabItem { Label("Barn", systemImage: "house") }
            .tag(Router.AppTab.barn)
        }
    }
}
