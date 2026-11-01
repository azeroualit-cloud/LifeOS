import XCTest

final class NativeRevision73UITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--compact-calendar", "--active-shift", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + extra
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
        return app
    }
    private func day() -> String {
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: "Europe/Rome"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func testSelectingDayKeepsMonthVisibleAndExpansionIsExplicit() {
        let app = launch()
        capture("73-dashboard-alignment")
        app.tabBars.buttons["Calendario"].tap()
        let month = app.scrollViews["calendar-scroll"], today = app.buttons["calendar-day-" + day()]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        for _ in 0..<12 { if today.isHittable { break }; month.swipeUp(velocity: .slow) }
        XCTAssertTrue(today.isHittable); today.tap()
        let agenda = app.scrollViews["calendar-day-pane"]
        XCTAssertTrue(agenda.waitForExistence(timeout: 10))
        XCTAssertTrue(month.exists); XCTAssertTrue(month.isHittable)
        XCTAssertTrue(today.isSelected)
        XCTAssertGreaterThan(agenda.frame.height, 100)
        XCTAssertGreaterThanOrEqual(agenda.frame.minY, month.frame.maxY)
        XCTAssertFalse(app.buttons["calendar-back-month"].exists)
        capture("73-inline-calendar-agenda")
        app.buttons["calendar-close-preview"].tap()
        XCTAssertFalse(agenda.exists); XCTAssertTrue(month.isHittable)
        today.tap(); app.buttons["calendar-expand-day"].tap()
        XCTAssertTrue(app.buttons["calendar-back-month"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-week-day-")).count, 7)
        capture("73-expanded-colour-agenda")
    }
    func testInlineAgendaRemainsUsableWithLargeTextAndReducedMotion() {
        let app = launch(["--large-text", "--reduce-motion"])
        app.tabBars.buttons["Calendario"].tap()
        let month = app.scrollViews["calendar-scroll"], today = app.buttons["calendar-day-" + day()]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        for _ in 0..<12 { if today.isHittable { break }; month.swipeUp(velocity: .slow) }
        today.tap()
        XCTAssertTrue(app.buttons["calendar-expand-day"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendar-close-preview"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["calendar-expand-day"].frame.height.rounded(), 44)
        capture("73-inline-large-text")
    }
}
