import XCTest

final class NativeNavigationUITests: XCTestCase {
    private let destinations = ["Dashboard", "Attività", "Salute", "Bloom", "Finanza", "Calendario"]

    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + (large ? ["--large-text"] : [])
        app.launch()
        XCTAssertTrue(app.mainTabBar.waitForExistence(timeout: 15))
        return app
    }

    private func assertSixVisibleTargets(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.mainTabBar.buttons.count, 6, file: file, line: line)
        XCTAssertFalse(app.mainTabBar.buttons["Altro"].exists, file: file, line: line)
        XCTAssertFalse(app.mainTabBar.buttons["More"].exists, file: file, line: line)
        var previousX = -CGFloat.infinity
        for title in destinations {
            let button = app.mainTabButton(title)
            XCTAssertTrue(button.exists && button.isHittable, title, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.width.rounded(), 44, title, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.height.rounded(), 44, title, file: file, line: line)
            XCTAssertGreaterThan(button.frame.midX, previousX, title, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX, title, file: file, line: line)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX, title, file: file, line: line)
            previousX = button.frame.midX
        }
    }

    func testSixVisibleTabsPreserveCalendarFinanceAndDashboardStacks() {
        let app = launch()
        assertSixVisibleTargets(app)
        capture("Sei destinazioni Liquid Glass senza Altro")

        app.openMainTab("Calendario")
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 15))
        let paint = app.buttons["toggle-shift-paint"]
        XCTAssertTrue(paint.waitForExistence(timeout: 10))
        XCTAssertEqual(paint.label, "Dipingi turni")
        paint.tap()
        XCTAssertTrue(app.scrollViews["shift-brush-scroll"].waitForExistence(timeout: 10))
        XCTAssertEqual(paint.label, "Fine")
        capture("Calendario e nuova icona turni")
        app.openMainTab("Salute")
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
        app.openMainTab("Calendario")
        XCTAssertTrue(app.scrollViews["shift-brush-scroll"].waitForExistence(timeout: 10), "Switching tabs preserves the calendar editing state")
        paint.tap()
        app.buttons["other-back"].tap()
        XCTAssertTrue(app.isMainTabSelected("Dashboard"))

        app.openMainTab("Finanza")
        XCTAssertTrue(app.scrollViews["finance-scroll"].waitForExistence(timeout: 10))
        let month = app.staticTexts["finance-month"]
        let original = month.label
        app.buttons["Mese successivo"].tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", original), object: month)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
        let nextMonth = month.label
        capture("Finanza dalla barra inferiore")
        app.openMainTab("Bloom")
        XCTAssertTrue(app.navigationBars["Bloom"].waitForExistence(timeout: 10))
        app.openMainTab("Finanza")
        XCTAssertEqual(month.label, nextMonth, "Switching tabs preserves the finance month")
        app.buttons["other-back"].tap()
        XCTAssertTrue(app.isMainTabSelected("Dashboard"))

        let calendar = app.buttons["home-calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        calendar.tap()
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
        app.openMainTab("Attività")
        XCTAssertTrue(app.navigationBars["Attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["primary-add"].isHittable)
        app.openMainTab("Dashboard")
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10), "The dashboard stack survives a tab switch")
        app.openMainTab("Dashboard")
        XCTAssertTrue(app.scrollViews["dashboard-scroll"].waitForExistence(timeout: 10), "Reselecting Dashboard returns to its root")
        assertSixVisibleTargets(app)
    }

    func testSixVisibleTabsWithLargeTextAndKeyboard() {
        let app = launch(large: true)
        assertSixVisibleTargets(app)
        capture("Sei destinazioni con testo grande")
        for title in ["Attività", "Salute", "Bloom", "Finanza", "Calendario", "Dashboard"] {
            app.openMainTab(title)
            XCTAssertTrue(app.isMainTabSelected(title))
            assertSixVisibleTargets(app)
        }
        app.openMainTab("Bloom")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        for _ in 0..<4 where !search.isHittable { app.scrollViews["bloom-library-scroll"].swipeDown(velocity: .slow) }
        XCTAssertTrue(search.isHittable)
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.mainTabBar)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed, "The navigation bar should not cover the keyboard")
        capture("Ricerca Bloom e tastiera senza barra sovrapposta")
        // On this iOS runtime the native search dismissal is an X beside the
        // field, rather than a text button named Cancel. Select that visible
        // control by its observed relationship to the active search field.
        let searchFrame = search.frame
        let close = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.midX > searchFrame.maxX &&
            abs($0.frame.midY - searchFrame.midY) < max(searchFrame.height, 44) / 2
        }.min { $0.frame.minX < $1.frame.minX }
        guard let close else {
            XCTFail("Missing native dismissal control beside the search field: " + app.debugDescription)
            return
        }
        print("NATIVE_SEARCH_DISMISS_LABEL " + close.label)
        close.tap()
        XCTAssertTrue(app.mainTabBar.waitForExistence(timeout: 10))
        assertSixVisibleTargets(app)
        capture("Barra ripristinata dopo la tastiera")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
