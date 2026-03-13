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

    func testFeatureTileNavigation() {
        let horses = app.buttons["Horses"]
        XCTAssertTrue(horses.waitForExistence(timeout: 5))
        horses.tap()

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        let clients = app.buttons["Clients"]
        XCTAssertTrue(clients.waitForExistence(timeout: 5))
        clients.tap()
    }
}
