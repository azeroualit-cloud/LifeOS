import XCTest

final class NativeRevision75UITests: XCTestCase {
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.minY < app.navigationBars.firstMatch.frame.maxY
            if above { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
        }
    }
    private func selectMenu(_ button: XCUIElement, title: String, app: XCUIApplication) {
        reveal(button, app: app)
        XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap()
        let choice = app.buttons[title]
        for _ in 0..<6 {
            if choice.exists && choice.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        }
        XCTAssertTrue(choice.isHittable); choice.tap()
    }
    func testBillMonthControlsFitWithLargeText() {
        continueAfterFailure = false; executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--expense-routing", "--large-text", "--reduce-motion", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch(); XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
        app.buttons["primary-add"].tap()
        selectMenu(app.buttons["movement-category"], title: "Acqua", app: app)
        for title in ["Mese iniziale", "Mese finale"] {
            for prefix in ["utility-month-", "utility-year-"] {
                let control = app.buttons[prefix + title]; reveal(control, app: app)
                XCTAssertTrue(control.isHittable)
                XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
            }
            let label = app.staticTexts[title].firstMatch
            reveal(label, app: app)
            XCTAssertGreaterThan(label.frame.height, 24, "La prova deve usare davvero testo ingrandito anche nel foglio")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "75-utility-large-text"; shot.lifetime = .keepAlways; add(shot)
    }
    func testBillPeriodShowsThreeExactSharesAndExistingPaymentCanBeEdited() {
        continueAfterFailure = false; executionTimeAllowance = 300
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "--expense-routing", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch(); XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
        app.buttons["primary-add"].tap()
        let amount = app.textFields["movement-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10)); amount.tap(); amount.typeText("221,79")
        app.textFields["movement-name"].tap(); app.textFields["movement-name"].typeText("Bolletta competenza UI75")
        app.buttons["movement-hide-keyboard"].tap()
        selectMenu(app.buttons["movement-category"], title: "Acqua", app: app)
        let start = app.buttons["utility-month-Mese iniziale"], end = app.buttons["utility-month-Mese finale"]
        for _ in 0..<8 { if start.isHittable { break }; app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        selectMenu(start, title: "Agosto", app: app); selectMenu(end, title: "Ottobre", app: app)
        let year = Calendar.current.component(.year, from: Date())
        for month in ["08", "09", "10"] {
            let row = app.descendants(matching: .any).matching(identifier: "utility-share-\(year)-" + month).firstMatch
            for _ in 0..<8 { if row.exists && row.isHittable { break }; app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            XCTAssertTrue(row.debugDescription.contains("73,93"), "La quota mostrata deve essere 73,93 €")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "75-utility-three-shares"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Salva"].tap()
        app.openOtherDestination("Finanza")
        let all = app.buttons["all-movements"]
        for _ in 0..<8 { if all.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp(velocity: .slow) }
        XCTAssertTrue(all.isHittable); all.tap()
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bolletta competenza UI75"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(rows.count, 1); rows.firstMatch.tap()
        let edit = app.buttons["movement-change-destination"]
        for _ in 0..<8 { if edit.isHittable { break }; app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        XCTAssertTrue(edit.isHittable); edit.tap()
        for _ in 0..<8 { if start.isHittable { break }; app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        XCTAssertTrue(start.isHittable)
        selectMenu(end, title: "Settembre", app: app)
        app.buttons["expense-destination-confirm"].tap()
        XCTAssertTrue(app.navigationBars["Modifica movimento"].waitForExistence(timeout: 10))
    }
}
