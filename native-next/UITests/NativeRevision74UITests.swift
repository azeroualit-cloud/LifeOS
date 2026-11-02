import XCTest

final class NativeRevision74UITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFourTabsAndNutritionCalculation() {
        let app = launch()
        for name in ["Dashboard", "Attività", "Salute", "Altro"] { XCTAssertTrue(app.tabBars.buttons[name].exists) }
        XCTAssertFalse(app.tabBars.buttons["Finanza"].exists); XCTAssertFalse(app.tabBars.buttons["Calendario"].exists)
        app.tabBars.buttons["Salute"].tap()
        for (label, value) in [("Proteine", "10"), ("Carboidrati", "20"), ("Grassi", "5")] {
            let field = app.textFields["nutrition-" + label]
            XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(value)
        }
        app.buttons["Fine"].tap()
        let total = app.staticTexts["nutrition-calories-value"]
        capture("74-nutrition-calculation")
        if !total.exists { print("NUTRITION_ACCESSIBILITY " + app.debugDescription) }
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        XCTAssertEqual(total.label, "165 kcal")
        capture("74-nutrition-calculation")
    }
    func testMoreDestinationsAndBloomNotePersistsAcrossNavigation() {
        let app = launch(); app.tabBars.buttons["Altro"].tap()
        for name in ["Finanza", "Calendario", "Bloom"] { XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 10)) }
        app.buttons["Bloom"].tap()
        XCTAssertTrue(app.buttons["Nuova nota"].waitForExistence(timeout: 10)); app.buttons["Nuova nota"].tap()
        let name = "Nota test " + UUID().uuidString.prefix(8)
        let title = app.textFields["bloom-note-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText(String(name))
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 10))
        app.tabBars.buttons["Dashboard"].tap(); app.tabBars.buttons["Altro"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 10))
        capture("74-bloom-library")
    }
}
