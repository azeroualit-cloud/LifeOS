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
    private func drag(_ scroll: XCUIElement, app: XCUIApplication, up: Bool, fraction: CGFloat = 1) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let bottom = min(scroll.frame.maxY, app.descendants(matching: .any).matching(identifier: "quick-nutrition-footer").firstMatch.frame.minY) - 12
        let top = scroll.frame.minY + 12
        XCTAssertGreaterThan(bottom, top)
        let start = up ? bottom : top
        let end = start + (up ? -1 : 1) * (bottom - top) * fraction
        // Start in the scroll view's gutter so a text field cannot consume the gesture.
        let gutter = scroll.frame.minX + 8
        origin.withOffset(CGVector(dx: gutter, dy: start))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: gutter, dy: end)),
                   withVelocity: .slow, thenHoldForDuration: 0.05)
    }
    private func visibleRegion(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews["quick-nutrition-scroll"].frame
        let footerTop = app.descendants(matching: .any).matching(identifier: "quick-nutrition-footer").firstMatch.frame.minY
        return CGRect(x: scroll.minX, y: scroll.minY + 1, width: scroll.width, height: max(0, min(scroll.maxY, footerTop) - scroll.minY - 2))
    }
    private func visible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let region = visibleRegion(in: app)
        let frame = element.frame
        return frame.minY >= region.minY && frame.maxY <= region.maxY
    }
    private func fill(_ app: XCUIApplication) {
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for (label, value) in [("Proteine", "25"), ("Carboidrati", "40"), ("Grassi", "10"), ("Fibre", "6")] {
            let field = app.textFields["quick-nutrition-" + label]
            for _ in 0..<8 {
                if visible(field, in: app) { break }
                let up = !field.exists || field.frame.midY >= visibleRegion(in: app).midY
                drag(scroll, app: app, up: up, fraction: 0.5)
            }
            if !visible(field, in: app) { capture("Nutrition keyboard: \(label) not fully visible", app) }
            XCTAssertTrue(visible(field, in: app),
                          "\(label) must be above the pinned action and keyboard: field \(field.frame), viewport \(visibleRegion(in: app))")
            XCTAssertTrue(field.isHittable); field.tap(); field.typeText(value)
        }
    }
    func testRenderCocktailAndBoneInPortions() {
        let app = open()
        app.buttons["quick-nutrition-catalog"].tap()
        XCTAssertFalse(app.buttons["Cocktail"].exists)
        XCTAssertTrue(app.buttons["Personali"].exists)
        let initialSearch = app.textFields["generic-food-search"]
        XCTAssertTrue(initialSearch.waitForExistence(timeout: 10))
        initialSearch.tap()
        initialSearch.typeText("Gin Tonic")
        let gin = app.buttons["generic-food-cocktail-gin-tonic"]
        XCTAssertTrue(gin.waitForExistence(timeout: 5))
        capture("01 Cocktail catalog", app)
        gin.tap()
        let alcohol = app.staticTexts["quick-nutrition-alcohol"]
        XCTAssertTrue(alcohol.waitForExistence(timeout: 5))
        XCTAssertTrue(alcohol.label.contains("1,3 UA"))
        capture("02 Cocktail portion and estimated alcohol", app)

        app.buttons["quick-nutrition-catalog"].tap()
        let search = app.textFields["generic-food-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Sovracoscia di pollo al forno con pelle")
        let cut = app.buttons["generic-food-estimate-sovracoscia-forno-pelle"]
        XCTAssertTrue(cut.waitForExistence(timeout: 5))
        cut.tap()
        let weighing = app.buttons["quick-nutrition-weighing"]
        XCTAssertTrue(weighing.waitForExistence(timeout: 5))
        weighing.tap()
        app.buttons["Con osso"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Parte edibile stimata")).firstMatch.waitForExistence(timeout: 5))
        capture("03 Chicken cut weighed with bone", app)
    }

    func testRenderPersonalFoodEditorAndSave() {
        let app = open()
        app.buttons["quick-nutrition-catalog"].tap()
        let create = app.buttons["generic-food-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        let name = app.textFields["personal-food-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        capture("04 Personal food editor", app)
        let title = "Crema di prova \(UUID().uuidString.prefix(4))"
        for (id, value) in [("name", title), ("energy", "200"), ("protein", "10"), ("carbs", "20"), ("fat", "8")] {
            let field = app.textFields["personal-food-" + id]
            for _ in 0..<3 where !field.isHittable { app.swipeUp() }
            XCTAssertTrue(field.isHittable, id)
            field.tap()
            field.typeText(value)
        }
        let save = app.buttons["personal-food-save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
        capture("05 Saved personal foods", app)
    }

    func testSupermarketFoodsAndSupplementEditor() {
        let app = open()
        app.buttons["quick-nutrition-catalog"].tap()
        let search = app.textFields["generic-food-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        for name in ["Crescenza", "Provolone", "Patatine", "Gelato", "Vitamina C"] {
            search.tap()
            let value = search.value as? String ?? ""
            if value != "Cerca alimento" {
                search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
            }
            search.typeText(name)
            capture("Supermercato " + name, app)
        }
        XCTAssertFalse(app.buttons["Integratori"].exists)
        let vitamin = app.buttons["generic-food-supplement-vitamin-c"]
        XCTAssertTrue(vitamin.isHittable)
        vitamin.tap()
        XCTAssertTrue(app.staticTexts["Dosi"].waitForExistence(timeout: 10))
        capture("Integratore generico da Tutti", app)
        app.buttons["quick-nutrition-catalog"].tap()
        app.buttons["generic-food-create"].tap()
        let family = app.buttons["personal-food-family"]
        XCTAssertTrue(family.waitForExistence(timeout: 10))
        family.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Integratori")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Valori per dose"].exists)
        for (id, value) in [("name", "Integratore di prova"), ("energy", "0"), ("protein", "0"), ("carbs", "0"), ("fat", "0")] {
            let field = app.textFields["personal-food-" + id]
            for _ in 0..<3 where !field.isHittable { app.swipeUp() }
            field.tap()
            field.typeText(value)
        }
        capture("Integratore per dose", app)
        app.buttons["personal-food-save"].tap()
        let item = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "generic-food-personal-", "Integratore di prova")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.tap()
        XCTAssertTrue(app.staticTexts["Dosi"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
        capture("Aggiunta integratore senza calorie", app)
        app.buttons["quick-nutrition-save"].tap()
        XCTAssertTrue(app.buttons["quick-nutrition-open"].waitForExistence(timeout: 10))
    }

    func testDatePickerOpensFullWidthAndKeepsNutrients() {
        checkFullWidthDatePicker(large: false)
    }

    func testDatePickerOpensFullWidthWithLargeTextAndKeepsNutrients() {
        checkFullWidthDatePicker(large: true)
    }

    private func checkFullWidthDatePicker(large: Bool) {
        let app = open(large: large)
        fill(app)
        app.staticTexts["Aggiungi nutrienti"].tap()
        let date = app.buttons["quick-nutrition-date"]
        let scroll = app.scrollViews["quick-nutrition-scroll"]
        for _ in 0..<8 where !visible(date, in: app) { drag(scroll, app: app, up: true) }
        XCTAssertTrue(visible(date, in: app))
        date.tap()

        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(picker.frame.width, app.frame.width * 0.8)
        XCTAssertGreaterThanOrEqual(picker.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(picker.frame.maxX, app.frame.maxX)
        capture(large ? "Nutrition full-width date large text" : "Nutrition full-width date", app)
        app.buttons["quick-nutrition-date-done"].tap()
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["quick-nutrition-calories"].label, "362 kcal")
        XCTAssertTrue(app.buttons["quick-nutrition-save"].isEnabled)
    }

    func testSearchFindsGenericBiscottiAndUsesItsPortion() {
        let app = open()
        app.buttons["quick-nutrition-catalog"].tap()
        let search = app.textFields["generic-food-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Biscotti")
        let biscuits = app.buttons["generic-food-ciqual-24001"]
        XCTAssertTrue(biscuits.waitForExistence(timeout: 5))
        XCTAssertTrue(biscuits.isHittable)
        capture("Generic food search for Biscotti", app)
        biscuits.tap()
        XCTAssertTrue(app.staticTexts["Generic"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["quick-nutrition-calories"].label, "438 kcal")
    }
    func testQuickSheetCalculatesAndSavesThenResets() {
        let app = open()
        XCTAssertFalse(app.buttons["quick-nutrition-save"].isEnabled)
        fill(app)
        let save = app.buttons["quick-nutrition-save"]
        XCTAssertFalse(app.buttons["Avanti"].exists)
        XCTAssertFalse(app.buttons["quick-nutrition-keyboard-done"].exists)
        XCTAssertTrue(app.buttons["quick-nutrition-catalog"].isHittable)
        XCTAssertTrue(save.isHittable); XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        capture("Nutrition approved panel keyboard", app)
        app.staticTexts["Aggiungi nutrienti"].tap()
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
        app.staticTexts["Aggiungi nutrienti"].tap()
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
