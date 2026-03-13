import SwiftUI
import SwiftData

@Observable
final class Router {
    var path = NavigationPath()

    func navigate(to route: any Hashable) {
        path.append(route)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
