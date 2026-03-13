import XCTest

final class BarnBookUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testHomeScreenExists() {
        let barnBookTitle = app.staticTexts["BarnBook"]
        XCTAssertTrue(barnBookTitle.waitForExistence(timeout: 5))
    }

    func testHomeScreenFeatureTiles() {
        let horses = app.buttons["Horses"]
        let clients = app.buttons["Clients"]
        let schedule = app.buttons["Schedule"]
        let supplies = app.buttons["Supplies"]
        let accounting = app.buttons["Accounting"]
        let reports = app.buttons["Reports"]

        XCTAssertTrue(horses.waitForExistence(timeout: 5))
        XCTAssertTrue(clients.exists)
        XCTAssertTrue(schedule.exists)
        XCTAssertTrue(supplies.exists)
        XCTAssertTrue(accounting.exists)
        XCTAssertTrue(reports.exists)
    }

    func testTabBarExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["Home"].exists)
        XCTAssertTrue(tabBar.buttons["Horses"].exists)
        XCTAssertTrue(tabBar.buttons["Clients"].exists)
        XCTAssertTrue(tabBar.buttons["Schedule"].exists)
        XCTAssertTrue(tabBar.buttons["Accounting"].exists)
    }

    func testTabNavigation() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Horses"].tap()
        tabBar.buttons["Clients"].tap()
        tabBar.buttons["Schedule"].tap()
        tabBar.buttons["Accounting"].tap()
        tabBar.buttons["Home"].tap()
    }
}
