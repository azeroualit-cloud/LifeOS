import XCTest

final class NativeRevision72UITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--compact-calendar", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + extra
        app.launch()
        XCTAssertTrue(app.mainTabBar.buttons["Dashboard"].waitForExistence(timeout: 30))
        return app
    }
    private func day() -> String {
        let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    private func openDay(_ app: XCUIApplication) {
        app.openOtherDestination("Calendario")
        let today = app.buttons["calendar-day-" + day()]
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            if today.isHittable { break }
            scroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(today.isHittable); today.tap(); app.openCalendarAgenda()
        XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
    }
    func testDatePickerHasSevenFullWidthColumnsAfterTypingAndBothDatesRemainClearable() {
        let app = launch()
        app.openMainTab("Attività"); app.buttons["primary-add"].tap()
        let title = app.textFields["activity-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText("Data senza tagli")
        for identifier in ["Inizio", "Scadenza"] {
            app.buttons["activity-date-" + identifier].tap()
            let picker = app.datePickers.firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 10))
            XCTAssertGreaterThan(picker.frame.width, app.frame.width * 0.8)
            XCTAssertGreaterThanOrEqual(picker.frame.minX, 0)
            XCTAssertLessThanOrEqual(picker.frame.maxX, app.frame.width)
            capture("72-date-picker-full-width-" + identifier)
            app.buttons["Fine"].tap()
        }
        app.buttons["Rimuovi inizio"].tap(); app.buttons["Rimuovi scadenza"].tap()
        XCTAssertFalse(app.buttons["Rimuovi inizio"].exists)
        XCTAssertEqual(title.value as? String, "Data senza tagli")
    }
    func testDayHasReachableMonthNavigationAndPinnedEventAction() {
        let app = launch(); openDay(app)
        let back = app.buttons["calendar-back-month"]
        let title = app.staticTexts["calendar-day-heading"]
        let add = app.buttons["calendar-add-event"]
        XCTAssertTrue(title.isHittable)
        for button in [back, app.buttons["calendar-previous-day"], app.buttons["calendar-next-day"], add] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height.rounded(), 44)
        }
        XCTAssertLessThanOrEqual(add.frame.maxY, app.mainTabBar.frame.minY)
        XCTAssertGreaterThan(add.frame.minY, title.frame.maxY)
        capture("day-navigation-and-event-action")
        back.tap(); XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
    }
    // Retired with the build 95 day list (no nested timeline blocks): testLongEventIsCompactAndContainsItsInnerEventAndDayScrollReachesMidnight.
    func testFinanceBudgetIsSmallerAndReferenceRoutesStillWork() {
        let app = launch(); app.openOtherDestination("Finanza")
        let amount = app.staticTexts["finance-budget-value"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        XCTAssertLessThan(amount.frame.height, 65)
        XCTAssertTrue(app.buttons["finance-budget"].isHittable)
        XCTAssertTrue(app.buttons["finance-analysis"].isHittable)
        capture("72-finance-refined-hierarchy")
    }
}
