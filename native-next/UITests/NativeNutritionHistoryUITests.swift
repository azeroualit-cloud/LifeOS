import XCTest

final class NativeNutritionHistoryUITests: XCTestCase {
    func testSelectedDayPreviewDeleteAndGroupedHistoryPreserveOtherDays() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "--health-week-review", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.mainTabBar.buttons["Salute"].waitForExistence(timeout: 20))
        app.mainTabBar.buttons["Salute"].tap()
        let previous = app.buttons["health-week-previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        previous.tap()
        let scroll = app.scrollViews["health-detail-scroll"]
        let meal = app.staticTexts["Pasto di prova"]
        for _ in 0..<8 where !meal.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(meal.isHittable)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Pasto di prova").count, 1, "Preview must show only the selected day's food")
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "health-diary-delete-")).firstMatch
        // The delete button must also clear the floating «Peso / Alimento» bar, which isHittable does not see.
        let bar = app.buttons["health-add-nutrition"]
        for _ in 0..<6 where remove.exists && bar.exists && remove.frame.maxY > bar.frame.minY - 4 { scroll.swipeUp(velocity: .slow) }
        guard remove.waitForExistence(timeout: 10), remove.isHittable else {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Diary delete control diagnostic"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            let frame = XCTAttachment(screenshot: app.screenshot())
            frame.name = "Diary delete control unavailable"; frame.lifetime = .keepAlways; add(frame)
            XCTFail("The selected LifeOS food must expose its delete button")
            return
        }
        remove.tap()
        let confirmation = app.buttons["Elimina da LifeOS e Apple Salute"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        let cancel = app.buttons["Annulla"]
        if cancel.exists { cancel.tap() }
        else {
            let outside = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(outside.waitForExistence(timeout: 5))
            outside.tap()
        }
        XCTAssertTrue(meal.exists)
        remove.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.staticTexts["Nessun alimento registrato per questo giorno"].waitForExistence(timeout: 10))
        XCTAssertFalse(meal.exists)
        let history = app.buttons["health-nutrition-history"]
        // SALUTE-SINGLE-ENTRY-2026-11-26: Cronologia is in «Sezioni», below the diary.
        let bottomBar = app.buttons["health-add-nutrition"]
        for _ in 0..<8 where !history.isHittable || (bottomBar.exists && history.frame.maxY > bottomBar.frame.minY - 4) { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars["Cronologia"].waitForExistence(timeout: 10))
        let dayHeader = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition-history-day-")).firstMatch
        for _ in 0..<6 where !dayHeader.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(dayHeader.isHittable)
        XCTAssertTrue(app.staticTexts["Pasto di prova"].firstMatch.exists, "Deleting the selected day must preserve meals from other days")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Nutrition history grouped by day after preview deletion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// FOOD-LOG-EDIT-2026-11-25: tapping a diary row opens Modifica; +10 g and Salva update the same row.
    func testDiaryRowEditsQuantityWithoutDeleting() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "--health-week-review", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.mainTabBar.buttons["Salute"].waitForExistence(timeout: 20))
        app.mainTabBar.buttons["Salute"].tap()
        let scroll = app.scrollViews["health-detail-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let meal = app.staticTexts["Pasto di prova"]
        let bar = app.buttons["health-add-nutrition"]
        for _ in 0..<8 where !meal.isHittable || (bar.exists && meal.frame.maxY > bar.frame.minY - 4) { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(meal.isHittable)
        meal.tap()
        let quantity = app.textFields["food-edit-quantity"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 10))
        XCTAssertEqual(quantity.value as? String, "300")
        XCTAssertFalse(app.buttons["food-edit-save"].isEnabled, "nothing changed yet")
        app.buttons["food-edit-step-plus-10"].tap()
        XCTAssertEqual(quantity.value as? String, "310")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Modifica alimento"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.buttons["food-edit-save"].isEnabled)
        app.buttons["food-edit-save"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: quantity); waitForExpectations(timeout: 10)
        let updated = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "310 g")).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 10), "the same diary row shows the new grams")
        XCTAssertEqual(app.staticTexts.matching(identifier: "Pasto di prova").count, 1, "edited, not duplicated")
    }
}
