import XCTest

/// Pre-deploy screen walk: opens every screen with sample data and checks that
/// each one shows its content, not just that the app didn't crash.
///
/// Each screen is opened on a fresh launch with `-screenshotRoute <page>` (see
/// `ScreenshotRouter`, Debug builds only) on the first matching sample record,
/// then the test waits for text that only appears once the screen has rendered
/// its data. The journey tests tap through the app like a user would, including
/// opening each document and invoice, where a blank sheet has bitten before.
///
/// Runs on iPhone and iPad (`BarnHubUITests`) and on the native Mac app
/// (`BarnHubMacUITests`). Run all three with `./scripts/test.sh`.
final class ScreenWalkTests: XCTestCase {
    var app: XCUIApplication!

    /// A screen to open and the text it must show. Every string in `expect` has
    /// to appear (in a label, value, title or identifier, ignoring case); at
    /// least one of `anyOf` too, when it's given.
    struct Screen {
        let page: String
        let expect: [String]
        var anyOf: [String] = []
    }

    // MARK: - Screens

    static let tabScreens: [Screen] = [
        // iPhone and iPad show feature tiles; the Mac shows stat cards and lists.
        Screen(page: "home", expect: [], anyOf: ["tile_horses", "Action Items"]),
        Screen(page: "horses", expect: ["Arrow", "Cleo"]),
        Screen(page: "clients", expect: ["Chen", "Rivera"]),
        // iPhone lists the schedule screens; iPad shows a calendar with them in a menu.
        Screen(page: "schedule", expect: [], anyOf: ["Vet Schedule", "Add Event"]),
        Screen(page: "accounting", expect: ["This Month", "Recent Transactions"],
               anyOf: ["Arena footing", "Weekly lesson", "Group trail ride", "Dressage training"]),
    ]

    static let homeScreens: [Screen] = [
        Screen(page: "reports", expect: ["Income vs Expenses", "Expenses by Category"]),
        Screen(page: "supplies", expect: ["Fly Spray", "Pine Shavings"]),
        Screen(page: "homeBarnNotes", expect: ["stiff in his left front"]),
        Screen(page: "dataManagement", expect: ["Export", "Delete All Data"]),
        Screen(page: "paywall", expect: ["Restore Purchases"]),
        Screen(page: "settings", expect: ["Subscription", "Feedback"]),
    ]

    static let horseScreens: [Screen] = [
        Screen(page: "horseDetail", expect: ["Thoroughbred", "Slight sensitivity in left front hoof"]),
        Screen(page: "addHorse", expect: ["New Horse", "Breed"]),
        Screen(page: "editHorse", expect: ["Edit Horse", "Thoroughbred", "Bay with white blaze"]),
        Screen(page: "addVetRecord", expect: ["New Vet Record", "Vet Name"]),
        Screen(page: "editVetRecord", expect: ["Edit Vet Record", "Annual vaccinations"]),
        Screen(page: "addFarrierVisit", expect: ["New Farrier Visit", "Service Description"]),
        Screen(page: "editFarrierVisit", expect: ["Edit Farrier Visit", "Barefoot trim"]),
        Screen(page: "addDentistVisit", expect: ["New Dentist Visit", "Service Description"]),
        Screen(page: "editDentistVisit", expect: ["Edit Dentist Visit", "Routine dental float"]),
        Screen(page: "healthTimeline", expect: ["Health Timeline", "Annual vaccinations"]),
        Screen(page: "weightChart", expect: ["Weight Trend", "1,100 lbs"]),
        Screen(page: "horseDocuments", expect: ["Coggins Certificate", "Registration Photo"]),
        Screen(page: "feedPlan", expect: ["Feed Plan", "Sweet Feed", "Timothy Hay"]),
        Screen(page: "addFeedEntry", expect: ["Add Feed Item", "Assigned Person"]),
        Screen(page: "editFeedEntry", expect: ["Edit Feed Item", "Sweet Feed"]),
    ]

    static let clientScreens: [Screen] = [
        Screen(page: "clientDetail", expect: ["sarah.c@example.com", "Beginner rider"]),
        Screen(page: "addClient", expect: ["New Client", "First Name"]),
        Screen(page: "editClient", expect: ["Edit Client", "sarah.c@example.com"]),
        Screen(page: "manageHorses", expect: ["Manage Horses", "Arrow", "Cleo"]),
        Screen(page: "invoiceHistory", expect: ["Invoice History", "150.00"]),
        Screen(page: "paymentHistory", expect: ["Payment History", "Weekly lesson — Sarah"]),
        Screen(page: "clientDocuments", expect: ["Boarding Agreement", "Signed Waiver"]),
    ]

    static let accountingScreens: [Screen] = [
        Screen(page: "transactions", expect: ["Transactions", "Hay delivery"]),
        Screen(page: "addTransaction", expect: ["New Transaction", "Memo"]),
        Screen(page: "editTransaction", expect: ["Edit Transaction"],
               anyOf: ["Weekly lesson — Sarah on Arrow", "Arena footing maintenance"]),
    ]

    static let scheduleScreens: [Screen] = [
        Screen(page: "barnSupplies", expect: ["Supplies", "Fly Spray"]),
        Screen(page: "addSupply", expect: ["New Supply", "Unit (e.g., lbs, bags)"]),
        Screen(page: "editSupply", expect: ["Edit Supply", "Fly Spray"]),
        Screen(page: "reminders", expect: ["Reminders", "Barn inspection"]),
        Screen(page: "addReminder", expect: ["New Reminder", "Due Date"]),
        Screen(page: "editReminder", expect: ["Edit Reminder", "Barn inspection"]),
        Screen(page: "barnNotes", expect: ["Barn Notes", "stiff in his left front"]),
        Screen(page: "addBarnNote", expect: ["New Note", "What happened at the barn?"]),
        Screen(page: "editBarnNote", expect: ["Edit Note", "stiff in his left front"]),
        Screen(page: "vetSchedule", expect: ["Vet Schedule", "Annual vaccinations"]),
        Screen(page: "scheduleVet", expect: ["New Vet Record", "Vet Name"]),
        Screen(page: "farrierSchedule", expect: ["Farrier Schedule", "Trim and reset front shoes"]),
        Screen(page: "scheduleFarrier", expect: ["New Farrier Visit", "Service Description"]),
        Screen(page: "dentistSchedule", expect: ["Dentist Schedule", "Routine dental float"]),
        Screen(page: "scheduleDentist", expect: ["New Dentist Visit", "Service Description"]),
        Screen(page: "lessons", expect: ["Lessons", "Posting trot and diagonals"]),
        Screen(page: "addLesson", expect: ["New Lesson", "Lesson Type"]),
        Screen(page: "editLesson", expect: ["Edit Lesson", "Posting trot and diagonals"]),
        Screen(page: "feedProducts", expect: ["Feed Products", "Alfalfa Cubes"]),
        Screen(page: "addFeedProduct", expect: ["New Feed Product", "Brand"]),
        Screen(page: "editFeedProduct", expect: ["Edit Product", "Alfalfa Cubes"]),
    ]

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Report every screen that fails, not just the first.
        continueAfterFailure = true
        app = XCUIApplication()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    private func launch(page: String? = nil) {
        app.terminate()
        app.launchArguments = [
            "-SeedSampleData", "-ForceProMode",
            "-net.shadowpuppet.BarnBook.hasCompletedFirstLaunch", "YES",
            "-net.shadowpuppet.BarnBook.appLocale", "en",
            "-net.shadowpuppet.BarnBook.currencyCode", "USD",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + (page.map { ["-screenshotRoute", $0] } ?? [])
        app.launch()
    }

    // MARK: - Every screen

    func testTabScreens() { walk(Self.tabScreens) }
    func testHomeScreens() { walk(Self.homeScreens) }
    func testHorseScreens() { walk(Self.horseScreens) }
    func testClientScreens() { walk(Self.clientScreens) }
    func testAccountingScreens() { walk(Self.accountingScreens) }
    func testScheduleScreens() { walk(Self.scheduleScreens) }

    private func walk(_ screens: [Screen]) {
        for screen in screens {
            XCTContext.runActivity(named: screen.page) { _ in
                launch(page: screen.page)
                assertShows(screen.expect, anyOf: screen.anyOf, on: screen.page)
            }
        }
    }

    // MARK: - Journeys

    /// Taps each tab (tab bar on iPhone, sidebar on iPad and Mac) and checks
    /// that its screen fills in.
    func testTabNavigation() {
        launch()
        let tabs: [(title: String, sidebarID: String, screen: Screen)] = [
            ("Horses", "sidebar_horses", Self.tabScreens[1]),
            ("Clients", "sidebar_clients", Self.tabScreens[2]),
            ("Schedule", "sidebar_schedule", Self.tabScreens[3]),
            ("Accounting", "sidebar_accounting", Self.tabScreens[4]),
            ("Home", "sidebar_home", Self.tabScreens[0]),
        ]
        for tab in tabs {
            XCTContext.runActivity(named: tab.title) { _ in
                selectTab(tab.title, sidebarID: tab.sidebarID)
                assertShows(tab.screen.expect, anyOf: tab.screen.anyOf, on: tab.title)
            }
        }
    }

    /// Opens a horse from the list, then its documents.
    func testHorseListToDetailToDocuments() {
        launch()
        selectTab("Horses", sidebarID: "sidebar_horses")
        tapText("Arrow")
        assertShows(["Slight sensitivity in left front hoof"], on: "horse detail")
        tapText("Documents")
        assertShows(["Coggins Certificate", "Registration Photo"], on: "horse documents")
    }

    /// Opens a client from the list, then their documents.
    func testClientListToDetailToDocuments() {
        launch()
        selectTab("Clients", sidebarID: "sidebar_clients")
        tapText("Chen")
        assertShows(["sarah.c@example.com"], on: "client detail")
        tapText("Documents")
        assertShows(["Boarding Agreement", "Signed Waiver"], on: "client documents")
    }

    func testHorsePhotoDocumentOpens() {
        openDocument("Registration Photo", from: "horseDocuments")
    }

    func testHorsePDFDocumentOpens() {
        openDocument("Coggins Certificate", from: "horseDocuments")
    }

    func testClientPhotoDocumentOpens() {
        openDocument("Signed Waiver", from: "clientDocuments")
    }

    func testClientPDFDocumentOpens() {
        openDocument("Boarding Agreement", from: "clientDocuments")
    }

    /// Tapping an invoice shares its PDF: the share sheet must show it, not open blank.
    func testInvoiceOpensShareSheet() {
        launch(page: "invoiceHistory")
        assertShows(["150.00"], on: "invoice history")
        tapText("150.00")
        assertShareSheetShown(for: "invoice")
    }

    /// Tapping a document row opens it in Quick Look, which must show the file.
    private func openDocument(_ title: String, from page: String) {
        launch(page: page)
        assertShows([title], on: page)
        tapText(title)
        #if os(macOS)
        // Quick Look opens as a panel titled with the file name.
        // Titled with the temp file's name, where spaces become underscores.
        let fileName = title.replacingOccurrences(of: " ", with: "_")
        let titled = NSPredicate(format: "title CONTAINS[c] %@ OR title CONTAINS[c] %@", title, fileName)
        let panel = app.windows.matching(titled).firstMatch
        let dialog = app.dialogs.matching(titled).firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10) || dialog.exists, "\(title): no Quick Look panel opened")
        #else
        // Quick Look's own bar: a close (Done) button over the file, titled with
        // the file's name (spaces become underscores in the temp file name).
        let close = app.buttons.matching(NSPredicate(
            format: "identifier == 'QLOverlayDoneButtonAccessibilityIdentifier' OR label == 'Done' OR label ==[c] 'close'"
        )).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "\(title): no viewer opened (no close button)")
        let fileName = title.replacingOccurrences(of: " ", with: "_")
        XCTAssertTrue(element(containing: fileName) != nil || element(containing: title) != nil,
                      "\(title): viewer doesn't name the file")
        #endif
        attachScreenshot(named: "\(page) \(title)")
        assertStillRunning(title)
    }

    private func assertShareSheetShown(for name: String) {
        #if os(macOS)
        // The Mac share sheet offers Reveal in Finder only when it has the file.
        let reveal = app.buttons["Reveal in Finder"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10), "\(name): share sheet missing or blank")
        #else
        // The share sheet's activity list, or its Copy action (iPad popovers
        // don't always expose the list by name).
        // iPad hosts the share sheet out of process, invisible to XCUITest, so
        // fall back to the app's debug marker that one is presented.
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        let marker = app.descendants(matching: .any)["share_sheet_presented"]
        let shown = sheet.waitForExistence(timeout: 10) || copy.exists || marker.exists
        XCTAssertTrue(shown, "\(name): share sheet missing or blank")
        #endif
        attachScreenshot(named: "\(name) share sheet")
        assertStillRunning(name)
    }

    // MARK: - Helpers

    /// Waits for every string in `texts`, and one of `anyOf`, then checks the
    /// app is still running. Attaches a screenshot either way.
    private func assertShows(_ texts: [String], anyOf: [String] = [], on screen: String,
                             timeout: TimeInterval = 10,
                             file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var missing = texts
        var foundAny = anyOf.isEmpty
        let scrollAfter = Date().addingTimeInterval(3)
        var scrolls = 0
        repeat {
            missing = missing.filter { element(containing: $0) == nil }
            if !foundAny { foundAny = anyOf.contains { element(containing: $0) != nil } }
            if missing.isEmpty && foundAny { break }
            // Lists build rows lazily, so text below the fold only exists once
            // it's scrolled to. Give the screen a moment, then scroll down.
            if Date() > scrollAfter && scrolls < 5 {
                scrollDown()
                scrolls += 1
            } else {
                Thread.sleep(forTimeInterval: 0.3)
            }
        } while Date() < deadline && app.state == .runningForeground

        attachScreenshot(named: screen)
        assertStillRunning(screen, file: file, line: line)
        XCTAssertTrue(missing.isEmpty, "\(screen): didn't show \(missing)", file: file, line: line)
        XCTAssertTrue(foundAny, "\(screen): didn't show any of \(anyOf)", file: file, line: line)
    }

    private func assertStillRunning(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "\(screen): app is no longer running (crashed?)",
                       file: file, line: line)
    }

    /// The first visible element whose label, value, title or identifier
    /// contains `text`, ignoring case.
    private func element(containing text: String) -> XCUIElement? {
        let byLabel = NSPredicate(format: "label CONTAINS[c] %@ OR identifier == %@ OR title CONTAINS[c] %@",
                                  text, text, text)
        // Only text elements: on other types `value` can be a number or a bool.
        let byValue = NSPredicate(format: "value CONTAINS[c] %@", text)
        // An empty text field shows its prompt only as the placeholder.
        let byPlaceholder = NSPredicate(format: "placeholderValue CONTAINS[c] %@", text)
        let queries: [XCUIElementQuery] = [
            app.staticTexts.matching(byLabel),
            app.buttons.matching(byLabel),
            app.cells.matching(byLabel),
            app.otherElements.matching(byLabel),
            app.navigationBars.matching(byLabel),
            app.windows.matching(byLabel),
            app.staticTexts.matching(byValue),
            app.textFields.matching(byValue),
            app.textViews.matching(byValue),
            app.textFields.matching(byLabel),
            app.textViews.matching(byLabel),
            app.textFields.matching(byPlaceholder),
            app.textViews.matching(byPlaceholder),
            // Pickers on the Mac: the selection is the pop-up button's value.
            app.popUpButtons.matching(byLabel),
            app.popUpButtons.matching(byValue),
        ]
        return queries.lazy.map(\.firstMatch).first { $0.exists }
    }

    /// Taps the first control showing `text`, scrolling down to find it.
    /// Plain text is only tapped when no button or row shows it, and then the
    /// last match, so a section header doesn't win over the row beneath it.
    private func tapText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let byLabel = NSPredicate(format: "label CONTAINS[c] %@", text)
        let controls = [app.buttons.matching(byLabel), app.cells.matching(byLabel)]
        let texts = [
            app.staticTexts.matching(byLabel),
            app.staticTexts.matching(NSPredicate(format: "value CONTAINS[c] %@", text)),
        ]
        for attempt in 0..<12 {
            if controls.contains(where: { $0.firstMatch.exists }) {
                if let target = controls.lazy.map(\.firstMatch).first(where: { $0.exists && $0.isHittable }) {
                    press(target)
                    return
                }
            } else if let target = texts.lazy.compactMap({ query in
                // The last match: a section header comes before the row
                // that repeats its title.
                query.allElementsBoundByIndex.last { $0.exists && $0.isHittable }
            }).first {
                press(target)
                return
            }
            // Wait for the screen first, then scroll down a step at a time.
            if attempt >= 3 { scrollDown() } else { Thread.sleep(forTimeInterval: 0.5) }
        }
        XCTFail("Nothing to tap showing \"\(text)\"", file: file, line: line)
    }

    private func press(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    private func scrollDown() {
        #if os(macOS)
        // Scroll every list and scroll view, so a detail column beside a
        // list scrolls too, not just whatever is under the window's center.
        let areas = app.scrollViews.allElementsBoundByIndex
            + app.tables.allElementsBoundByIndex
            + app.outlines.allElementsBoundByIndex
            + app.collectionViews.allElementsBoundByIndex
        let visible = areas.filter { $0.exists && $0.isHittable }
        if visible.isEmpty {
            app.windows.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        }
        visible.forEach { $0.scroll(byDeltaX: 0, deltaY: -300) }
        #else
        app.swipeUp()
        #endif
    }

    /// Selects a tab from the tab bar (iPhone), or the sidebar (iPad, Mac).
    private func selectTab(_ title: String, sidebarID: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        let tabBarButton = app.tabBars.buttons[title]
        let sidebarItem = app.descendants(matching: .any)[sidebarID]
        // iPad on iOS 18+ shows the tabs as a floating bar of plain buttons.
        // Home's tiles share the titles, so leave out anything tagged tile_.
        let floatingTab = app.buttons.matching(NSPredicate(
            format: "label == %@ AND NOT (identifier BEGINSWITH 'tile_')", title
        )).firstMatch
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            for item in [tabBarButton, sidebarItem, floatingTab] where item.exists && item.isHittable {
                press(item)
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTFail("No tab or sidebar item for \(title)", file: file, line: line)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }
}
