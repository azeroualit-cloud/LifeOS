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
            if open.isHittable && open.frame.maxY <= app.tabBars.firstMatch.frame.minY { break }
            dashboard.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let catalog = app.buttons["quick-nutrition-catalog"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 10))
        catalog.tap()
        XCTAssertTrue(app.textFields["generic-food-search"].waitForExistence(timeout: 10))
        return app
    }

    private func replace(_ field: XCUIElement, with text: String, app: XCUIApplication) {
        for _ in 0..<6 where !field.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(field.isHittable)
        field.tap()
        let previous = field.value as? String ?? ""
        if previous != field.placeholderValue && !previous.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
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
        app.buttons["generic-food-create"].tap()
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

    func testBrandedCapsulesAndPowderUseTheirOwnUnits() {
        let app = openCatalog()
        let search = app.textFields["generic-food-search"]
        replace(search, with: "vit4ever", app: app)
        let magnesium = app.buttons["generic-food-brand-vit4ever-magnesium-citrate"]
        XCTAssertTrue(magnesium.waitForExistence(timeout: 10))
        XCTAssertTrue(magnesium.label.contains("vit4ever"))
        XCTAssertTrue(magnesium.label.contains("non dichiarati"))
        magnesium.tap()
        let capsules = app.textFields["quick-nutrition-Capsule"]
        XCTAssertTrue(capsules.waitForExistence(timeout: 10))
        XCTAssertEqual(capsules.value as? String, "1")
        XCTAssertFalse(app.textFields["quick-nutrition-Porzione"].exists)
        let calories = app.staticTexts["quick-nutrition-calories"]
        XCTAssertEqual(calories.label, "Non dichiarate")
        XCTAssertEqual(app.staticTexts["quick-nutrition-nutrient-magnesium"].label, "Magnesio: 120 mg")
        replace(capsules, with: "2", app: app)
        XCTAssertEqual(capsules.value as? String, "2")
        XCTAssertEqual(app.staticTexts["quick-nutrition-nutrient-magnesium"].label, "Magnesio: 240 mg")
        XCTAssertEqual(calories.label, "Non dichiarate")
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        capture("Integratore di marca per singola capsula")
        app.buttons["quick-nutrition-catalog"].tap()
        replace(search, with: "Proteine whey isolate", app: app)
        let powder = app.buttons["generic-food-supplement-whey-isolate"]
        XCTAssertTrue(powder.waitForExistence(timeout: 10))
        powder.tap()
        let grams = app.textFields["quick-nutrition-Quantità"]
        XCTAssertTrue(grams.waitForExistence(timeout: 10))
        XCTAssertEqual(grams.value as? String, "30")
        XCTAssertTrue(grams.label.contains("grammi"))
        XCTAssertEqual(calories.label, "114 kcal")
        replace(grams, with: "60", app: app)
        XCTAssertEqual(calories.label, "228 kcal")
        XCTAssertFalse(app.textFields["quick-nutrition-Capsule"].exists)
        capture("Integratore in polvere pesato in grammi")
    }
}
