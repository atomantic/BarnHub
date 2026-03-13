import SwiftUI
import SwiftData

@Observable
final class Router {
    var selectedTab: AppTab = .horses
    var horsesPath = NavigationPath()
    var clientsPath = NavigationPath()
    var accountingPath = NavigationPath()
    var barnPath = NavigationPath()

    enum AppTab: String, CaseIterable {
        case horses, clients, accounting, barn
    }

    func navigate(to route: any Hashable, tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .horses: horsesPath.append(route)
        case .clients: clientsPath.append(route)
        case .accounting: accountingPath.append(route)
        case .barn: barnPath.append(route)
        }
    }

    func popToRoot(tab: AppTab) {
        switch tab {
        case .horses: horsesPath = NavigationPath()
        case .clients: clientsPath = NavigationPath()
        case .accounting: accountingPath = NavigationPath()
        case .barn: barnPath = NavigationPath()
        }
    }
}
