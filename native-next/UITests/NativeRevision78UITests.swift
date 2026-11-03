import XCTest

final class NativeRevision78UITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + extra
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 20))
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testPrayerSharesDateRowAndOpensAllTimes() {
        let app = launch()
        for button in [app.buttons["Impostazioni"], app.buttons["primary-add"]] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertLessThanOrEqual(button.frame.width, 48)
            XCTAssertLessThanOrEqual(button.frame.height, 48)
        }
        let date = app.staticTexts["home-today"], prayer = app.buttons["home-next-time"]
        XCTAssertTrue(prayer.waitForExistence(timeout: 10))
        XCTAssertNotNil((prayer.value as? String)?.range(of: "^[0-9]{2}:[0-9]{2}$", options: .regularExpression))
        XCTAssertLessThan(prayer.frame.minX, app.frame.maxX)
        XCTAssertGreaterThan(prayer.frame.midX, date.frame.midX)
        XCTAssertLessThan(abs(prayer.frame.midY - date.frame.midY), 20)
        XCTAssertLessThan(prayer.frame.width, app.frame.width / 3)
        prayer.tap()
        XCTAssertTrue(app.navigationBars["Orari"].waitForExistence(timeout: 10))
        capture("78-prayers", app)
    }
    func testFinanceBudgetAndThumbActionUseTheSameRow() {
        let app = launch()
        let button = app.buttons["home-add-expense"]
        for _ in 0..<15 {
            if button.exists && button.isHittable { break }
            app.scrollViews["dashboard-scroll"].swipeUp(velocity: .slow)
        }
        XCTAssertTrue(button.isHittable)
        let value = app.staticTexts["home-budget-value"], label = app.staticTexts["home-budget-label"]
        let header = app.buttons["home-finance"]
        XCTAssertTrue(value.exists); XCTAssertTrue(label.exists)
        XCTAssertEqual(label.label, "Budget")
        XCTAssertEqual(value.frame.minX, label.frame.minX, accuracy: 1)
        XCTAssertLessThanOrEqual(value.frame.maxY, label.frame.minY)
        XCTAssertGreaterThan(button.frame.minX, value.frame.maxX)
        XCTAssertLessThanOrEqual(button.frame.maxX, header.frame.maxX + 1)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        capture("78-dashboard-budget-action", app)
        button.tap()
        XCTAssertTrue(app.textFields["movement-amount"].waitForExistence(timeout: 10))
    }
    func testHealthUniformRowsAndCompactActions() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        let rows = ["tdee", "weight", "calories", "simulation"].map { app.buttons["health-summary-" + $0] }
        for row in rows { XCTAssertTrue(row.waitForExistence(timeout: 10)) }
        let height = rows[0].frame.height
        for row in rows { XCTAssertEqual(row.frame.height, height, accuracy: 1) }
        for id in ["health-add-weight", "health-add-nutrition"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertLessThanOrEqual(button.frame.width, 48)
            XCTAssertLessThanOrEqual(button.frame.height, 48)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        XCTAssertFalse(app.buttons["health-connect"].exists)
        XCTAssertFalse(app.staticTexts["Fonte delle calorie"].exists)
        capture("78-health-summary", app)
        rows[3].tap()
        XCTAssertTrue(app.textFields["health-intake"].waitForExistence(timeout: 10))
        capture("78-simulation-detail", app)
    }
    func testHealthAccessibleRowsRemainEqualAndActionsStayCompact() {
        let app = launch(["--large-text"])
        app.tabBars.buttons["Salute"].tap()
        let rows = ["tdee", "weight", "calories", "simulation"].map { app.buttons["health-summary-" + $0] }
        for row in rows { XCTAssertTrue(row.waitForExistence(timeout: 10)) }
        let height = rows[0].frame.height
        for row in rows { XCTAssertEqual(row.frame.height, height, accuracy: 1) }
        capture("78-health-accessibility-top", app)
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<4 { surface.swipeUp() }
        capture("78-health-accessibility-bottom", app)
        for id in ["health-add-weight", "health-add-nutrition"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertEqual(button.frame.width, 44, accuracy: 1)
            XCTAssertEqual(button.frame.height, 44, accuracy: 1)
        }
    }
    func testBloomCancelClosesFilesAndAllowsRetry() {
        let app = launch(["--bloom-import-fixture"])
        app.tabBars.buttons["Bloom"].tap()
        app.buttons["bloom-archive-menu"].tap(); app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Importa backup Bloom", "bloom.importBackup")).firstMatch.tap()
        let cancel = app.buttons["Annulla"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15)); cancel.tap()
        XCTAssertTrue(app.buttons["bloom-section-library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["bloom-section-library"].isHittable)
        app.buttons["bloom-archive-menu"].tap(); app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Importa backup Bloom", "bloom.importBackup")).firstMatch.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 15)); cancel.tap()
        capture("78-bloom-picker-cancel", app)
    }
    func testBloomSystemFilesSelectionReachesPreviewAndPersists() {
        let app = launch(["--bloom-import-fixture"])
        app.tabBars.buttons["Bloom"].tap()
        let section = app.buttons["bloom-section-library"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(section.frame.height, 44)
        XCTAssertLessThanOrEqual(section.frame.height, 48)
        app.buttons["bloom-archive-menu"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Importa backup Bloom", "bloom.importBackup")).firstMatch.tap()
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Bloom-UI-Fixture")).firstMatch
        let visible = file.waitForExistence(timeout: 20)
        if !visible { print("FILES_PICKER_TREE " + app.debugDescription) }
        capture("78-bloom-files-picker", app)
        XCTAssertTrue(visible)
        file.tap()
        let preview = app.navigationBars["Importa backup"]
        let ready = preview.waitForExistence(timeout: 20)
        if !ready { print("BLOOM_IMPORT_PREVIEW_TREE " + app.debugDescription) }
        capture("78-bloom-import-preview", app)
        XCTAssertTrue(ready)
        app.buttons["Importa"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "bloom-note-", "Bloom import UI fixture")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        app.terminate(); app.launch(); app.tabBars.buttons["Bloom"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        capture("78-bloom-import-persisted", app)
    }
}

/// Reference capture uses a clean simulator; it never reads a personal device.
final class NativeAppleHealthReferenceUITests: XCTestCase {
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
        print("APPLE_HEALTH_REFERENCE_TREE_" + name + " " + app.debugDescription)
    }
    func testCaptureAppleHealthReference() {
        let seed = XCUIApplication()
        seed.launchArguments = ["--visual-test", "--apple-health-reference-seed", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        seed.launch()
        let status = seed.staticTexts["apple-health-reference-seed-status"]
        let authorization = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (status.exists && status.label == "Dati pronti") || seed.switches.firstMatch.exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [authorization], timeout: 20), .completed)
        if seed.switches.firstMatch.exists {
                for toggle in seed.switches.allElementsBoundByIndex where toggle.isHittable && (toggle.value as? String) == "0" { toggle.tap() }
                // iOS 27 exposes the footer action as StaticText in a scrollable
                // authorization sheet; it is initially below the viewport.
                let allow = seed.staticTexts.matching(NSPredicate(format: "label IN %@", ["Consenti", "Allow"])).firstMatch
                for _ in 0..<6 {
                    if allow.exists && allow.isHittable { break }
                    seed.swipeUp()
                }
                XCTAssertTrue(allow.isHittable); allow.tap()
        }
        let prepared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Dati pronti"), object: status)
        let preparation = XCTWaiter.wait(for: [prepared], timeout: 30)
        if preparation != .completed { capture("seed-permission-diagnostic", seed) }
        XCTAssertEqual(preparation, .completed)
        seed.terminate()
        let health = XCUIApplication(bundleIdentifier: "com.apple.Health")
        health.launchArguments = ["-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        health.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 5) {
            let deny = springboard.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Don", "Non")).firstMatch
            if deny.exists { deny.tap() }
        }
        let notificationTile = health.buttons["UIA.Health.NotificationAuthorizationTile.Header.Accessory"]
        if notificationTile.exists && notificationTile.isHittable { notificationTile.tap() }
        capture("summary-before-favorites", health)
        let edit = health.buttons["UIA.Health.Inevidenza.Detail"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15)); edit.tap()
        capture("favorites-editor", health)
        // Health's metric dictionary may finish loading after the editor opens.
        // Its display names can be Italian or English independently of the chrome.
        let anyMetric = health.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "UIA.Health.FavoritesEdit.HKQuantityTypeIdentifier")).firstMatch
        _ = anyMetric.waitForExistence(timeout: 45)
        for (titles, identifier) in [(["Energia alimentare", "Dietary Energy"], "HKQuantityTypeIdentifierDietaryEnergyConsumed"), (["Peso", "Weight"], "HKQuantityTypeIdentifierBodyMass")] {
            let row = health.cells["UIA.Health.FavoritesEdit." + identifier]
            var found = false
            for title in titles {
                let search = health.searchFields.firstMatch
                XCTAssertTrue(search.waitForExistence(timeout: 10) && search.isHittable)
                search.tap()
                let clear = search.buttons.matching(NSPredicate(format: "label IN %@", ["Cancella testo", "Clear text"])).firstMatch
                if clear.exists { clear.tap() }
                search.typeText(title)
                let keyboardNotice = health.buttons["Continue"]
                if keyboardNotice.exists && keyboardNotice.isHittable { keyboardNotice.tap() }
                if row.waitForExistence(timeout: 10) && row.isHittable { found = true; break }
            }
            if found { row.tap() }
            else { capture("favorite-not-found-" + identifier, health); XCTFail("Favorite metric not found: " + identifier) }
            capture("favorite-" + identifier, health)
        }
        let done = health.buttons.matching(NSPredicate(format: "label IN %@", ["Fine", "Done"])).firstMatch
        if done.exists && done.isHittable { done.tap() }
        let summary = health.tabBars.buttons["Riepilogo"]
        if summary.exists && summary.isHittable { summary.tap() }
        for identifier in ["HKQuantityTypeIdentifierDietaryEnergyConsumed", "HKQuantityTypeIdentifierBodyMass"] {
            XCTAssertTrue(health.cells["UIA.Health.Snippet." + identifier].waitForExistence(timeout: 15))
        }
        capture("populated-summary", health)
    }
}
