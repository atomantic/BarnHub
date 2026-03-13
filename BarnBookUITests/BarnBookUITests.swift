import XCTest

final class BarnBookUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabBarExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let horsesTab = tabBar.buttons["Horses"]
        let clientsTab = tabBar.buttons["Clients"]
        let accountingTab = tabBar.buttons["Accounting"]
        let barnTab = tabBar.buttons["Barn"]

        XCTAssertTrue(horsesTab.exists)
        XCTAssertTrue(clientsTab.exists)
        XCTAssertTrue(accountingTab.exists)
        XCTAssertTrue(barnTab.exists)
    }

    func testTabNavigation() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Clients"].tap()
        tabBar.buttons["Accounting"].tap()
        tabBar.buttons["Barn"].tap()
        tabBar.buttons["Horses"].tap()
    }
}
