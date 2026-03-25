import XCTest

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!
    let dir = "/Users/antic/github.com/atomantic/BarnHub/screenshots"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-SeedSampleData", "-ForceProMode"]
        app.launch()
    }

    func testCaptureAllScreenshots() {
        // 1. Home screen
        let title = app.staticTexts["BarnHub"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        saveScreenshot("01_home")

        let tabBar = app.tabBars.firstMatch

        // 2. Horses list
        tabBar.buttons["Horses"].tap()
        sleep(1)
        saveScreenshot("02_horses")

        // 3. Horse detail (tap first horse — Arrow)
        let arrowCell = app.cells.firstMatch
        if arrowCell.waitForExistence(timeout: 3) {
            arrowCell.tap()
            sleep(1)
            saveScreenshot("03_horse_detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // 4. Clients
        tabBar.buttons["Clients"].tap()
        sleep(1)
        saveScreenshot("04_clients")

        // 5. Client detail (tap first client)
        let clientCell = app.cells.firstMatch
        if clientCell.waitForExistence(timeout: 3) {
            clientCell.tap()
            sleep(1)
            saveScreenshot("05_client_detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // 6. Schedule
        tabBar.buttons["Schedule"].tap()
        sleep(1)
        saveScreenshot("06_schedule")

        // 7. Accounting
        tabBar.buttons["Accounting"].tap()
        sleep(1)
        saveScreenshot("07_accounting")

        // 8. Reports (from Home grid)
        tabBar.buttons["Home"].tap()
        sleep(1)
        let reports = app.buttons["Reports"]
        XCTAssertTrue(reports.waitForExistence(timeout: 3))
        reports.tap()
        sleep(2)
        saveScreenshot("08_reports")

        // 9. Scroll reports to show charts
        let reportsView = app.scrollViews.firstMatch
        if reportsView.exists {
            reportsView.swipeUp()
            sleep(1)
            saveScreenshot("09_reports_charts")
        }

        // 10. Contract generator with type picker
        tabBar.buttons["Clients"].tap()
        sleep(1)
        let clientCell2 = app.cells.firstMatch
        if clientCell2.waitForExistence(timeout: 3) {
            clientCell2.tap()
            sleep(1)

            // Scroll to find Generate Contract
            let list = app.collectionViews.firstMatch
            for _ in 0..<5 {
                if app.staticTexts["Generate Contract"].exists { break }
                list.swipeUp()
                sleep(1)
            }

            if app.staticTexts["Generate Contract"].exists {
                app.staticTexts["Generate Contract"].tap()
                sleep(2)

                // Tap the Type picker row to expand it and show options
                let typePicker = app.staticTexts["Boarding Agreement"]
                if typePicker.waitForExistence(timeout: 3) {
                    typePicker.tap()
                    sleep(1)
                    saveScreenshot("10_contract_types")
                } else {
                    // Fallback: screenshot the form as-is
                    saveScreenshot("10_contract_types")
                }
            }
        }
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = screenshot.pngRepresentation
        let url = URL(fileURLWithPath: "\(dir)/\(name).png")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}
