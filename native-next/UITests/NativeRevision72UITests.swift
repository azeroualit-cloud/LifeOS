import XCTest

final class NativeRevision72UITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--compact-calendar", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + extra
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
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
        app.tabBars.buttons["Calendario"].tap()
        let today = app.buttons["calendar-day-" + day()]
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            if today.isHittable { break }
            scroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(today.isHittable); today.tap()
        XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
    }
    func testDatePickerHasSevenFullWidthColumnsAfterTypingAndBothDatesRemainClearable() {
        let app = launch()
        app.tabBars.buttons["Attività"].tap(); app.buttons["primary-add"].tap()
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
    func testDayHasOneHeaderRowAndSevenShiftBadges() {
        let app = launch(); openDay(app)
        XCTAssertFalse(app.navigationBars["Calendario"].exists)
        XCTAssertFalse(app.buttons["Impostazioni"].exists)
        let back = app.buttons["calendar-back-month"], title = app.buttons["calendar-day-heading"], add = app.buttons["primary-add"]
        XCTAssertEqual(back.frame.midY, title.frame.midY, accuracy: 4)
        XCTAssertEqual(back.frame.midY, add.frame.midY, accuracy: 4)
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-week-day-"))
        XCTAssertEqual(days.count, 7)
        for index in 0..<7 {
            XCTAssertFalse(days.element(boundBy: index).label.contains("nessun turno"))
        }
        XCTAssertLessThan(days.firstMatch.frame.minY - back.frame.maxY, 65)
        capture("72-calendar-compact-header-week-shifts")
        back.tap(); XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
        capture("72-calendar-month-no-circle")
    }
    func testLongEventIsCompactAndContainsItsInnerEventAndDayScrollReachesMidnight() {
        let app = launch(); openDay(app)
        let long = app.descendants(matching: .any).matching(identifier: "calendar-agenda-block-event:301:" + day()).firstMatch
        let inner = app.buttons["calendar-timeline-event:302:" + day()]
        XCTAssertTrue(long.waitForExistence(timeout: 10)); XCTAssertTrue(inner.exists)
        XCTAssertLessThan(long.frame.height, 310)
        XCTAssertGreaterThanOrEqual(inner.frame.minY, long.frame.minY)
        XCTAssertLessThanOrEqual(inner.frame.maxY, long.frame.maxY)
        let strip = app.scrollViews["calendar-all-day-strip"]
        XCTAssertTrue(strip.exists); XCTAssertLessThanOrEqual(strip.frame.height, 60)
        XCTAssertFalse(app.staticTexts["07:00"].exists, "Intermediate hour rows must not consume space")
        capture("72-compact-long-event-and-chips")
        let last = app.buttons["calendar-timeline-event:304:" + day()]
        for _ in 0..<5 { if last.isHittable { break }; app.scrollViews["calendar-day-pane"].swipeUp() }
        XCTAssertTrue(last.isHittable); last.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["activity-title"].value as? String, "Ultimo impegno")
    }
    func testFinanceBudgetIsSmallerAndReferenceRoutesStillWork() {
        let app = launch(); app.tabBars.buttons["Finanza"].tap()
        let amount = app.staticTexts["finance-budget-value"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        XCTAssertLessThan(amount.frame.height, 65)
        XCTAssertTrue(app.buttons["finance-budget"].isHittable)
        XCTAssertTrue(app.buttons["finance-analysis"].isHittable)
        capture("72-finance-refined-hierarchy")
    }
}
