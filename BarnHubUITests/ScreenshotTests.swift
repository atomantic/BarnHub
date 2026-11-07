import XCTest

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    private static let projectDir = "/Users/antic/github.com/atomantic/BarnHub"

    /// Read config from project dir or /tmp (written by take_screenshots.sh)
    private var config: [String: String] {
        for path in ["\(Self.projectDir)/.screenshot_config.json",
                     "/tmp/barnhub_screenshot_config.json"] {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return dict
            }
        }
        return [:]
    }

    private var locale: String { config["locale"] ?? "en" }

    private var isIPad: Bool {
        if let device = config["device"] { return device.hasPrefix("ipad") }
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    private var deviceType: String {
        if let device = config["device"] { return device }
        return isIPad ? "ipad_13" : "iphone_6.7"
    }

    private var outputDir: String {
        config["output_dir"] ?? "\(Self.projectDir)/screenshots"
    }

    private var currency: String { config["currency"] ?? "USD" }

    /// Non-nil when only a single screen should be saved (e.g. "01_home").
    private var targetScreen: String? {
        let s = config["target_screen"] ?? ""
        return s.isEmpty ? nil : s
    }

    private var launchArgs: [String] {
        ["-SeedSampleData", "-ForceProMode",
         "-net.shadowpuppet.BarnBook.appLocale", locale,
         "-net.shadowpuppet.BarnBook.currencyCode", currency,
         "-AppleLanguages", "(\(locale))",
         "-AppleLocale", locale]
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = launchArgs
        app.launch()
        sleep(2)
        dismissSystemAlerts()
    }

    // MARK: - iPhone Screenshots

    func testCaptureIPhoneScreenshots() {
        guard !isIPad else { return }

        saveScreenshot("01_home")

        let tabBar = app.tabBars.firstMatch

        // Horses list
        tabBar.buttons.element(boundBy: 1).tap()
        sleep(1)
        saveScreenshot("02_horses")

        // Horse detail
        if app.cells.firstMatch.waitForExistence(timeout: 3) {
            app.cells.firstMatch.tap()
            sleep(1)
            saveScreenshot("03_horse_detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Clients
        tabBar.buttons.element(boundBy: 2).tap()
        sleep(1)
        saveScreenshot("04_clients")

        // Client detail
        if app.cells.firstMatch.waitForExistence(timeout: 3) {
            app.cells.firstMatch.tap()
            sleep(1)
            saveScreenshot("05_client_detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Schedule
        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        saveScreenshot("06_schedule")

        // Accounting
        tabBar.buttons.element(boundBy: 4).tap()
        sleep(1)
        saveScreenshot("07_accounting")

        // Reports (navigate via Home tile)
        tabBar.buttons.element(boundBy: 0).tap()
        sleep(1)
        let reportsTile = app.buttons["tile_reports"]
        if reportsTile.waitForExistence(timeout: 3) {
            reportsTile.tap()
            sleep(2)
            saveScreenshot("08_reports")

            // Scroll to show charts
            let reportsView = app.scrollViews.firstMatch
            if reportsView.exists {
                reportsView.swipeUp()
                sleep(1)
                saveScreenshot("09_reports_charts")
            }
        }

        // Contract type picker (navigate to client detail → Generate Contract)
        tabBar.buttons.element(boundBy: 2).tap()
        sleep(1)
        if app.cells.firstMatch.waitForExistence(timeout: 3) {
            app.cells.firstMatch.tap()
            sleep(1)

            // Scroll to find Generate Contract button
            let list = app.collectionViews.firstMatch
            for _ in 0..<5 {
                let contractBtn = app.buttons["generate_contract"]
                if contractBtn.exists {
                    contractBtn.tap()
                    sleep(2)
                    saveScreenshot("10_contract_types")
                    break
                }
                list.swipeUp()
                sleep(1)
            }
        }
    }

    // MARK: - iPad Screenshots
    // iPad portrait hides sidebar — navigate via Home grid tiles, relaunch between screens.

    func testCaptureIPadScreenshots() {
        guard isIPad else { return }

        // 1. Home
        saveScreenshot("01_home")

        // 2-3. Horses + detail
        tapTile("tile_horses")
        saveScreenshot("02_horses")
        if app.cells.firstMatch.waitForExistence(timeout: 3) {
            app.cells.firstMatch.tap()
            sleep(1)
            saveScreenshot("03_horse_detail")
        }

        relaunch()

        // 4. Clients
        tapTile("tile_clients")
        saveScreenshot("04_clients")

        relaunch()

        // 5. Schedule
        tapTile("tile_schedule")
        saveScreenshot("05_schedule")

        relaunch()

        // 6. Accounting
        tapTile("tile_accounting")
        saveScreenshot("06_accounting")

        relaunch()

        // 7. Reports
        tapTile("tile_reports")
        saveScreenshot("07_reports")
    }

    // MARK: - iPhone Duo Screenshots
    // Run once with the simulator closed (outer display) and once open (inner display);
    // take_screenshots.sh passes the matching folder (duo_outer / duo_inner) via config.
    // Each screen relaunches straight to its route, because bar positions (vertical on the
    // side vs. horizontal) differ between poses and make tab-tapping unreliable.

    func testCaptureDuoScreenshots() {
        guard deviceType.hasPrefix("duo") else { return }

        let screens: [(name: String, route: String)] = [
            ("01_home", "home"),
            ("02_horses", "horses"),
            ("03_horse_detail", "horseDetail"),
            ("04_clients", "clients"),
            ("05_client_detail", "clientDetail"),
            ("06_schedule", "schedule"),
            ("07_accounting", "accounting"),
        ]
        for (index, screen) in screens.enumerated() {
            if let target = targetScreen, target != screen.name { continue }
            if index > 0 || targetScreen != nil {
                relaunch(route: screen.route)
            }
            saveScreenshot(screen.name)
        }
    }

    // MARK: - Helpers

    private func tapTile(_ identifier: String) {
        let tile = app.buttons[identifier]
        if tile.waitForExistence(timeout: 3) {
            tile.tap()
            sleep(2)
        }
    }

    private func relaunch(route: String? = nil) {
        app.launchArguments = launchArgs + (route.map { ["-screenshotRoute", $0] } ?? [])
        app.launch()
        sleep(2)
        dismissSystemAlerts()
    }

    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Check localized "Allow" buttons across all supported languages
        for label in ["Allow", "Erlauben", "Autoriser", "Permitir",
                      "Consenti", "Toestaan", "Tillåt"] {
            let btn = springboard.buttons[label]
            if btn.waitForExistence(timeout: 1) {
                btn.tap()
                sleep(1)
                return
            }
        }
    }

    private func saveScreenshot(_ name: String) {
        if let target = targetScreen, target != name { return }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(locale)_\(deviceType)_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        let dir = "\(outputDir)/\(locale)/\(deviceType)"
        let url = URL(fileURLWithPath: "\(dir)/\(name).png")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: url)
    }
}
