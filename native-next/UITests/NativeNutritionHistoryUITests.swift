import XCTest

final class NativeNutritionHistoryUITests: XCTestCase {
    func testSelectedDayPreviewDeleteAndGroupedHistoryPreserveOtherDays() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "--health-week-review", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Salute"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Salute"].tap()
        let previous = app.buttons["health-week-previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        previous.tap()
        let scroll = app.scrollViews["health-detail-scroll"]
        let meal = app.staticTexts["Pasto di prova"]
        for _ in 0..<8 where !meal.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(meal.isHittable)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Pasto di prova").count, 1, "Preview must show only the selected day's food")
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "health-diary-delete-")).firstMatch
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
        app.buttons["Annulla"].tap()
        XCTAssertTrue(meal.exists)
        remove.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.staticTexts["Nessun alimento registrato per questo giorno"].waitForExistence(timeout: 10))
        XCTAssertFalse(meal.exists)
        let history = app.buttons["health-nutrition-history"]
        for _ in 0..<4 where !history.isHittable { scroll.swipeDown(velocity: .slow) }
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars["Nutrizione"].waitForExistence(timeout: 10))
        let dayHeader = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition-history-day-")).firstMatch
        for _ in 0..<6 where !dayHeader.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(dayHeader.isHittable)
        XCTAssertTrue(app.staticTexts["Pasto di prova"].firstMatch.exists, "Deleting the selected day must preserve meals from other days")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Nutrition history grouped by day after preview deletion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
