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
    @State private var selectionSync = SidebarSelectionSync()

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
            selectionSync.userSelectionChanged(to: new, router: router)
        }
        .onAppear {
            // Initialize selection from router state when view first appears
            if let synced = selectionSync.syncFromRouter(tab: router.selectedTab, current: selection) {
                selection = synced
            }
        }
        .onChange(of: router.selectedHorseID) { _, id in
            // Follow the selection in the Horses list column, if the horse has a row.
            guard router.selectedTab == .horses, router.horsesShowSplit, let id,
                  activeHorses.contains(where: { $0.persistentModelID == id }),
                  let synced = selectionSync.syncItem(.horse(id), current: selection) else { return }
            selection = synced
        }
        .onChange(of: router.selectedClientID) { _, id in
            guard router.selectedTab == .clients, router.clientsShowSplit, let id,
                  activeClients.contains(where: { $0.persistentModelID == id }),
                  let synced = selectionSync.syncItem(.client(id), current: selection) else { return }
            selection = synced
        }
        .onChange(of: router.selectedTab) { _, new in
            // Sync sidebar when tab changes externally (e.g., deep link, Cmd-1..5)
            if let synced = selectionSync.syncFromRouter(tab: new, current: selection) {
                selection = synced
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
}

// MARK: - Selection Handling

extension SidebarSelection {
    var tab: Router.AppTab {
        switch self {
        case .home: return .home
        case .horses, .horse: return .horses
        case .clients, .client: return .clients
        case .schedule, .schedulePage: return .schedule
        case .accounting: return .accounting
        }
    }

    init(tab: Router.AppTab) {
        switch tab {
        case .home: self = .home
        case .horses: self = .horses
        case .clients: self = .clients
        case .schedule: self = .schedule
        case .accounting: self = .accounting
        }
    }

    /// Applies a user-initiated sidebar selection: tapping a sidebar row resets
    /// that tab's stack and pushes the row's destination, if any.
    func apply(to router: Router) {
        router.selectedTab = tab
        switch self {
        case .home, .accounting:
            break
        case .horses, .clients, .schedule:
            router.popToRoot(tab: tab)
        case .horse(let id):
            if !router.horsesShowSplit { router.popToRoot(tab: .horses) }
            router.showHorse(id)
        case .client(let id):
            if !router.clientsShowSplit { router.popToRoot(tab: .clients) }
            router.showClient(id)
        case .schedulePage(let sub):
            router.popToRoot(tab: .schedule)
            router.navigate(to: sub.barnRoute, tab: .schedule)
        }
    }
}

/// Keeps the sidebar's selection in step with `Router.selectedTab` without
/// treating router-driven changes (keyboard shortcuts, deep links) as user taps.
/// A synced selection only highlights the row; it must not pop the tab's stack.
struct SidebarSelectionSync {
    private(set) var pendingSync: SidebarSelection?

    /// Returns the selection the sidebar should show for an external tab change,
    /// or nil to leave it as is. A selection already inside `tab` (including a
    /// sub-item such as a specific horse) is kept so it isn't clobbered.
    mutating func syncFromRouter(tab: Router.AppTab, current: SidebarSelection?) -> SidebarSelection? {
        guard current?.tab != tab else { return nil }
        let target = SidebarSelection(tab: tab)
        pendingSync = target
        return target
    }

    /// Returns the sidebar row to highlight for an item picked in the list beside
    /// the detail, or nil if it's already highlighted. Like `syncFromRouter`, the
    /// resulting selection change is not treated as a tap.
    mutating func syncItem(_ target: SidebarSelection, current: SidebarSelection?) -> SidebarSelection? {
        guard current != target else { return nil }
        pendingSync = target
        return target
    }

    /// Handles a change of the sidebar's selection binding. Changes made by
    /// `syncFromRouter` are swallowed; anything else is a user tap.
    mutating func userSelectionChanged(to new: SidebarSelection, router: Router) {
        if let pending = pendingSync {
            pendingSync = nil
            if pending == new { return }
        }
        new.apply(to: router)
    }
}
