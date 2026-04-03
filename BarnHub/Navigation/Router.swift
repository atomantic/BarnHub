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

    enum AppTab: String, CaseIterable {
        case home, horses, clients, schedule, accounting

        var title: LocalizedStringKey {
            switch self {
            case .home: "Home"
            case .horses: "Horses"
            case .clients: "Clients"
            case .schedule: "Schedule"
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
    }

    func navigate(to route: any Hashable, tab: AppTab? = nil) {
        if let tab { selectedTab = tab }
        switch selectedTab {
        case .home: homePath.append(route)
        case .horses: horsesPath.append(route)
        case .clients: clientsPath.append(route)
        case .schedule: schedulePath.append(route)
        case .accounting: accountingPath.append(route)
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
