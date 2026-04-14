import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService

    @Query(filter: #Predicate<Horse> { $0.isActive }, sort: \Horse.name)
    private var activeHorses: [Horse]

    @Query(filter: #Predicate<Client> { $0.isActive }, sort: \Client.lastName)
    private var activeClients: [Client]

    @AppStorage("net.shadowpuppet.BarnBook.sidebar.horsesExpanded") private var horsesExpanded = true
    @AppStorage("net.shadowpuppet.BarnBook.sidebar.clientsExpanded") private var clientsExpanded = true
    @AppStorage("net.shadowpuppet.BarnBook.sidebar.scheduleExpanded") private var scheduleExpanded = true

    private var isPro: Bool { storeService.isPro }

    var body: some View {
        List(selection: sidebarSelection) {
            Label(Router.AppTab.home.title, systemImage: Router.AppTab.home.icon)
                .tag(Router.AppTab.home)
                .accessibilityIdentifier("sidebar_home")

            DisclosureGroup(isExpanded: $horsesExpanded) {
                ForEach(activeHorses, id: \.persistentModelID) { horse in
                    Button {
                        goToHorse(horse)
                    } label: {
                        horseRow(horse)
                    }
                    .buttonStyle(.plain)
                }
            } label: {
                Label(Router.AppTab.horses.title, systemImage: Router.AppTab.horses.icon)
                    .tag(Router.AppTab.horses)
                    .accessibilityIdentifier("sidebar_horses")
            }

            if isPro {
                DisclosureGroup(isExpanded: $clientsExpanded) {
                    ForEach(activeClients, id: \.persistentModelID) { client in
                        Button {
                            goToClient(client)
                        } label: {
                            clientRow(client)
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon)
                        .tag(Router.AppTab.clients)
                        .accessibilityIdentifier("sidebar_clients")
                }
            } else {
                Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon)
                    .tag(Router.AppTab.clients)
                    .accessibilityIdentifier("sidebar_clients")
            }

            DisclosureGroup(isExpanded: $scheduleExpanded) {
                scheduleSubItem("Reminders", icon: "bell.fill", route: .reminders)
                scheduleSubItem("Vet Schedule", icon: "stethoscope", route: .vetSchedule)
                scheduleSubItem("Farrier Schedule", icon: "hammer.fill", route: .farrierSchedule)
                scheduleSubItem("Dentist Schedule", icon: "mouth.fill", route: .dentistSchedule)
                scheduleSubItem("Lessons", icon: "book.fill", route: .lessons)
                scheduleSubItem("Supplies", icon: "shippingbox.fill", route: .supplies)
                scheduleSubItem("Barn Notes", icon: "note.text", route: .barnNotes)
                scheduleSubItem("Feed Products", icon: "leaf.fill", route: .feedProducts)
            } label: {
                Label(Router.AppTab.schedule.title, systemImage: Router.AppTab.schedule.icon)
                    .tag(Router.AppTab.schedule)
                    .accessibilityIdentifier("sidebar_schedule")
            }

            Label(Router.AppTab.accounting.title, systemImage: Router.AppTab.accounting.icon)
                .tag(Router.AppTab.accounting)
                .accessibilityIdentifier("sidebar_accounting")
        }
        .navigationTitle("BarnHub")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
    }

    // MARK: - Sub-item Rows

    private func horseRow(_ horse: Horse) -> some View {
        HStack(spacing: 8) {
            if let data = horse.photoData, let image = Image(photoData: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            } else {
                Image(systemName: "figure.equestrian.sports")
                    .font(.caption)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.barnGreen)
                    .background(Circle().fill(Color.barnGreen.opacity(0.15)))
            }
            Text(horse.name)
                .lineLimit(1)
        }
    }

    private func clientRow(_ client: Client) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.barnGreen)
                .frame(width: 22, height: 22)
            Text(client.fullName)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func scheduleSubItem(_ title: LocalizedStringKey, icon: String, route: BarnRoute) -> some View {
        Button {
            goToScheduleRoute(route)
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func goToHorse(_ horse: Horse) {
        router.selectedTab = .horses
        router.popToRoot(tab: .horses)
        router.navigate(to: HorseRoute.detail(horse.persistentModelID), tab: .horses)
    }

    private func goToClient(_ client: Client) {
        router.selectedTab = .clients
        router.popToRoot(tab: .clients)
        router.navigate(to: ClientRoute.detail(client.persistentModelID), tab: .clients)
    }

    private func goToScheduleRoute(_ route: BarnRoute) {
        router.selectedTab = .schedule
        router.popToRoot(tab: .schedule)
        router.navigate(to: route, tab: .schedule)
    }

    private var sidebarSelection: Binding<Router.AppTab?> {
        Binding(
            get: { router.selectedTab },
            set: { if let tab = $0 { router.selectedTab = tab } }
        )
    }
}
