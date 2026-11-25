import XCTest

final class NativePersonalFoodUITests: XCTestCase {
    private func openCatalog() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--empty-home", "--dark", "--nutrition-ui-fixture", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let open = app.buttons["quick-nutrition-open"]
        let dashboard = app.scrollViews["dashboard-scroll"]
        for _ in 0..<8 {
            if open.isHittable && open.frame.maxY <= app.mainTabBar.frame.minY { break }
            dashboard.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(open.isHittable)
        open.tap()
        // FOOD-QUICK-ADD-2026-11-23: the search opens directly (quick sheet: «food-quick-*» identifiers).
        XCTAssertTrue(app.textFields["food-quick-search"].waitForExistence(timeout: 10))
        return app
    }

    private func replace(_ field: XCUIElement, with text: String, app: XCUIApplication) {
        for _ in 0..<6 where !field.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(field.isHittable)
        let catalogSearch = field.identifier == "generic-food-search"
        field.tap()
        if catalogSearch {
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
            XCTAssertTrue(field.waitForExistence(timeout: 10), "Opening the keyboard must keep the catalog search sheet presented")
            XCTAssertTrue(field.isHittable)
        }
        let previous = field.value as? String ?? ""
        if previous != field.placeholderValue && !previous.isEmpty {
            // A tap may place the caret before an existing numeric value.
            field.press(forDuration: 1.1)
            let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["Seleziona tutto", "Select All"])).firstMatch
            if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
            else {
                let end = field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
                end.tap()
            }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: field)
        let complete = XCTWaiter.wait(for: [entered], timeout: 10) == .completed
        if !complete {
            capture("Incomplete text input diagnostic")
            print("INCOMPLETE_INPUT_TREE " + app.debugDescription)
        }
        XCTAssertTrue(complete, "Replacement must finish before checking Save: " + (field.value as? String ?? "nil"))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func personalRow(named name: String, app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "generic-food-personal-", name))
    }

    func testEditingPersonalFoodKeepsIdentityAndUpdatesPortion() {
        let app = openCatalog()
        app.buttons["food-quick-create"].tap()
        let suffix = String(UUID().uuidString.prefix(6))
        let originalName = "Crema iniziale " + suffix
        let editedName = "Crema aggiornata " + suffix
        XCTAssertTrue(app.textFields["personal-food-name"].waitForExistence(timeout: 10))
        for (field, value) in [("name", originalName), ("energy", "200"), ("protein", "10"), ("carbs", "20"), ("fat", "8")] {
            replace(app.textFields["personal-food-" + field], with: value, app: app)
        }
        let save = app.buttons["personal-food-save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let created = personalRow(named: originalName, app: app).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 10))
        let identifier = created.identifier
        created.swipeLeft()
        if !app.textFields["personal-food-name"].exists {
            app.buttons.matching(NSPredicate(format: "label == %@", "Modifica")).firstMatch.tap()
        }
        let name = app.textFields["personal-food-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.value as? String, originalName)
        replace(name, with: editedName, app: app)
        replace(app.textFields["personal-food-energy"], with: "300", app: app)
        capture("Alimento personale modificato prima del salvataggio")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let updated = app.buttons[identifier]
        let renamed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", editedName), object: updated)
        XCTAssertEqual(XCTWaiter.wait(for: [renamed], timeout: 10), .completed)
        XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1)
        XCTAssertEqual(personalRow(named: editedName, app: app).count, 1)
        XCTAssertEqual(personalRow(named: originalName, app: app).count, 0)
        capture("Alimento personale aggiornato senza duplicati")
        updated.tap()
        let calories = app.staticTexts["quick-nutrition-calories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 10))
        XCTAssertEqual(calories.label, "300 kcal")
        replace(app.textFields["quick-nutrition-Porzione"], with: "50", app: app)
        XCTAssertEqual(calories.label, "150 kcal")
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        capture("Porzione del personale modificato")
    }

    func testSupplementTabSeparatesFoodsAndSearchesKnownBrands() {
        let app = openCatalog()
        let search = app.textFields["food-quick-search"]
        app.segmentedControls.buttons["Integratori"].tap()
        // SUPPLEMENTS-PERSONAL-ONLY-92: no preset supplement, only the user's own.
        for query in ["vit4ever", "Proteine whey", "Vitamina C"] {
            replace(search, with: query, app: app)
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT identifier BEGINSWITH %@ AND NOT identifier IN %@", "generic-food-", "generic-food-personal-", ["generic-food-create", "generic-food-search", "generic-food-scope"])).firstMatch.exists, "Preset supplement for " + query)
        }
        XCTAssertTrue(app.buttons["food-quick-create"].exists)
        capture("Scheda Integratori con sole voci personali")
        app.segmentedControls.buttons["Tutti"].tap()
        // FOOD-DB-RESET-2026-11-25: the base replaces the branded catalogs; a food with versions is one row.
        replace(search, with: "Coscia", app: app)
        let thigh = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@", "generic-food-base-", "varianti")).firstMatch
        XCTAssertTrue(thigh.waitForExistence(timeout: 10))
        capture("Base: una riga per alimento con le varianti")
    }

}
