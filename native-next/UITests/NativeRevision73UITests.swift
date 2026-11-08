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
    func testDayOpensDirectlyAndMonthReturnsToSameWeek() {
        let app = launch()
        app.openOtherDestination("Calendario")
        let month = app.scrollViews["calendar-scroll"], today = app.buttons["calendar-day-" + day()]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        for _ in 0..<12 { if today.isHittable { break }; month.swipeUp(velocity: .slow) }
        XCTAssertTrue(today.isHittable)
        XCTAssertEqual(today.value as? String, "5 eventi")
        capture("calendar-month-event-dots")
        let origin = today.frame.midY
        today.tap()

        let agenda = app.scrollViews["calendar-day-pane"]
        XCTAssertTrue(agenda.waitForExistence(timeout: 10))
        XCTAssertFalse(month.isHittable)
        capture("calendar-dedicated-day")
        app.buttons["calendar-back-month"].tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in today.isHittable }, object: today)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        XCTAssertTrue(today.isSelected)
        XCTAssertEqual(today.frame.midY, origin, accuracy: 3)
        XCTAssertFalse(agenda.isHittable)
    }

    func testDayRemainsUsableWithLargeTextAndReducedMotion() {
        let app = launch(["--large-text", "--reduce-motion"])
        app.openOtherDestination("Calendario")
        let month = app.scrollViews["calendar-scroll"], today = app.buttons["calendar-day-" + day()]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        for _ in 0..<12 { if today.isHittable { break }; month.swipeUp(velocity: .slow) }
        XCTAssertTrue(today.isHittable); today.tap()
        let back = app.buttons["calendar-back-month"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertTrue(back.isHittable)
        let add = app.buttons["calendar-add-event"]
        XCTAssertTrue(add.isHittable)
        XCTAssertGreaterThanOrEqual(add.frame.height.rounded(), 44)
        capture("calendar-dedicated-day-large-text")
    }
}
