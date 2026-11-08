import XCTest

/// Delete All Data and Restore All Data's chained dialogs (#76). The second
/// dialog used to be dropped on iPad, so nothing got deleted.
final class DataResetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SeedSampleData", "-ForceProMode",
                               "-net.shadowpuppet.BarnBook.hasCompletedFirstLaunch", "YES",
                               "-screenshotRoute", "settings"]
        app.launch()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openDataManagement() {
        let row = app.buttons["Import / Export"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["Delete All Data"].firstMatch.waitForExistence(timeout: 5))
    }

    /// The dialog's `title` button, not the same-named row behind the dialog:
    /// the match closest to the dialog's `heading`.
    private func dialogButton(_ title: String, below heading: String) -> XCUIElement {
        let headingY = app.staticTexts[heading].frame.midY
        return app.buttons.matching(identifier: title).allElementsBoundByIndex
            .min { abs($0.frame.midY - headingY) < abs($1.frame.midY - headingY) } ?? app.buttons[title]
    }

    func testDeleteAllData_reachesFinalConfirmationAndDeletes() {
        openDataManagement()
        app.buttons["Delete All Data"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Delete All Data?"].waitForExistence(timeout: 5))
        screenshot("1 Delete All Data")
        app.buttons["Delete Everything"].tap()

        XCTAssertTrue(app.staticTexts["Final Confirmation"].waitForExistence(timeout: 5), "the second dialog appears")
        screenshot("2 Final Confirmation")
        dialogButton("Delete All Data", below: "Final Confirmation").tap()

        XCTAssertTrue(app.staticTexts["All data deleted"].waitForExistence(timeout: 5), "everything was deleted")
        screenshot("3 All data deleted")
    }

    func testDeleteAllData_cancelAtEitherStepKeepsData() {
        openDataManagement()
        app.buttons["Delete All Data"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Delete All Data?"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Delete All Data?"].waitForExistence(timeout: 2))

        app.buttons["Delete All Data"].firstMatch.tap()
        app.buttons["Keep Documents"].tap()
        XCTAssertTrue(app.staticTexts["Final Confirmation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Final Confirmation"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["All data deleted"].waitForExistence(timeout: 2), "nothing was deleted")
    }

    /// Needs an All Data "BarnHub Export" folder in On My iPhone / On My
    /// iPad on the simulator; skipped otherwise.
    func testRestore_deleteAllDataThenRestore() throws {
        openDataManagement()
        app.buttons["Restore All Data"].firstMatch.tap()
        let local = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'On My'")).firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 10))
        local.tap()
        let folder = app.staticTexts["BarnHub Export"].firstMatch
        guard folder.waitForExistence(timeout: 5) else {
            throw XCTSkip("no BarnHub Export folder in On My iPhone/iPad")
        }
        folder.tap()
        let open = app.buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        XCTAssertTrue(app.buttons["Restore and Keep My Data"].waitForExistence(timeout: 5))
        screenshot("1 Restore choice")
        app.buttons["Delete All Data, Then Restore"].tap()

        XCTAssertTrue(app.staticTexts["Delete All Data, Then Restore?"].waitForExistence(timeout: 5))
        screenshot("2 Documents question")
        app.buttons["Delete Everything"].tap()

        XCTAssertTrue(app.staticTexts["Final Confirmation"].waitForExistence(timeout: 5))
        screenshot("3 Final Confirmation")
        dialogButton("Delete All Data, Then Restore", below: "Final Confirmation").tap()

        XCTAssertTrue(app.staticTexts["Restore Complete"].waitForExistence(timeout: 120))
        screenshot("4 Restore Complete")
    }
}
