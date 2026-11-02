import XCTest

final class NativeRevision74UITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--compact-calendar", "--active-shift", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
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
    func testHealthChartsAllowVerticalScrollAndNativeSelection() {
        let app = launch(), dashboard = app.scrollViews["dashboard-scroll"]
        let detail = app.buttons["home-health-detail"]
        for _ in 0..<12 { if detail.isHittable { break }; dashboard.swipeUp(velocity: .slow) }
        XCTAssertTrue(detail.isHittable); detail.tap()
        XCTAssertTrue(app.navigationBars["Peso e calorie"].waitForExistence(timeout: 10))
        let chart = app.descendants(matching: .any).matching(identifier: "health-weight-chart").firstMatch
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.frame.maxY + 8
            let bottom = app.tabBars.firstMatch.frame.minY - 8
            if chart.exists && chart.frame.minY >= top && chart.frame.maxY <= bottom { break }
            let above = chart.exists && chart.frame.minY < top
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.3 : 0.75))
                .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.65 : 0.4)))
        }
        XCTAssertTrue(chart.waitForExistence(timeout: 10)); XCTAssertTrue(chart.isHittable)
        XCTAssertLessThanOrEqual(chart.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let caption = app.staticTexts["health-weight-selection"]
        let before = caption.frame.height
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "label != %@", "Tocca o tieni premuto e scorri"), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(caption.frame.height, before, accuracy: 1)
        let selected = caption.label
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).press(forDuration: 0.35, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        XCTAssertNotEqual(caption.label, selected)
        let y = chart.frame.minY
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75)).press(forDuration: 0.05, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.15)))
        XCTAssertLessThan(chart.frame.minY, y - 20)
        capture("74-health-chart-selection")
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
        app.buttons["Nuova nota"].tap()
        let secondName = "Seconda nota " + UUID().uuidString.prefix(8)
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText(String(secondName))
        app.buttons["Salva"].tap()
        let second = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "bloom-note-", String(secondName))).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10)); XCTAssertTrue(note.exists)
        for name in ["map", "rediscovery", "library"] {
            let section = app.buttons["bloom-section-" + name]
            XCTAssertTrue(section.waitForExistence(timeout: 10)); section.tap()
            XCTAssertTrue(section.isSelected)
        }
        XCTAssertTrue(note.waitForExistence(timeout: 10)); XCTAssertTrue(second.exists)
        capture("74-bloom-library")
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
        print("CALENDAR_PREVIEW_FRAMES cell=\(cell.frame) viewport=\(surface.frame) state=\(surface.value ?? "none")")
        expectation(for: NSPredicate { _, _ in cell.isHittable }, evaluatedWith: cell)
        waitForExpectations(timeout: 3)
        app.buttons["calendar-expand-day"].tap()
        XCTAssertTrue(app.buttons["calendar-week-day-" + today].waitForExistence(timeout: 10))
        capture("74-calendar-month-week")
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
    }
}
