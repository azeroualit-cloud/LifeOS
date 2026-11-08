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
        for name in ["Dashboard", "Attività", "Salute", "Bloom"] { XCTAssertTrue(app.tabBars.buttons[name].exists) }
        XCTAssertFalse(app.tabBars.buttons["Finanza"].exists); XCTAssertFalse(app.tabBars.buttons["Calendario"].exists)
        app.tabBars.buttons["Salute"].tap()
        let add = app.buttons["health-add-nutrition"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        for _ in 0..<6 where !add.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
        XCTAssertTrue(add.isHittable); add.tap()
        XCTAssertTrue(app.staticTexts["Aggiungi nutrienti"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quick-nutrition-save"].isEnabled)
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for (label, value) in [("Proteine", "10"), ("Carboidrati", "20"), ("Grassi", "5"), ("Fibre", "1")] {
            let field = app.textFields["quick-nutrition-" + label]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            for _ in 0..<5 where !field.isHittable { scroll.swipeUp() }
            XCTAssertTrue(field.isHittable); field.tap(); field.typeText(value)
        }
        app.staticTexts["Aggiungi nutrienti"].tap()
        let total = app.staticTexts["quick-nutrition-calories"]
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        capture("74-nutrition-calculation")
        if !total.exists { print("NUTRITION_ACCESSIBILITY " + app.debugDescription) }
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        XCTAssertEqual(total.label, "167 kcal")
        capture("74-nutrition-calculation")
    }
    func testHealthChartsAllowVerticalScrollAndNativeSelection() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        XCTAssertTrue(app.navigationBars["Salute"].waitForExistence(timeout: 10))
        app.buttons["health-summary-weight"].tap()
        // The compact metric detail fits on screen. Expand its real method
        // content to exercise vertical scrolling while dragging over the chart.
        let method = app.buttons["health-method-disclosure"]
        XCTAssertTrue(method.waitForExistence(timeout: 10)); method.tap()
        let chart = app.descendants(matching: .any).matching(identifier: "health-weight-chart").firstMatch
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.frame.maxY + 8
            let bottom = app.tabBars.firstMatch.frame.minY - 8
            if chart.exists && chart.frame.minY >= top && chart.frame.maxY + 64 <= bottom { break }
            let above = chart.exists && chart.frame.minY < top
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.3 : 0.75))
                .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.65 : 0.4)))
        }
        XCTAssertTrue(chart.waitForExistence(timeout: 10)); XCTAssertTrue(chart.isHittable)
        XCTAssertLessThanOrEqual(chart.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let caption = app.staticTexts["health-weight-selection"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        let before = caption.frame.height
        print("CHART_BEFORE_TAP frame=\(chart.frame) caption=\(caption.frame) surface=\(surface.frame)")
        capture("75-health-chart-before-tap")
        print("CHART_ACCESSIBILITY_SYNTHETIC " + app.debugDescription)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "label != %@", "Tocca o tieni premuto e scorri"), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(caption.frame.height, before, accuracy: 1)
        let selected = caption.label
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).press(forDuration: 0.35, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        XCTAssertNotEqual(caption.label, selected)
        let y = chart.frame.minY
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75)).press(forDuration: 0.05, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.15)))
        capture("74-health-chart-selection")
        print("HEALTH_CHART_SCROLL before=\(y) after=\(chart.frame.minY) caption=\(caption.label) state=\(surface.value ?? "none")")
        XCTAssertLessThan(chart.frame.minY, y - 20)
    }
    func testMoreDestinationsAndBloomNotePersistsAcrossNavigation() {
        let app = launch(); app.tabBars.buttons["Bloom"].tap()
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
        app.tabBars.buttons["Dashboard"].tap(); app.tabBars.buttons["Bloom"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        app.openOtherDestination("Calendario")
        let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date()), surface = app.scrollViews["calendar-scroll"]
        let cell = app.buttons["calendar-day-" + today]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        for _ in 0..<12 { if cell.isHittable { break }; surface.swipeUp(velocity: .slow) }
        XCTAssertTrue(cell.isHittable); cell.tap()
        XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["calendar-day-heading"].exists)
        XCTAssertFalse(surface.isHittable)
        capture("74-calendar-dedicated-day")
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
    }
}
