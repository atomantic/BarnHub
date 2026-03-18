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

        // Pop one tab, others unaffected
        router.popToRoot(tab: .clients)
        XCTAssertTrue(router.clientsPath.isEmpty)
        XCTAssertEqual(router.horsesPath.count, 1)
        XCTAssertEqual(router.accountingPath.count, 1)
        XCTAssertEqual(router.schedulePath.count, 1)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testMultipleNavigationsAccumulate() {
        let router = Router()
        router.switchTab(.horses)
        router.navigate(to: HorseRoute.list)
        router.navigate(to: HorseRoute.list)
        router.navigate(to: HorseRoute.list)
        XCTAssertEqual(router.horsesPath.count, 3)
    }
}
