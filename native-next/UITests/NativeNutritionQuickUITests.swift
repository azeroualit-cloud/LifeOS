import XCTest

final class NativeNutritionQuickUITests: XCTestCase {
    private func open(large: Bool = false, failure: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--empty-home", "--dark", "--nutrition-ui-fixture", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + (large ? ["--large-text"] : []) + (failure ? ["--nutrition-write-failure"] : [])
        app.launch()
        let button = app.buttons["quick-nutrition-open"]
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<8 {
            if button.isHittable && button.frame.maxY <= tabBar.frame.minY { break }
            app.scrollViews["dashboard-scroll"].swipeUp(velocity: .slow)
        }
        XCTAssertTrue(button.isHittable)
        XCTAssertLessThanOrEqual(button.frame.maxY, tabBar.frame.minY)
        XCTAssertFalse(app.textFields["quick-nutrition-Proteine"].exists)
        capture("Nutrition dashboard quick action", app)
        button.tap()
        let protein = app.textFields["quick-nutrition-Proteine"], carbs = app.textFields["quick-nutrition-Carboidrati"]
        XCTAssertTrue(protein.waitForExistence(timeout: 10)); XCTAssertTrue(carbs.waitForExistence(timeout: 10))
        if large { XCTAssertEqual(protein.frame.minX, carbs.frame.minX, accuracy: 1, "Accessibility layout must use one column") }
        else { XCTAssertGreaterThan(carbs.frame.minX, protein.frame.maxX, "Standard layout must use two columns") }
        capture(large ? "Nutrition accessibility sheet initial" : "Nutrition standard sheet initial", app)
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screen.name = name + " full screen"; screen.lifetime = .keepAlways; add(screen)
    }
    private func drag(_ scroll: XCUIElement, app: XCUIApplication, up: Bool) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let bottom = min(scroll.frame.maxY, app.descendants(matching: .any).matching(identifier: "quick-nutrition-footer").firstMatch.frame.minY) - 12
        let top = scroll.frame.minY + 12
        XCTAssertGreaterThan(bottom, top)
        origin.withOffset(CGVector(dx: scroll.frame.midX, dy: up ? bottom : top)).press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: scroll.frame.midX, dy: up ? top : bottom)))
    }
    private func visible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let scroll = app.scrollViews["quick-nutrition-scroll"].frame
        let bottom = min(scroll.maxY, app.descendants(matching: .any).matching(identifier: "quick-nutrition-footer").firstMatch.frame.minY)
        let frame = element.frame
        return frame.minY >= scroll.minY + 1 && frame.maxY <= bottom - 1
    }
    private func fill(_ app: XCUIApplication) {
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for (label, value) in [("Proteine", "25"), ("Carboidrati", "40"), ("Grassi", "10"), ("Fibre", "6")] {
            let field = app.textFields["quick-nutrition-" + label]
            for _ in 0..<6 {
                if visible(field, in: app) { break }
                drag(scroll, app: app, up: true)
            }
            XCTAssertTrue(visible(field, in: app), "Input must be above the pinned action and keyboard")
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
        let hiddenKeyboard = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !app.keyboards.firstMatch.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [hiddenKeyboard], timeout: 5), .completed)
        // Capture once the keyboard/layout transition has had a separate render turn.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        capture("Nutrition approved panel stable", app)
        save.tap()
        XCTAssertTrue(app.staticTexts["quick-nutrition-notice"].waitForExistence(timeout: 15))
        app.buttons["quick-nutrition-open"].tap()
        XCTAssertTrue(app.textFields["quick-nutrition-Proteine"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quick-nutrition-save"].isEnabled)
    }
    func testLargeTextCaloriesRemainReadableAboveActionWithKeyboard() {
        let app = open(large: true)
        fill(app)
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        let summary = app.descendants(matching: .any).matching(identifier: "quick-nutrition-calorie-summary").firstMatch
        let value = app.staticTexts["quick-nutrition-calories"]
        let save = app.buttons["quick-nutrition-save"]
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        for _ in 0..<8 {
            if visible(summary, in: app) { break }
            drag(scroll, app: app, up: true)
        }
        XCTAssertTrue(visible(summary, in: app), "The entire calorie summary must be reachable above the pinned action with the keyboard open")
        XCTAssertTrue(visible(value, in: app))
        XCTAssertEqual(value.label, "362 kcal")
        XCTAssertLessThanOrEqual(summary.frame.maxY, save.frame.minY)
        XCTAssertTrue(save.isHittable)
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        capture("Nutrition accessibility calories above action", app)
    }
    func testLargeTextErrorKeepsValuesAndRetryCompletes() {
        let app = open(large: true, failure: true)
        fill(app)
        XCTAssertLessThanOrEqual(app.buttons["quick-nutrition-save"].frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        capture("Nutrition accessibility keyboard", app)
        app.buttons["quick-nutrition-keyboard-done"].tap()
        app.buttons["quick-nutrition-save"].tap()
        let error = app.staticTexts["quick-nutrition-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        let protein = app.descendants(matching: .any).matching(identifier: "quick-nutrition-Proteine").firstMatch
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for _ in 0..<6 {
            if visible(protein, in: app) { break }
            drag(scroll, app: app, up: false)
        }
        let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "Pending nutrition accessibility hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        capture("Nutrition pending values after scrolling", app)
        XCTAssertTrue(visible(protein, in: app), app.debugDescription)
        XCTAssertEqual((protein.value as? String) ?? protein.label, "25")
        XCTAssertTrue(app.scrollViews["quick-nutrition-scroll"].exists, "Reading back values must not dismiss a pending entry")
        XCTAssertGreaterThanOrEqual(error.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(error.frame.maxY, app.buttons["quick-nutrition-save"].frame.minY)
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        capture("Nutrition large text recoverable error stable", app)
        app.buttons["quick-nutrition-save"].tap()
        XCTAssertTrue(app.staticTexts["quick-nutrition-notice"].waitForExistence(timeout: 15))
    }
}
