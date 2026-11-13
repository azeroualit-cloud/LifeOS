import XCTest

final class NativeRevision77UITests: XCTestCase {
    // Historical selector retained for existing CI smoke routing.
    func testFourTabsAndDirectHealthAndBloom() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home"]
        app.launch()
        for name in ["Dashboard", "Attività", "Salute", "Bloom", "Finanza", "Calendario"] {
            XCTAssertTrue(app.mainTabBar.buttons[name].waitForExistence(timeout: 15))
        }
        XCTAssertFalse(app.mainTabBar.buttons["Altro"].exists); XCTAssertFalse(app.mainTabBar.buttons["More"].exists)
        app.mainTabBar.buttons["Salute"].tap()
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
        capture("Salute diretta", app)
        app.openMainTab("Bloom")
        XCTAssertTrue(app.navigationBars["Bloom"].waitForExistence(timeout: 10))
        capture("Bloom", app)
        app.mainTabBar.buttons["Dashboard"].tap()
        capture("Dashboard", app)
    }
    func testLargeTextDashboardAndHealth() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--large-text", "--reduce-motion"]
        app.launch()
        XCTAssertTrue(app.scrollViews["dashboard-scroll"].waitForExistence(timeout: 15))
        capture("Dashboard testo grande", app)
        app.mainTabBar.buttons["Salute"].tap()
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
        capture("Salute testo grande", app)
    }
    func testCalendarReturnsToDashboardAndFinanceOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 15))
        day.tap()
        XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.mainTabBar.buttons["Dashboard"].isSelected)
        capture("Calendario completo", app)
        app.buttons["other-back"].tap()
        let finance = app.buttons["home-finance"]
        reveal(finance, app: app)
        finance.tap()
        XCTAssertTrue(app.scrollViews["finance-scroll"].waitForExistence(timeout: 10))
        capture("Finanza", app)
        app.buttons["other-back"].tap()
        XCTAssertTrue(app.scrollViews["dashboard-scroll"].exists)
    }
    func testCompactMacroDecimalInputAndKeyboardProgression() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--empty-home", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let open = app.buttons["quick-nutrition-open"]
        reveal(open, app: app); open.tap()
        let protein = app.textFields["quick-nutrition-Proteine"]
        XCTAssertTrue(protein.waitForExistence(timeout: 10))
        protein.tap(); protein.typeText("10")
        for (name, value) in [("Carboidrati", "0,2"), ("Grassi", "5"), ("Fibre", "8")] {
            let field = app.textFields["quick-nutrition-" + name]
            let scroll = app.scrollViews["quick-nutrition-scroll"]
            for _ in 0..<6 where !field.isHittable { scroll.swipeUp() }
            XCTAssertTrue(field.isHittable)
            field.tap()
            field.typeText(value)
        }
        app.staticTexts["Aggiungi nutrienti"].tap()
        XCTAssertEqual(app.staticTexts["quick-nutrition-calories"].label, "101,8 kcal")
        let save = app.buttons["quick-nutrition-save"]
        XCTAssertTrue(save.isEnabled)
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        capture("Macro compatti", app)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.scrollViews["dashboard-scroll"].swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
