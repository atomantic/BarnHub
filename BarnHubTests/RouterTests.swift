import XCTest
import SwiftData
@testable import BarnHub

final class RouterTests: XCTestCase {

    func testNavigateAppendsRouteToCorrectTab() {
        let router = Router()
        router.selectedTab = .horses
        router.navigate(to: HorseRoute.list)

        XCTAssertFalse(router.horsesPath.isEmpty)
        XCTAssertEqual(router.horsesPath.count, 1)
        // Other tabs remain empty
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.clientsPath.isEmpty)
        XCTAssertTrue(router.schedulePath.isEmpty)
        XCTAssertTrue(router.accountingPath.isEmpty)
    }

    func testNavigateWithTabSwitchesAndAppends() {
        let router = Router()
        router.selectedTab = .home
        router.navigate(to: ClientRoute.list, tab: .clients)

        XCTAssertEqual(router.selectedTab, .clients)
        XCTAssertEqual(router.clientsPath.count, 1)
        XCTAssertTrue(router.homePath.isEmpty)
    }

    func testSwitchTabUpdatesSelectedTab() {
        let router = Router()
        XCTAssertEqual(router.selectedTab, .home)

        for tab in Router.AppTab.allCases {
            router.switchTab(tab)
            XCTAssertEqual(router.selectedTab, tab)
        }
    }

    func testPopToRootResetsCorrectPath() {
        let router = Router()
        router.navigate(to: HorseRoute.list, tab: .horses)
        router.navigate(to: AccountingRoute.list, tab: .accounting)

        XCTAssertEqual(router.horsesPath.count, 1)
        XCTAssertEqual(router.accountingPath.count, 1)

        router.popToRoot(tab: .horses)
        XCTAssertTrue(router.horsesPath.isEmpty)
        // Accounting path should be untouched
        XCTAssertEqual(router.accountingPath.count, 1)
    }

    func testPopToRootUsesCurrentTabWhenNilProvided() {
        let router = Router()
        router.switchTab(.schedule)
        router.navigate(to: BarnRoute.supplies)
        XCTAssertEqual(router.schedulePath.count, 1)

        router.popToRoot()
        XCTAssertTrue(router.schedulePath.isEmpty)
    }

    func testTabPathIsolation() {
        let router = Router()

        router.navigate(to: HorseRoute.list, tab: .horses)
        router.navigate(to: ClientRoute.list, tab: .clients)
        router.navigate(to: AccountingRoute.list, tab: .accounting)
        router.navigate(to: BarnRoute.supplies, tab: .schedule)
        router.navigate(to: HomeRoute.reports, tab: .home)

        XCTAssertEqual(router.horsesPath.count, 1)
        XCTAssertEqual(router.clientsPath.count, 1)
        XCTAssertEqual(router.accountingPath.count, 1)
        XCTAssertEqual(router.schedulePath.count, 1)
        XCTAssertEqual(router.homePath.count, 1)

        // Verify selectedTab matches the last explicit tab argument used
        XCTAssertEqual(router.selectedTab, .home)

        // Pop one tab, verify correct tab is now active and others untouched
        router.popToRoot(tab: .clients)
        XCTAssertTrue(router.clientsPath.isEmpty)
        XCTAssertEqual(router.horsesPath.count, 1)
        XCTAssertEqual(router.accountingPath.count, 1)
        XCTAssertEqual(router.schedulePath.count, 1)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testNavigate_setsSelectedTabToSpecifiedTab() {
        let router = Router()
        router.selectedTab = .home
        router.navigate(to: HorseRoute.list, tab: .horses)
        XCTAssertEqual(router.selectedTab, .horses)
    }

    func testNavigate_withoutTabArgument_usesCurrentTab() {
        let router = Router()
        router.selectedTab = .accounting
        router.navigate(to: AccountingRoute.list)
        XCTAssertEqual(router.selectedTab, .accounting)
        XCTAssertEqual(router.accountingPath.count, 1)
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.horsesPath.isEmpty)
    }

    func testMultipleNavigationsAccumulate() {
        let router = Router()
        router.switchTab(.horses)
        router.navigate(to: HorseRoute.list)
        router.navigate(to: HorseRoute.list)
        router.navigate(to: HorseRoute.list)
        XCTAssertEqual(router.horsesPath.count, 3)
    }

    func testTabKeyboardShortcuts_areUniqueAndSequential() {
        let shortcuts = Router.AppTab.allCases.map(\.keyboardShortcut.character)
        XCTAssertEqual(shortcuts, ["1", "2", "3", "4", "5"], "Tabs should map to Cmd-1..5 in declaration order")
        XCTAssertEqual(Set(shortcuts).count, shortcuts.count, "Each tab must have a unique keyboard shortcut")
    }

    // MARK: - Sidebar selection sync

    /// Simulates SidebarView: an external tab change syncs the selection, and the
    /// resulting binding change is fed back through `userSelectionChanged`.
    private func syncSidebar(_ sync: inout SidebarSelectionSync, selection: inout SidebarSelection?, to tab: Router.AppTab, router: Router) {
        router.selectedTab = tab
        if let synced = sync.syncFromRouter(tab: tab, current: selection) {
            selection = synced
            sync.userSelectionChanged(to: synced, router: router)
        }
    }

    func testSidebarSync_switchingAwayAndBackPreservesTabStack() {
        let router = Router()
        var sync = SidebarSelectionSync()
        var selection: SidebarSelection? = .horses
        SidebarSelection.horses.apply(to: router)
        router.navigate(to: HorseRoute.list, tab: .horses)
        XCTAssertEqual(router.horsesPath.count, 1)

        syncSidebar(&sync, selection: &selection, to: .home, router: router)
        XCTAssertEqual(selection, .home)
        syncSidebar(&sync, selection: &selection, to: .horses, router: router)

        XCTAssertEqual(selection, .horses)
        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertEqual(router.horsesPath.count, 1, "Returning via keyboard shortcut must not pop the stack")
        XCTAssertNil(sync.pendingSync)
    }

    func testSidebarSync_keepsSubItemSelectionWithinSameTab() {
        var sync = SidebarSelectionSync()
        let current = SidebarSelection.schedulePage(.lessons)
        XCTAssertNil(sync.syncFromRouter(tab: .schedule, current: current))
        XCTAssertEqual(sync.syncFromRouter(tab: .home, current: current), .home)
    }

    func testSidebarUserTapOnTopLevelRowPopsToRoot() {
        let router = Router()
        var sync = SidebarSelectionSync()
        router.navigate(to: HorseRoute.list, tab: .horses)

        sync.userSelectionChanged(to: .horses, router: router)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertTrue(router.horsesPath.isEmpty, "A user tap on a top-level row resets that tab")
    }

    func testSidebarUserTapAfterSyncIsNotSwallowed() {
        let router = Router()
        var sync = SidebarSelectionSync()
        router.navigate(to: HorseRoute.list, tab: .horses)
        _ = sync.syncFromRouter(tab: .home, current: .horses)

        // The binding change for the sync was coalesced away; the next change is a real tap.
        sync.userSelectionChanged(to: .horses, router: router)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertTrue(router.horsesPath.isEmpty)
        XCTAssertNil(sync.pendingSync)
    }

    // MARK: - List beside detail

    private func makeHorseID() throws -> (ModelContainer, PersistentIdentifier) {
        let container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let horse = Horse()
        horse.name = "Arrow"
        context.insert(horse)
        try context.save()
        return (container, horse.persistentModelID)
    }

    func testShowHorse_withSplit_selectsInsteadOfPushing() throws {
        let (container, id) = try makeHorseID()
        defer { _ = container }
        let router = Router()
        router.horsesShowSplit = true
        router.navigate(to: HorseRoute.list, tab: .horses)

        router.showHorse(id)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertEqual(router.selectedHorseID, id)
        XCTAssertTrue(router.horsesPath.isEmpty, "The split shows the detail, so nothing is pushed")
    }

    func testShowHorse_withoutSplit_pushesDetail() throws {
        let (container, id) = try makeHorseID()
        defer { _ = container }
        let router = Router()

        router.showHorse(id)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertEqual(router.horsesPath.count, 1)
        XCTAssertNil(router.selectedHorseID)
    }

    func testSidebarSync_itemPickedInListIsNotTreatedAsTap() throws {
        let (container, id) = try makeHorseID()
        defer { _ = container }
        let router = Router()
        router.horsesShowSplit = true
        router.selectedTab = .horses
        router.navigate(to: HorseRoute.list, tab: .horses)
        var sync = SidebarSelectionSync()

        let synced = sync.syncItem(.horse(id), current: .horses)
        XCTAssertEqual(synced, .horse(id))
        sync.userSelectionChanged(to: .horse(id), router: router)

        XCTAssertEqual(router.horsesPath.count, 1, "Highlighting the row must not pop the stack")
        XCTAssertNil(sync.syncItem(.horse(id), current: .horse(id)))
    }

    // MARK: - Form sheets

    func testNavigate_formRoute_presentsSheetWhenEnabled() {
        let router = Router()
        router.presentsFormsAsSheets = true

        router.navigate(to: HorseRoute.edit(nil), tab: .horses)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertTrue(router.horsesPath.isEmpty, "A form opens as a sheet instead of pushing")
        XCTAssertEqual(router.presentedForm?.route, AnyHashable(HorseRoute.edit(nil)))
    }

    func testNavigate_formRoute_pushesWhenSheetsDisabled() {
        let router = Router()

        router.navigate(to: AccountingRoute.edit(nil), tab: .accounting)

        XCTAssertEqual(router.accountingPath.count, 1)
        XCTAssertNil(router.presentedForm)
    }

    func testNavigate_nonFormRoute_stillPushesWhenSheetsEnabled() {
        let router = Router()
        router.presentsFormsAsSheets = true

        router.navigate(to: BarnRoute.supplies, tab: .schedule)

        XCTAssertEqual(router.schedulePath.count, 1)
        XCTAssertNil(router.presentedForm)
    }

    func testIsForm_coversAddAndEditRoutesOnly() {
        XCTAssertTrue(Router.isForm(HorseRoute.edit(nil)))
        XCTAssertTrue(Router.isForm(ClientRoute.edit(nil)))
        XCTAssertTrue(Router.isForm(BarnRoute.supplyEdit(nil)))
        XCTAssertTrue(Router.isForm(BarnRoute.addVetRecord))
        XCTAssertFalse(Router.isForm(HorseRoute.list))
        XCTAssertFalse(Router.isForm(ClientRoute.list))
        XCTAssertFalse(Router.isForm(HomeRoute.settings))
    }
}

// MARK: - Every route

/// One value of every case of every route enum, built from a single record ID.
/// Each list is checked against an exhaustive switch, so adding a route case
/// fails to compile until it's listed here too.
enum AllRoutes {
    static func home() -> [HomeRoute] {
        let all: [HomeRoute] = [.horses, .clients, .schedule, .supplies, .accounting,
                                .reports, .barnNotes, .settings, .dataManagement]
        for route in all {
            switch route {
            case .horses, .clients, .schedule, .supplies, .accounting, .reports,
                 .barnNotes, .settings, .dataManagement: break
            }
        }
        return all
    }

    static func horse(_ id: PersistentIdentifier) -> [HorseRoute] {
        let all: [HorseRoute] = [
            .list, .detail(id), .edit(id), .edit(nil), .addVetRecord(id), .addFarrierVisit(id),
            .addDentistVisit(id), .editVetRecord(id), .editFarrierVisit(id), .editDentistVisit(id),
            .healthTimeline(id), .weightChart(id), .documents(id), .feedPlan(id),
            .editFeedEntry(id, nil), .editFeedEntry(id, id),
        ]
        for route in all {
            switch route {
            case .list, .detail, .edit, .addVetRecord, .addFarrierVisit, .addDentistVisit,
                 .editVetRecord, .editFarrierVisit, .editDentistVisit, .healthTimeline,
                 .weightChart, .documents, .feedPlan, .editFeedEntry: break
            }
        }
        return all
    }

    static func client(_ id: PersistentIdentifier) -> [ClientRoute] {
        let all: [ClientRoute] = [.list, .detail(id), .edit(id), .edit(nil), .manageHorses(id),
                                  .invoiceHistory(id), .paymentHistory(id), .documents(id)]
        for route in all {
            switch route {
            case .list, .detail, .edit, .manageHorses, .invoiceHistory, .paymentHistory, .documents: break
            }
        }
        return all
    }

    static func accounting(_ id: PersistentIdentifier) -> [AccountingRoute] {
        let all: [AccountingRoute] = [.list, .edit(id), .edit(nil)]
        for route in all {
            switch route {
            case .list, .edit: break
            }
        }
        return all
    }

    static func subscription() -> [SubscriptionRoute] {
        let all: [SubscriptionRoute] = [.paywall]
        for route in all {
            switch route {
            case .paywall: break
            }
        }
        return all
    }

    static func barn(_ id: PersistentIdentifier) -> [BarnRoute] {
        let all: [BarnRoute] = [
            .supplies, .supplyEdit(id), .supplyEdit(nil), .reminders, .reminderEdit(id),
            .reminderEdit(nil), .barnNotes, .barnNoteEdit(id), .barnNoteEdit(nil),
            .vetSchedule, .addVetRecord, .farrierSchedule, .addFarrierVisit,
            .dentistSchedule, .addDentistVisit, .lessons, .lessonEdit(id), .lessonEdit(nil),
            .feedProducts, .feedProductEdit(id), .feedProductEdit(nil),
        ]
        for route in all {
            switch route {
            case .supplies, .supplyEdit, .reminders, .reminderEdit, .barnNotes, .barnNoteEdit,
                 .vetSchedule, .addVetRecord, .farrierSchedule, .addFarrierVisit,
                 .dentistSchedule, .addDentistVisit, .lessons, .lessonEdit,
                 .feedProducts, .feedProductEdit: break
            }
        }
        return all
    }

    static func all(_ id: PersistentIdentifier) -> [any Hashable] {
        home() + horse(id) + client(id) + accounting(id) + subscription() + barn(id)
    }
}

final class RouteFormTests: XCTestCase {
    private var container: ModelContainer!
    private var id: PersistentIdentifier!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let horse = Horse(name: "Arrow")
        context.insert(horse)
        try context.save()
        id = horse.persistentModelID
    }

    override func tearDown() {
        container = nil
        id = nil
        super.tearDown()
    }

    /// The add/edit screens, spelled out by name so a route can't silently
    /// become (or stop being) a form.
    private func expectedForm(_ route: any Hashable) -> Bool {
        switch route {
        case let r as HorseRoute:
            switch r {
            case .edit, .addVetRecord, .addFarrierVisit, .addDentistVisit,
                 .editVetRecord, .editFarrierVisit, .editDentistVisit: return true
            default: return false  // .editFeedEntry opens in the feed plan's own sheet
            }
        case let r as ClientRoute:
            if case .edit = r { return true }
            return false
        case let r as AccountingRoute:
            if case .edit = r { return true }
            return false
        case let r as BarnRoute:
            switch r {
            case .supplyEdit, .reminderEdit, .barnNoteEdit, .lessonEdit, .feedProductEdit,
                 .addVetRecord, .addFarrierVisit, .addDentistVisit: return true
            default: return false
            }
        default:
            return false
        }
    }

    func test_isForm_matchesEveryAddAndEditRoute() {
        let routes = AllRoutes.all(id)
        XCTAssertEqual(routes.count, 9 + 16 + 8 + 3 + 1 + 21)
        for route in routes {
            XCTAssertEqual(Router.isForm(route), expectedForm(route), "isForm wrong for \(route)")
        }
    }

    func test_isForm_unknownRouteType_isNotForm() {
        XCTAssertFalse(Router.isForm("not a route"))
    }

    func test_navigate_presentsEveryFormAsSheet_andPushesTheRest() {
        for route in AllRoutes.all(id) {
            let router = Router()
            router.presentsFormsAsSheets = true
            router.navigate(to: route, tab: .home)
            if Router.isForm(route) {
                XCTAssertEqual(router.presentedForm?.route, AnyHashable(route), "\(route)")
                XCTAssertTrue(router.homePath.isEmpty, "\(route) should not push")
            } else {
                XCTAssertNil(router.presentedForm, "\(route)")
                XCTAssertEqual(router.homePath.count, 1, "\(route) should push")
            }
        }
    }

    func test_navigate_pushesFormsWhenNotPresentingSheets() {
        for route in AllRoutes.all(id) where Router.isForm(route) {
            let router = Router()
            router.navigate(to: route, tab: .schedule)
            XCTAssertNil(router.presentedForm)
            XCTAssertEqual(router.schedulePath.count, 1, "\(route)")
        }
    }
}
