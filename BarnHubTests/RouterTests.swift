import XCTest
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
}
