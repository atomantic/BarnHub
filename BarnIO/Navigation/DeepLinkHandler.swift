import Foundation

struct DeepLinkHandler {
    static func handle(url: URL, router: Router) {
        guard url.scheme == "barnio" else { return }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "horses":
            router.popToRoot(tab: .horses)
            router.switchTab(.horses)

        case "clients":
            router.popToRoot(tab: .clients)
            router.switchTab(.clients)

        case "accounting":
            router.popToRoot(tab: .accounting)
            router.switchTab(.accounting)

        case "barn", "schedule":
            router.popToRoot(tab: .schedule)
            router.switchTab(.schedule)

            if let first = pathComponents.first {
                switch first {
                case "supplies":
                    router.navigate(to: BarnRoute.supplies, tab: .schedule)
                case "reminders":
                    router.navigate(to: BarnRoute.reminders, tab: .schedule)
                default:
                    break
                }
            }

        case "supplies":
            router.popToRoot(tab: .home)
            router.switchTab(.home)
            router.navigate(to: HomeRoute.supplies, tab: .home)

        case "reports":
            router.popToRoot(tab: .home)
            router.switchTab(.home)
            router.navigate(to: HomeRoute.reports, tab: .home)

        default:
            BarnIOLogger.warning("Unhandled deep link host=\(host)")
        }
    }
}
