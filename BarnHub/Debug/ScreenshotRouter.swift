import SwiftUI
import SwiftData

// MARK: Screenshot routes (debug builds only)

// Drive navigation for the screenshot UI tests and scripts. Release builds
// leave these out so no other app or web page can steer navigation.
#if DEBUG
/// Handles `-screenshotRoute <page>` and `barnhub://screenshot/<page>` for
/// `ContentView`.
@MainActor
struct ScreenshotRouter {
    let router: Router
    let modelContext: ModelContext
    #if os(macOS)
    let openSettings: OpenSettingsAction
    #endif

    func handleLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-screenshotRoute"),
              idx + 1 < args.count else { return }
        navigate(to: args[idx + 1])
    }

    func navigate(to page: String) {
        // Set the tab synchronously; defer detail-level navigation until the
        // layout (tab bar or sidebar) has rendered its first frame.
        let tab: Router.AppTab
        switch page {
        case "home", "reports", "supplies", "settings": tab = .home
        case "horses", "horseDetail", "addHorse": tab = .horses
        case "clients", "clientDetail": tab = .clients
        case "schedule", "feedProducts", "dentistSchedule", "reminders": tab = .schedule
        case "accounting", "transactions": tab = .accounting
        default: return
        }
        router.selectedTab = tab
        router.popToRoot(tab: tab)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            switch page {
            case "horseDetail":
                let d = FetchDescriptor<Horse>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.name)])
                if let h = try? modelContext.fetch(d).first {
                    router.showHorse(h.persistentModelID)
                }
            case "clientDetail":
                let d = FetchDescriptor<Client>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.lastName)])
                if let c = try? modelContext.fetch(d).first {
                    router.showClient(c.persistentModelID)
                }
            case "reports":
                router.navigate(to: HomeRoute.reports, tab: .home)
            case "supplies":
                router.navigate(to: HomeRoute.supplies, tab: .home)
            case "settings":
                // The Mac has a Settings window; pick its tab with
                // -net.shadowpuppet.BarnBook.settings.tab general|subscription|data|feedback
                #if os(macOS)
                openSettings()
                #else
                router.navigate(to: HomeRoute.settings, tab: .home)
                #endif
            case "transactions":
                router.navigate(to: AccountingRoute.list, tab: .accounting)
            case "addHorse":
                router.navigate(to: HorseRoute.edit(nil), tab: .horses)
            case "feedProducts":
                router.navigate(to: BarnRoute.feedProducts, tab: .schedule)
            case "dentistSchedule":
                router.navigate(to: BarnRoute.dentistSchedule, tab: .schedule)
            case "reminders":
                router.navigate(to: BarnRoute.reminders, tab: .schedule)
            default:
                break
            }
        }
    }
}
#endif
