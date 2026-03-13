import Foundation

struct DeepLinkHandler {
    static func handle(url: URL, router: Router) {
        guard url.scheme == "barnbook" else { return }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        router.popToRoot()

        switch host {
        case "horses":
            router.navigate(to: HomeRoute.horses)

        case "clients":
            router.navigate(to: HomeRoute.clients)

        case "accounting":
            router.navigate(to: HomeRoute.accounting)

        case "barn", "schedule":
            router.navigate(to: HomeRoute.schedule)

            if let first = pathComponents.first {
                switch first {
                case "supplies":
                    router.navigate(to: BarnRoute.supplies)
                case "reminders":
                    router.navigate(to: BarnRoute.reminders)
                default:
                    break
                }
            }

        case "supplies":
            router.navigate(to: HomeRoute.supplies)

        case "reports":
            router.navigate(to: HomeRoute.reports)

        default:
            BarnBookLogger.warning("Unhandled deep link host=\(host)")
        }
    }
}
