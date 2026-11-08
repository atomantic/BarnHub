import XCTest

final class BarnHubUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testHomeScreenExists() {
        let barnBookTitle = app.staticTexts["BarnHub"]
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

    /// #35: an amount typed on the decimal pad without a currency symbol, and
    /// without pressing Return (the pad has none), is saved.
    func testTypedAmountWithoutSymbolIsSaved() {
        // Skip the first-launch sheet, which would cover the tab bar.
        app.terminate()
        app.launchArguments = ["-net.shadowpuppet.BarnBook.hasCompletedFirstLaunch", "YES"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Accounting"].tap()
        let newTransaction = app.buttons["New Transaction"].firstMatch
        XCTAssertTrue(newTransaction.waitForExistence(timeout: 5))
        newTransaction.tap()

        let memo = "UI test \(Int(Date().timeIntervalSince1970))"
        let memoField = app.textFields["Memo"]
        XCTAssertTrue(memoField.waitForExistence(timeout: 5))
        memoField.tap()
        memoField.typeText(memo)

        // Type the amount last and save straight away, so nothing but the
        // keystrokes themselves can commit it.
        let amount = app.textFields.element(boundBy: 0)
        amount.tap()
        amount.typeText("12.50")

        app.buttons["Save"].tap()

        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", memo)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "saved transaction listed")
        XCTAssertTrue(row.label.contains("12.50"), "saved amount: \(row.label)")
    }
}
