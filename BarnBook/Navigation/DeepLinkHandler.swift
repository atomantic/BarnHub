import Foundation

struct DeepLinkHandler {
    static func handle(url: URL, router: Router) {
        guard url.scheme == "barnbook" else { return }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "horses":
            router.popToRoot(tab: .horses)
            router.selectedTab = .horses

        case "clients":
            router.popToRoot(tab: .clients)
            router.selectedTab = .clients

        case "accounting":
            router.popToRoot(tab: .accounting)
            router.selectedTab = .accounting

        case "barn":
            router.popToRoot(tab: .barn)
            router.selectedTab = .barn

            if let first = pathComponents.first {
                switch first {
                case "supplies":
                    router.navigate(to: BarnRoute.supplies, tab: .barn)
                case "reminders":
                    router.navigate(to: BarnRoute.reminders, tab: .barn)
                default:
                    break
                }
            }

        default:
            BarnBookLogger.warning("Unhandled deep link host=\(host)")
        }
    }
}
