import SwiftUI
import SwiftData

// MARK: Screenshot routes (debug builds only)

// Drive navigation for the screenshot and screen-walk UI tests and scripts.
// Release builds leave these out so no other app or web page can steer navigation.
#if DEBUG
/// Handles `-screenshotRoute <page>` and `barnhub://screenshot/<page>` for
/// `ContentView`. Every route in `Routes.swift` has a page here, opened on the
/// first matching sample record, so `ScreenWalkTests` can open each screen
/// directly. Keep the page names in step with `ScreenWalkTests.pages`.
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
        guard let (tab, open) = entry(for: page) else {
            BarnHubLogger.warning("Unknown screenshot route")
            return
        }
        // Set the tab synchronously; defer detail-level navigation until the
        // layout (tab bar or sidebar) has rendered its first frame.
        let apply = {
            router.selectedTab = tab
            router.popToRoot(tab: tab)
        }
        apply()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            let unopened = state
            open()
            guard page != "settings" else { return }
            // On a busy simulator, especially right after a UI test relaunches
            // the app, the first frames can drop the push or put the tab back
            // to Home. Watch for a few seconds and reapply the route if it
            // never took (nothing changed) or its tab, stack, sheet or
            // selection was undone. Tab-only pages change nothing, so they
            // only check the tab.
            let opensScreen = unopened != state
            var expected = state
            for _ in 0..<8 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let dropped = !opensScreen && entryOpensScreen(page) && state == unopened
                guard state != expected || dropped else { continue }
                BarnHubLogger.warning("Screenshot route was undone; reapplying")
                apply()
                try? await Task.sleep(nanoseconds: 300_000_000)
                open()
                expected = state
            }
        }
    }

    /// Whether the page opens something beyond its tab's root screen.
    private func entryOpensScreen(_ page: String) -> Bool {
        !["home", "horses", "clients", "schedule", "accounting"].contains(page)
    }

    /// What a route sets: the tab, the stacks, the form sheet and the split selections.
    private struct NavigationState: Equatable {
        let tab: Router.AppTab
        let pathCounts: [Int]
        let formID: UUID?
        let horseID: PersistentIdentifier?
        let clientID: PersistentIdentifier?
    }

    private var state: NavigationState {
        NavigationState(
            tab: router.selectedTab,
            pathCounts: [router.homePath.count, router.horsesPath.count, router.clientsPath.count,
                         router.schedulePath.count, router.accountingPath.count],
            formID: router.presentedForm?.id,
            horseID: router.selectedHorseID,
            clientID: router.selectedClientID
        )
    }

    private typealias Page = (tab: Router.AppTab, open: () -> Void)

    private func entry(for name: String) -> Page? {
        switch name {
        // Tabs
        case "home": return (.home, {})
        case "horses": return (.horses, {})
        case "clients": return (.clients, {})
        case "schedule": return (.schedule, {})
        case "accounting": return (.accounting, {})

        // Home
        case "reports": return push(HomeRoute.reports, on: .home)
        case "supplies": return push(HomeRoute.supplies, on: .home)
        case "homeBarnNotes": return push(HomeRoute.barnNotes, on: .home)
        case "dataManagement": return push(HomeRoute.dataManagement, on: .home)
        case "paywall": return push(SubscriptionRoute.paywall, on: .home)
        case "settings":
            // The Mac has a Settings window; pick its tab with
            // -net.shadowpuppet.BarnBook.settings.tab general|subscription|data|feedback
            #if os(macOS)
            return (.home, { openSettings() })
            #else
            return push(HomeRoute.settings, on: .home)
            #endif

        // Horses (the first active horse by name: Arrow)
        case "horseDetail": return (.horses, { if let id = horse?.persistentModelID { router.showHorse(id) } })
        case "addHorse": return push(HorseRoute.edit(nil), on: .horses)
        case "editHorse": return horseRoute { .edit($0.persistentModelID) }
        case "addVetRecord": return horseRoute { .addVetRecord($0.persistentModelID) }
        case "addFarrierVisit": return horseRoute { .addFarrierVisit($0.persistentModelID) }
        case "addDentistVisit": return horseRoute { .addDentistVisit($0.persistentModelID) }
        case "editVetRecord":
            return pushLatest(VetRecord.self, sort: \.date, on: .horses) { HorseRoute.editVetRecord($0) }
        case "editFarrierVisit":
            return pushLatest(FarrierVisit.self, sort: \.date, on: .horses) { HorseRoute.editFarrierVisit($0) }
        case "editDentistVisit":
            return pushLatest(DentistVisit.self, sort: \.date, on: .horses) { HorseRoute.editDentistVisit($0) }
        case "healthTimeline": return horseRoute { .healthTimeline($0.persistentModelID) }
        case "weightChart": return horseRoute { .weightChart($0.persistentModelID) }
        case "horseDocuments": return horseRoute { .documents($0.persistentModelID) }
        case "feedPlan": return horseRoute { .feedPlan($0.persistentModelID) }
        case "addFeedEntry": return horseRoute { .editFeedEntry($0.persistentModelID, nil) }
        case "editFeedEntry":
            return horseRoute { horse in
                let entry = (horse.feedPlanEntries ?? []).first { $0.product?.name == "Sweet Feed" }
                return .editFeedEntry(horse.persistentModelID, entry?.persistentModelID)
            }

        // Clients (the first active client by last name: Sarah Chen)
        case "clientDetail": return (.clients, { if let id = client?.persistentModelID { router.showClient(id) } })
        case "addClient": return push(ClientRoute.edit(nil), on: .clients)
        case "editClient": return clientRoute { .edit($0) }
        case "manageHorses": return clientRoute { .manageHorses($0) }
        case "invoiceHistory": return clientRoute { .invoiceHistory($0) }
        case "paymentHistory": return clientRoute { .paymentHistory($0) }
        case "clientDocuments": return clientRoute { .documents($0) }

        // Accounting
        case "transactions": return push(AccountingRoute.list, on: .accounting)
        case "addTransaction": return push(AccountingRoute.edit(nil), on: .accounting)
        case "editTransaction":
            return pushLatest(Transaction.self, sort: \.date, on: .accounting) { AccountingRoute.edit($0) }

        // Schedule
        case "barnSupplies": return push(BarnRoute.supplies, on: .schedule)
        case "addSupply": return push(BarnRoute.supplyEdit(nil), on: .schedule)
        case "editSupply":
            return pushFirst(SupplyItem.self, sort: \.name, on: .schedule) { BarnRoute.supplyEdit($0) }
        case "reminders": return push(BarnRoute.reminders, on: .schedule)
        case "addReminder": return push(BarnRoute.reminderEdit(nil), on: .schedule)
        case "editReminder":
            return pushFirst(Reminder.self, sort: \.title, on: .schedule) { BarnRoute.reminderEdit($0) }
        case "barnNotes": return push(BarnRoute.barnNotes, on: .schedule)
        case "addBarnNote": return push(BarnRoute.barnNoteEdit(nil), on: .schedule)
        case "editBarnNote":
            return pushLatest(BarnNote.self, sort: \.date, on: .schedule) { BarnRoute.barnNoteEdit($0) }
        case "vetSchedule": return push(BarnRoute.vetSchedule, on: .schedule)
        case "scheduleVet": return push(BarnRoute.addVetRecord, on: .schedule)
        case "farrierSchedule": return push(BarnRoute.farrierSchedule, on: .schedule)
        case "scheduleFarrier": return push(BarnRoute.addFarrierVisit, on: .schedule)
        case "dentistSchedule": return push(BarnRoute.dentistSchedule, on: .schedule)
        case "scheduleDentist": return push(BarnRoute.addDentistVisit, on: .schedule)
        case "lessons": return push(BarnRoute.lessons, on: .schedule)
        case "addLesson": return push(BarnRoute.lessonEdit(nil), on: .schedule)
        case "editLesson":
            return pushLatest(Lesson.self, sort: \.date, on: .schedule) { BarnRoute.lessonEdit($0) }
        case "feedProducts": return push(BarnRoute.feedProducts, on: .schedule)
        case "addFeedProduct": return push(BarnRoute.feedProductEdit(nil), on: .schedule)
        case "editFeedProduct":
            return pushFirst(FeedProduct.self, sort: \.name, on: .schedule) { BarnRoute.feedProductEdit($0) }

        default: return nil
        }
    }

    // MARK: Helpers

    private var horse: Horse? {
        let d = FetchDescriptor<Horse>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.name)])
        return try? modelContext.fetch(d).first
    }

    private var client: Client? {
        let d = FetchDescriptor<Client>(predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.lastName)])
        return try? modelContext.fetch(d).first
    }

    private func push(_ route: any Hashable, on tab: Router.AppTab) -> Page {
        (tab, { router.navigate(to: route, tab: tab) })
    }

    private func horseRoute(_ route: @escaping (Horse) -> HorseRoute) -> Page {
        (.horses, { if let horse { router.navigate(to: route(horse), tab: .horses) } })
    }

    private func clientRoute(_ route: @escaping (PersistentIdentifier) -> ClientRoute) -> Page {
        (.clients, { if let id = client?.persistentModelID { router.navigate(to: route(id), tab: .clients) } })
    }

    /// Opens the route for the most recent record of a type.
    private func pushLatest<T: PersistentModel>(
        _ type: T.Type, sort: KeyPath<T, Date>, on tab: Router.AppTab,
        _ route: @escaping (PersistentIdentifier) -> any Hashable
    ) -> Page {
        (tab, {
            var d = FetchDescriptor<T>(sortBy: [SortDescriptor(sort, order: .reverse)])
            d.fetchLimit = 1
            if let id = (try? modelContext.fetch(d))?.first?.persistentModelID {
                router.navigate(to: route(id), tab: tab)
            }
        })
    }

    /// Opens the route for the first record of a type, sorted by name or title.
    private func pushFirst<T: PersistentModel>(
        _ type: T.Type, sort: KeyPath<T, String>, on tab: Router.AppTab,
        _ route: @escaping (PersistentIdentifier) -> any Hashable
    ) -> Page {
        (tab, {
            var d = FetchDescriptor<T>(sortBy: [SortDescriptor(sort)])
            d.fetchLimit = 1
            if let id = (try? modelContext.fetch(d))?.first?.persistentModelID {
                router.navigate(to: route(id), tab: tab)
            }
        })
    }
}
#endif
