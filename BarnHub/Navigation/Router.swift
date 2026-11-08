import SwiftUI
import SwiftData

@Observable
final class Router {
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()
    var horsesPath = NavigationPath()
    var clientsPath = NavigationPath()
    var schedulePath = NavigationPath()
    var accountingPath = NavigationPath()

    /// The horse and client selected in the list beside the detail
    /// (`ListDetailSplit`), kept here so the sidebar and deep links can drive it.
    var selectedHorseID: PersistentIdentifier?
    var selectedClientID: PersistentIdentifier?
    /// Whether the Horses / Clients tab is currently showing its list beside the detail.
    var horsesShowSplit = false
    var clientsShowSplit = false

    /// Add/edit forms open as sheets instead of pushing (Mac, and iPad-sized
    /// windows). Set by the root view from the platform and size class.
    var presentsFormsAsSheets = false
    /// The form currently shown as a sheet, if any.
    var presentedForm: PresentedForm?

    struct PresentedForm: Identifiable {
        let id = UUID()
        let route: AnyHashable
    }

    enum AppTab: String, CaseIterable {
        case home, horses, clients, schedule, accounting

        var title: LocalizedStringKey {
            switch self {
            case .home:       "Home"
            case .horses:     "Horses"
            case .clients:    "Clients"
            case .schedule:   "Schedule"
            case .accounting: "Accounting"
            }
        }

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .horses: "figure.equestrian.sports"
            case .clients: "person.2.fill"
            case .schedule: "calendar"
            case .accounting: "dollarsign.circle.fill"
            }
        }

        var keyboardShortcut: KeyEquivalent {
            switch self {
            case .home: "1"
            case .horses: "2"
            case .clients: "3"
            case .schedule: "4"
            case .accounting: "5"
            }
        }
    }

    func navigate(to route: any Hashable, tab: AppTab? = nil) {
        if let tab { selectedTab = tab }
        if presentsFormsAsSheets, Self.isForm(route) {
            presentedForm = PresentedForm(route: AnyHashable(route))
            return
        }
        switch selectedTab {
        case .home: homePath.append(route)
        case .horses: horsesPath.append(route)
        case .clients: clientsPath.append(route)
        case .schedule: schedulePath.append(route)
        case .accounting: accountingPath.append(route)
        }
    }

    /// Shows a horse's detail: selects it in the split when that's showing,
    /// otherwise pushes it onto the Horses stack.
    func showHorse(_ id: PersistentIdentifier) {
        selectedTab = .horses
        if horsesShowSplit {
            popToRoot(tab: .horses)
            selectedHorseID = id
        } else {
            horsesPath.append(HorseRoute.detail(id))
        }
    }

    /// Shows a client's detail: selects it in the split when that's showing,
    /// otherwise pushes it onto the Clients stack.
    func showClient(_ id: PersistentIdentifier) {
        selectedTab = .clients
        if clientsShowSplit {
            popToRoot(tab: .clients)
            selectedClientID = id
        } else {
            clientsPath.append(ClientRoute.detail(id))
        }
    }

    /// Add/edit screens: the routes that open as a sheet when `presentsFormsAsSheets`.
    static func isForm(_ route: any Hashable) -> Bool {
        switch route {
        case let r as HomeRoute: r.isForm
        case let r as HorseRoute: r.isForm
        case let r as ClientRoute: r.isForm
        case let r as AccountingRoute: r.isForm
        case let r as BarnRoute: r.isForm
        case let r as SubscriptionRoute: r.isForm
        default: false
        }
    }

    func switchTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func popToRoot(tab: AppTab? = nil) {
        switch tab ?? selectedTab {
        case .home: homePath = NavigationPath()
        case .horses: horsesPath = NavigationPath()
        case .clients: clientsPath = NavigationPath()
        case .schedule: schedulePath = NavigationPath()
        case .accounting: accountingPath = NavigationPath()
        }
    }
}
