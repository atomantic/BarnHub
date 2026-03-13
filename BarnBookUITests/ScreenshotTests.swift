import XCTest

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!
    let dir = "/Users/antic/github.com/atomantic/BarnBook/screenshots"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-SeedSampleData"]
        app.launch()
    }

    func testCaptureAllScreenshots() {
        // 1. Home screen
        let title = app.staticTexts["BarnBook"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        saveScreenshot("01_home")

        // 2. Horses
        let tabBar = app.tabBars.firstMatch
        tabBar.buttons["Horses"].tap()
        sleep(1)
        saveScreenshot("02_horses")

        // 3. Clients
        tabBar.buttons["Clients"].tap()
        sleep(1)
        saveScreenshot("03_clients")

        // 4. Schedule
        tabBar.buttons["Schedule"].tap()
        sleep(1)
        saveScreenshot("04_schedule")

        // 5. Accounting
        tabBar.buttons["Accounting"].tap()
        sleep(1)
        saveScreenshot("05_accounting")

        // 6. Reports (from Home grid)
        tabBar.buttons["Home"].tap()
        sleep(1)
        let reports = app.buttons["Reports"]
        XCTAssertTrue(reports.waitForExistence(timeout: 3))
        reports.tap()
        sleep(1)
        saveScreenshot("06_reports")
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
