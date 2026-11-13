import XCTest

final class NativeNavigationUITests: XCTestCase {
    func testCalendarFinanceAndOverflowRemainReachable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        for name in ["Dashboard", "Calendario", "Finanza", "Salute"] {
            XCTAssertTrue(app.tabBars.buttons[name].waitForExistence(timeout: 15))
        }
        capture("Barra con Calendario e Finanza")

        app.openMainTab("Calendario")
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 15))
        let paint = app.buttons["toggle-shift-paint"]
        XCTAssertTrue(paint.waitForExistence(timeout: 10))
        XCTAssertEqual(paint.label, "Dipingi turni")
        paint.tap()
        XCTAssertTrue(app.scrollViews["shift-brush-scroll"].waitForExistence(timeout: 10))
        XCTAssertEqual(paint.label, "Fine")
        capture("Calendario e nuova icona turni")
        paint.tap()
        app.buttons["other-back"].tap()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].isSelected)

        app.openMainTab("Finanza")
        XCTAssertTrue(app.scrollViews["finance-scroll"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["primary-add"].isHittable)
        capture("Finanza dalla barra inferiore")
        app.buttons["other-back"].tap()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].isSelected)

        app.openMainTab("Attività")
        XCTAssertTrue(app.navigationBars["Attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["primary-add"].isHittable)
        app.openMainTab("Bloom")
        XCTAssertTrue(app.navigationBars["Bloom"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.isMainTabSelected("Bloom"))
        capture("Bloom raggiungibile da Altro")

        app.openMainTab("Salute")
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
