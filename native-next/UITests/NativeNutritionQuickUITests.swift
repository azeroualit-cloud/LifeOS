import XCTest

final class NativeNutritionQuickUITests: XCTestCase {
    private func open(large: Bool = false, failure: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--empty-home", "--dark", "--nutrition-ui-fixture", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + (large ? ["--large-text"] : []) + (failure ? ["--nutrition-write-failure"] : [])
        app.launch()
        let button = app.buttons["quick-nutrition-open"]
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.scrollViews["dashboard-scroll"].swipeUp(velocity: .slow)
        }
        XCTAssertTrue(button.isHittable)
        XCTAssertFalse(app.textFields["quick-nutrition-Proteine"].exists)
        capture("Nutrition dashboard quick action", app)
        button.tap()
        XCTAssertTrue(app.textFields["quick-nutrition-Proteine"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func fill(_ app: XCUIApplication) {
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for (label, value) in [("Proteine", "25"), ("Carboidrati", "40"), ("Grassi", "10"), ("Fibre", "6")] {
            let field = app.textFields["quick-nutrition-" + label]
            for _ in 0..<5 {
                if field.isHittable { break }
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let bottom = min(scroll.frame.maxY, app.buttons["quick-nutrition-save"].frame.minY) - 12
                let top = scroll.frame.minY + 12
                XCTAssertGreaterThan(bottom, top)
                origin.withOffset(CGVector(dx: scroll.frame.midX, dy: bottom)).press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: scroll.frame.midX, dy: top)))
            }
            XCTAssertTrue(field.isHittable); field.tap(); field.typeText(value)
        }
    }
    func testQuickSheetCalculatesAndSavesThenResets() {
        let app = open()
        XCTAssertFalse(app.buttons["quick-nutrition-save"].isEnabled)
        fill(app)
        let save = app.buttons["quick-nutrition-save"]
        XCTAssertTrue(save.isHittable); XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        capture("Nutrition approved panel keyboard", app)
        app.buttons["quick-nutrition-keyboard-done"].tap()
        XCTAssertEqual(app.staticTexts["quick-nutrition-calories"].label, "362 kcal")
        XCTAssertFalse(app.textFields["quick-nutrition-Porzione effettiva"].exists)
        XCTAssertFalse(app.textFields["quick-nutrition-Calorie"].exists)
        capture("Nutrition approved panel", app)
        save.tap()
        XCTAssertTrue(app.staticTexts["quick-nutrition-notice"].waitForExistence(timeout: 15))
        app.buttons["quick-nutrition-open"].tap()
        XCTAssertTrue(app.textFields["quick-nutrition-Proteine"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quick-nutrition-save"].isEnabled)
    }
    func testLargeTextErrorKeepsValuesAndRetryCompletes() {
        let app = open(large: true, failure: true)
        fill(app)
        app.buttons["quick-nutrition-keyboard-done"].tap()
        app.buttons["quick-nutrition-save"].tap()
        let error = app.staticTexts["quick-nutrition-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        XCTAssertEqual(app.textFields["quick-nutrition-Proteine"].value as? String, "25")
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        capture("Nutrition large text recoverable error", app)
        app.buttons["quick-nutrition-save"].tap()
        XCTAssertTrue(app.staticTexts["quick-nutrition-notice"].waitForExistence(timeout: 15))
    }
}
