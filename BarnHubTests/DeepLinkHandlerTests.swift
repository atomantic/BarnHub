import XCTest
@testable import BarnHub

final class DeepLinkHandlerTests: XCTestCase {

    func testHorsesDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://horses")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .horses)
        XCTAssertTrue(router.horsesPath.isEmpty)
    }

    func testClientsDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://clients")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .clients)
        XCTAssertTrue(router.clientsPath.isEmpty)
    }

    func testAccountingDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://accounting")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .accounting)
        XCTAssertTrue(router.accountingPath.isEmpty)
    }

    func testScheduleDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://schedule")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .schedule)
    }

    func testBarnDeepLinkMapsToScheduleTab() {
        let router = Router()
        let url = URL(string: "barnio://barn")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .schedule)
    }

    func testSuppliesDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://supplies")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testReportsDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://reports")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testBarnSuppliesPathComponent() {
        let router = Router()
        let url = URL(string: "barnio://barn/supplies")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .schedule)
        XCTAssertEqual(router.schedulePath.count, 1)
    }

    func testBarnRemindersPathComponent() {
        let router = Router()
        let url = URL(string: "barnio://barn/reminders")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .schedule)
        XCTAssertEqual(router.schedulePath.count, 1)
    }

    func testScheduleSuppliesPathComponent() {
        let router = Router()
        let url = URL(string: "barnio://schedule/supplies")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .schedule)
        XCTAssertEqual(router.schedulePath.count, 1)
    }

    func testInvalidHostDoesNotChangeTab() {
        let router = Router()
        let originalTab = router.selectedTab
        let url = URL(string: "barnio://nonexistent")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, originalTab)
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.horsesPath.isEmpty)
        XCTAssertTrue(router.clientsPath.isEmpty)
        XCTAssertTrue(router.schedulePath.isEmpty)
        XCTAssertTrue(router.accountingPath.isEmpty)
    }

    func testWrongSchemeIsIgnored() {
        let router = Router()
        let url = URL(string: "https://horses")!
        DeepLinkHandler.handle(url: url, router: router)

        // Should remain on default tab with no navigation
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertTrue(router.horsesPath.isEmpty)
    }

    func testSubscriptionPaywallDeepLink() {
        let router = Router()
        let url = URL(string: "barnio://subscription/paywall")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testSubscriptionWithoutPathGoesToPaywall() {
        let router = Router()
        let url = URL(string: "barnio://subscription")!
        DeepLinkHandler.handle(url: url, router: router)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router.homePath.count, 1)
    }

    func testDeepLinkResetsExistingPathBeforeNavigating() {
        let router = Router()
        // Pre-populate horses path
        router.navigate(to: HorseRoute.list, tab: .horses)
        router.navigate(to: HorseRoute.list, tab: .horses)
        XCTAssertEqual(router.horsesPath.count, 2)

        // Deep link to horses should reset the path
        let url = URL(string: "barnio://horses")!
        DeepLinkHandler.handle(url: url, router: router)
        XCTAssertTrue(router.horsesPath.isEmpty)
    }
}
