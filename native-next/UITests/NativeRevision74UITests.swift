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
        capture("74-bloom-entry")
        let add = app.buttons["Nuova nota"]
        let ready = add.waitForExistence(timeout: 10)
        if !ready { print("BLOOM_ENTRY_DIAGNOSTIC " + app.debugDescription) }
        XCTAssertTrue(ready); add.tap()
        let name = "Nota test " + UUID().uuidString.prefix(8)
        let title = app.textFields["bloom-note-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText(String(name))
        app.buttons["Salva"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "bloom-note-", String(name))).firstMatch
        let saved = note.waitForExistence(timeout: 10)
        capture("74-bloom-library")
        if !saved { print("BLOOM_SAVE_DIAGNOSTIC " + app.debugDescription) }
        XCTAssertFalse(title.exists, "Successful save must close the editor")
        XCTAssertTrue(saved, "Saved note must be present in the library")
        app.tabBars.buttons["Dashboard"].tap(); app.tabBars.buttons["Altro"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        app.openOtherDestination("Calendario")
        let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date()), surface = app.scrollViews["calendar-scroll"]
        let cell = app.buttons["calendar-day-" + today]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        for _ in 0..<12 { if cell.isHittable { break }; surface.swipeUp(velocity: .slow) }
        XCTAssertTrue(cell.isHittable); cell.tap()
        XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
        capture("74-calendar-preview-diagnostic")
        print("CALENDAR_PREVIEW_FRAMES cell=\(cell.frame) viewport=\(surface.frame)")
        expectation(for: NSPredicate { _, _ in cell.isHittable }, evaluatedWith: cell)
        waitForExpectations(timeout: 3)
        app.buttons["calendar-expand-day"].tap()
        XCTAssertTrue(app.buttons["calendar-week-day-" + today].waitForExistence(timeout: 10))
        capture("74-calendar-month-week")
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
    }
}
