import XCTest
import UIKit

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
        // Permit at most one physical pixel for fractional coordinate rounding.
        XCTAssertLessThanOrEqual(value.frame.maxY, label.frame.minY + 1 / UIScreen.main.scale)
        XCTAssertGreaterThan(button.frame.minX, value.frame.maxX)
        XCTAssertLessThanOrEqual(button.frame.maxX, header.frame.maxX + 1 + 1 / UIScreen.main.scale)
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
        XCTAssertTrue(rows[0].label.contains("TDEE")); XCTAssertTrue(rows[0].label.contains("Stima storica"))
        XCTAssertTrue(rows[3].label.contains("Peso previsto"))
        XCTAssertTrue(rows[1].label.contains("Peso"))
        XCTAssertNotNil(rows[3].label.components(separatedBy: ", ").last?.range(of: "[0-9]", options: .regularExpression), "The forecast date remains in the accessible summary")
        XCTAssertNotNil(rows[1].label.components(separatedBy: ", ").last?.range(of: "[0-9]", options: .regularExpression), "The latest weight and date remain in the accessible summary")
        XCTAssertLessThan(rows[0].frame.midY, rows[1].frame.midY)
        XCTAssertEqual(rows[0].frame.midY, rows[3].frame.midY, accuracy: 2)
        XCTAssertEqual(rows[1].frame.midY, rows[2].frame.midY, accuracy: 2)
        XCTAssertLessThan(rows[0].frame.midX, rows[3].frame.midX)
        XCTAssertLessThan(rows[1].frame.midX, rows[2].frame.midX)
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
        let ordered = [rows[0], rows[3], rows[1], rows[2]]
        for pair in zip(ordered, ordered.dropFirst()) { XCTAssertLessThan(pair.0.frame.midY, pair.1.frame.midY) }
        capture("78-health-accessibility-top", app)
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<4 { surface.swipeUp() }
        capture("78-health-accessibility-bottom", app)
        XCTAssertTrue(app.descendants(matching: .any)["health-nutrient-HKQuantityTypeIdentifierDietaryFiber"].exists)
        for id in ["health-add-weight", "health-add-nutrition"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertEqual(button.frame.width, 44, accuracy: 1)
            XCTAssertEqual(button.frame.height, 44, accuracy: 1)
        }
    }
    func testHealthNutritionQuickAddAndHistoryAreReachable() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        let add = app.buttons["health-add-nutrition"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        XCTAssertTrue(app.staticTexts["Aggiungi nutrienti"].waitForExistence(timeout: 10))
        app.buttons["quick-nutrition-close"].tap()
        let history = app.buttons["health-nutrition-history"]
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<6 where !history.isHittable { surface.swipeUp() }
        XCTAssertTrue(history.isHittable); history.tap()
        XCTAssertTrue(app.navigationBars["Nutrizione"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
    }
    func testSafeAreaLastContentStandard() { checkSafeAreaLastContent(large: false) }
    func testSafeAreaLastContentLargeText() { checkSafeAreaLastContent(large: true) }
    private func checkSafeAreaLastContent(large: Bool) {
        executionTimeAllowance = 600
        let app = launch(["--bloom-grid-fixture"] + (large ? ["--large-text"] : []))
        let tabBar = app.tabBars.firstMatch
        let dashboard = app.scrollViews["dashboard-scroll"]
        let quick = app.buttons["quick-nutrition-open"]
        let status = dashboard.staticTexts.matching(NSPredicate(format: "label IN %@", ["Demo", "Salvataggio", "Sincronizzazione", "Da aggiornare", "Condiviso con il sito", "Sul dispositivo", "Collegato"])).firstMatch
        for _ in 0..<15 {
            if quick.isHittable && status.exists && status.frame.maxY <= tabBar.frame.minY { break }
            dashboard.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(quick.isHittable, "Dashboard bottom action must be reachable")
        XCTAssertTrue(status.exists, "The final connection status must remain readable")
        XCTAssertLessThanOrEqual(quick.frame.maxY, tabBar.frame.minY)
        XCTAssertLessThanOrEqual(status.frame.maxY, tabBar.frame.minY)
        capture(large ? "safe-area-dashboard-large" : "safe-area-dashboard-standard", app)

        app.tabBars.buttons["Salute"].tap()
        let health = app.scrollViews["health-detail-scroll"]
        let history = app.buttons["health-nutrition-history"]
        let weight = app.buttons["health-add-weight"], food = app.buttons["health-add-nutrition"]
        XCTAssertTrue(health.waitForExistence(timeout: 10))
        for _ in 0..<15 {
            if history.isHittable && history.frame.maxY <= min(weight.frame.minY, food.frame.minY) { break }
            health.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(history.isHittable, "The last Health action must be reachable")
        XCTAssertLessThanOrEqual(history.frame.maxY, min(weight.frame.minY, food.frame.minY))
        XCTAssertTrue(weight.isHittable); XCTAssertTrue(food.isHittable)
        XCTAssertLessThanOrEqual(max(weight.frame.maxY, food.frame.maxY), tabBar.frame.minY)
        capture(large ? "safe-area-health-large" : "safe-area-health-standard", app)

        app.tabBars.buttons["Bloom"].tap()
        let bloom = app.scrollViews["bloom-library-scroll"]
        XCTAssertTrue(bloom.waitForExistence(timeout: 20))
        let last = app.buttons["bloom-note-BA000000-0000-4000-8000-000000000121"]
        func recordBloomProgress(_ step: Int) {
            let visibleBounds = bloom.frame.intersection(CGRect(x: app.frame.minX, y: app.frame.minY,
                width: app.frame.width, height: max(0, tabBar.frame.minY - app.frame.minY)))
            let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bloom-note-"))
                .allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(visibleBounds) }
            let details = cards.map { "\($0.identifier): \($0.frame)" }.joined(separator: "\n")
            let prefix = "safe-area-bloom-\(large ? "large" : "standard")-step-\(step)"
            print("BLOOM_SCROLL_DIAGNOSTIC \(prefix) scroll=\(bloom.frame) visible=\(visibleBounds)\n\(details)")
            let hierarchy = XCTAttachment(string: "Visible cards:\n\(details)\n\nHierarchy:\n\(app.debugDescription)")
            hierarchy.name = prefix + " hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            capture(prefix, app)
        }
        var gestures = 0
        for step in 0..<120 {
            XCTAssertTrue(bloom.exists, "The identified Bloom library scroll must remain present")
            if [0, 20, 40, 100].contains(step) { recordBloomProgress(step) }
            let scrollFrame = bloom.frame
            let tabTop = tabBar.frame.minY
            if last.exists && last.isHittable && last.frame.maxY <= min(scrollFrame.maxY, tabTop) { break }
            // Resolve the bounds once per gesture; repeated XCTest snapshots are expensive.
            let top = max(scrollFrame.minY, app.frame.minY) + 24
            let bottom = min(scrollFrame.maxY, tabTop) - 24
            XCTAssertGreaterThan(bottom - top, 44, "The visible Bloom scroll region must permit a gesture")
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: scrollFrame.midX, dy: bottom))
            let end = origin.withOffset(CGVector(dx: scrollFrame.midX, dy: max(top, bottom - 200)))
            start.press(forDuration: 0.05, thenDragTo: end)
            gestures += 1
            XCTAssertTrue(app.tabBars.buttons["Bloom"].isSelected, "Scrolling the library must not select another tab")
        }
        XCTAssertTrue(bloom.exists, "The identified Bloom library scroll must remain present")
        recordBloomProgress(gestures)
        XCTAssertTrue(last.exists, "The last fixture note must be reached")
        XCTAssertTrue(last.isHittable)
        XCTAssertLessThanOrEqual(last.frame.maxY, min(bloom.frame.maxY, tabBar.frame.minY))
        capture(large ? "safe-area-bloom-large" : "safe-area-bloom-standard", app)
        last.tap()
        XCTAssertTrue(app.navigationBars["Nota"].waitForExistence(timeout: 10))
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
        for (id, label) in [("library", "Libreria"), ("map", "Mappa"), ("rediscovery", "Riscopri")] {
            let matches = app.descendants(matching: .any).matching(identifier: "bloom-section-" + id)
            XCTAssertEqual(matches.count, 1, "Each section must expose exactly one identified accessibility element")
            XCTAssertEqual(matches.element(boundBy: 0).label, label)
        }
        print("BLOOM_SECTION_ACCESSIBILITY_FRAME \(section.frame) hittable=\(section.isHittable) selected=\(section.isSelected)")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "78 Bloom section before touch target assertion hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let sectionScreenshot = XCTAttachment(screenshot: app.screenshot())
        sectionScreenshot.name = "78 Bloom section before touch target assertion"
        sectionScreenshot.lifetime = .keepAlways
        add(sectionScreenshot)
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
    func testBloomSectionRespondsAtLowerEdgeOf44PointTouchTarget() {
        let app = launch()
        app.tabBars.buttons["Bloom"].tap()
        let section = app.buttons["bloom-section-map"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        XCTAssertFalse(section.isSelected)
        let bounds = app.frame
        let frame = section.frame
        let target = app.coordinate(withNormalizedOffset: CGVector(
            dx: (frame.midX - bounds.minX) / bounds.width,
            dy: (frame.midY + 21 - bounds.minY) / bounds.height
        ))
        target.tap()
        XCTAssertTrue(section.isSelected, "The section button should respond at the lower edge of its 44 pt target.")
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
        let feed = health.collectionViews["UIA.Health.SummaryFeedViewController.CollectionView"]
        XCTAssertTrue(feed.waitForExistence(timeout: 15))
        let identifiers = ["HKQuantityTypeIdentifierDietaryEnergyConsumed", "HKQuantityTypeIdentifierBodyMass"]
        var found: [String: String] = [:]
        for _ in 0..<13 {
            for identifier in identifiers where found[identifier] == nil {
                let cell = health.cells["UIA.Health.Snippet." + identifier]
                if cell.exists && cell.isHittable {
                    found[identifier] = cell.label.lowercased()
                    capture("reference-visible-" + identifier, health)
                }
            }
            if found.count == identifiers.count { break }
            let top = max(feed.frame.minY, health.frame.minY) + 24
            let bottom = min(feed.frame.maxY, health.tabBars.firstMatch.frame.minY) - 24
            XCTAssertGreaterThan(bottom - top, 44)
            let origin = health.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: feed.frame.midX, dy: bottom))
            let end = origin.withOffset(CGVector(dx: feed.frame.midX, dy: max(top, bottom - 300)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        if found.count != identifiers.count { capture("reference-missing-metrics", health) }
        for identifier in identifiers {
            XCTAssertNotNil(found[identifier], "The seeded Health metric must be visible: " + identifier)
        }
        let energy = found[identifiers[0]] ?? ""
        XCTAssertTrue(energy.filter { $0.isNumber }.contains("2200"), "Expected seeded 2,200 calories: " + energy)
        let weight = found[identifiers[1]] ?? ""
        let kilograms = weight.range(of: "(?<![0-9])80([.,]0+)?\\s*(kg|kilogram)", options: .regularExpression) != nil
        let pounds = weight.range(of: "(?<![0-9])176[.,]4[0-9]*\\s*(lb|pound)", options: .regularExpression) != nil
        XCTAssertTrue(kilograms || pounds, "Expected seeded 80 kg (or its pound equivalent): " + weight)
        capture("populated-summary", health)
    }
}
