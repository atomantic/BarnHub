import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case home
    case horses
    case horse(PersistentIdentifier)
    case clients
    case client(PersistentIdentifier)
    case schedule
    case schedulePage(ScheduleSubpage)
    case accounting

    enum ScheduleSubpage: String, Hashable, CaseIterable {
        case reminders, vetSchedule, farrierSchedule, dentistSchedule, lessons, supplies, barnNotes, feedProducts

        var barnRoute: BarnRoute {
            switch self {
            case .reminders: return .reminders
            case .vetSchedule: return .vetSchedule
            case .farrierSchedule: return .farrierSchedule
            case .dentistSchedule: return .dentistSchedule
            case .lessons: return .lessons
            case .supplies: return .supplies
            case .barnNotes: return .barnNotes
            case .feedProducts: return .feedProducts
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .reminders: return "Reminders"
            case .vetSchedule: return "Vet Schedule"
            case .farrierSchedule: return "Farrier Schedule"
            case .dentistSchedule: return "Dentist Schedule"
            case .lessons: return "Lessons"
            case .supplies: return "Supplies"
            case .barnNotes: return "Barn Notes"
            case .feedProducts: return "Feed Products"
            }
        }

        var icon: String {
            switch self {
            case .reminders: return "bell.fill"
            case .vetSchedule: return "stethoscope"
            case .farrierSchedule: return "hammer.fill"
            case .dentistSchedule: return "mouth.fill"
            case .lessons: return "book.fill"
            case .supplies: return "shippingbox.fill"
            case .barnNotes: return "note.text"
            case .feedProducts: return "leaf.fill"
            }
        }
    }
}

struct SidebarView: View {
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService

    @Query(filter: #Predicate<Horse> { $0.isActive }, sort: \Horse.name)
    private var activeHorses: [Horse]

    @Query(filter: #Predicate<Client> { $0.isActive }, sort: \Client.lastName)
    private var activeClients: [Client]

    @State private var selection: SidebarSelection? = .home

    @AppStorage("net.shadowpuppet.BarnBook.sidebar.horsesExpanded") private var horsesExpanded = true
    @AppStorage("net.shadowpuppet.BarnBook.sidebar.clientsExpanded") private var clientsExpanded = true
    @AppStorage("net.shadowpuppet.BarnBook.sidebar.scheduleExpanded") private var scheduleExpanded = true

    private var isPro: Bool { storeService.isPro }

    var body: some View {
        List(selection: $selection) {
            Label(Router.AppTab.home.title, systemImage: Router.AppTab.home.icon)
                .tag(SidebarSelection.home)
                .accessibilityIdentifier("sidebar_home")

            DisclosureGroup(isExpanded: $horsesExpanded) {
                ForEach(activeHorses, id: \.persistentModelID) { horse in
                    horseRow(horse)
                        .tag(SidebarSelection.horse(horse.persistentModelID))
                }
            } label: {
                Label(Router.AppTab.horses.title, systemImage: Router.AppTab.horses.icon)
                    .tag(SidebarSelection.horses)
                    .accessibilityIdentifier("sidebar_horses")
            }

            if isPro {
                DisclosureGroup(isExpanded: $clientsExpanded) {
                    ForEach(activeClients, id: \.persistentModelID) { client in
                        clientRow(client)
                            .tag(SidebarSelection.client(client.persistentModelID))
                    }
                } label: {
                    Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon)
                        .tag(SidebarSelection.clients)
                        .accessibilityIdentifier("sidebar_clients")
                }
            } else {
                Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon)
                    .tag(SidebarSelection.clients)
                    .accessibilityIdentifier("sidebar_clients")
            }

            DisclosureGroup(isExpanded: $scheduleExpanded) {
                ForEach(SidebarSelection.ScheduleSubpage.allCases, id: \.self) { sub in
                    Label(sub.title, systemImage: sub.icon)
                        .font(.subheadline)
                        .tag(SidebarSelection.schedulePage(sub))
                }
            } label: {
                Label(Router.AppTab.schedule.title, systemImage: Router.AppTab.schedule.icon)
                    .tag(SidebarSelection.schedule)
                    .accessibilityIdentifier("sidebar_schedule")
            }

            Label(Router.AppTab.accounting.title, systemImage: Router.AppTab.accounting.icon)
                .tag(SidebarSelection.accounting)
                .accessibilityIdentifier("sidebar_accounting")
        }
        .navigationTitle("BarnHub")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        .onChange(of: selection) { _, new in
            guard let new else { return }
            handleSelection(new)
        }
        .onAppear {
            // Initialize selection from router state when view first appears
            if selection == .home, router.selectedTab != .home {
                selection = initialSelection(for: router.selectedTab)
            }
        }
        .onChange(of: router.selectedTab) { _, new in
            // Sync sidebar when tab changes externally (e.g., deep link, tab bar)
            // Only if current selection is a top-level tab — don't clobber sub-item selection
            if isTabSelection(selection) {
                selection = initialSelection(for: new)
            }
        }
    }

    // MARK: - Row Views

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

    // MARK: - Selection Handling

    private func handleSelection(_ new: SidebarSelection) {
        switch new {
        case .home:
            router.selectedTab = .home
        case .horses:
            router.selectedTab = .horses
            router.popToRoot(tab: .horses)
        case .horse(let id):
            router.selectedTab = .horses
            router.popToRoot(tab: .horses)
            router.navigate(to: HorseRoute.detail(id), tab: .horses)
        case .clients:
            router.selectedTab = .clients
            router.popToRoot(tab: .clients)
        case .client(let id):
            router.selectedTab = .clients
            router.popToRoot(tab: .clients)
            router.navigate(to: ClientRoute.detail(id), tab: .clients)
        case .schedule:
            router.selectedTab = .schedule
            router.popToRoot(tab: .schedule)
        case .schedulePage(let sub):
            router.selectedTab = .schedule
            router.popToRoot(tab: .schedule)
            router.navigate(to: sub.barnRoute, tab: .schedule)
        case .accounting:
            router.selectedTab = .accounting
        }
    }

    private func initialSelection(for tab: Router.AppTab) -> SidebarSelection {
        switch tab {
        case .home: return .home
        case .horses: return .horses
        case .clients: return .clients
        case .schedule: return .schedule
        case .accounting: return .accounting
        }
    }

    private func isTabSelection(_ sel: SidebarSelection?) -> Bool {
        switch sel {
        case .home, .horses, .clients, .schedule, .accounting: return true
        default: return false
        }
    }
}
