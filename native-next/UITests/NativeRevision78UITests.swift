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
            XCTAssertGreaterThanOrEqual(button.frame.width, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44 - 0.001)
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
        XCTAssertGreaterThanOrEqual(button.frame.height, 44 - 0.001)
        capture("78-dashboard-budget-action", app)
        button.tap()
        XCTAssertTrue(app.textFields["movement-amount"].waitForExistence(timeout: 10))
    }
    func testHealthUniformRowsAndCompactActions() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        let rows = ["tdee", "weight", "calories", "simulation"].map { app.buttons["health-summary-" + $0] }
        for row in rows { XCTAssertTrue(row.waitForExistence(timeout: 10)) }
        XCTAssertTrue(rows[0].label.contains("TDEE")); XCTAssertTrue(rows[0].label.contains("14 giorni dall’ultima pesata"))
        XCTAssertTrue(rows[3].label.contains("Peso previsto"))
        XCTAssertTrue(rows[1].label.contains("Peso"))
        XCTAssertNotNil(rows[3].label.components(separatedBy: ", ").last?.range(of: "[0-9]", options: .regularExpression), "The forecast date remains in the accessible summary")
        XCTAssertNotNil(rows[1].label.components(separatedBy: ", ").last?.range(of: "[0-9]", options: .regularExpression), "The latest weight and date remain in the accessible summary")
        XCTAssertLessThan(rows[0].frame.midY, rows[1].frame.midY)
        XCTAssertEqual(rows[0].frame.midY, rows[3].frame.midY, accuracy: 2)
        XCTAssertEqual(rows[1].frame.midY, rows[2].frame.midY, accuracy: 2)
        XCTAssertLessThan(rows[0].frame.midX, rows[3].frame.midX)
        XCTAssertLessThan(rows[1].frame.midX, rows[2].frame.midX)
        capture("78-health-summary", app)
        let surface = app.scrollViews["health-detail-scroll"]
        let food = app.buttons["health-add-nutrition"]
        for (id, title) in [("health-add-weight", "Aggiungi peso"), ("health-add-nutrition", "Aggiungi alimento")] {
            let button = app.buttons[id]
            XCTAssertEqual(button.label, title)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44 - 0.001)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        XCTAssertFalse(app.buttons["health-connect"].exists)
        XCTAssertFalse(app.staticTexts["Fonte delle calorie"].exists)
        let weight = app.buttons["health-add-weight"]
        XCTAssertEqual((weight.frame.union(food.frame)).midX, surface.frame.midX, accuracy: 2)
        capture("health-actions-above-navigation", app)
        let initialWeightFrame = weight.frame
        let initialFoodFrame = food.frame
        surface.swipeUp()
        XCTAssertEqual(weight.frame.minY, initialWeightFrame.minY, accuracy: 1)
        XCTAssertEqual(food.frame.minY, initialFoodFrame.minY, accuracy: 1)
        for _ in 0..<6 where !rows[3].isHittable { surface.swipeDown() }
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
        capture("health-accessible-actions-above-navigation", app)
        for id in ["health-add-weight", "health-add-nutrition"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44 - 0.001)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        let fibre = app.descendants(matching: .any)["health-nutrient-HKQuantityTypeIdentifierDietaryFiber"]
        let surface = app.scrollViews["health-detail-scroll"]
        for _ in 0..<12 where !fibre.isHittable { surface.swipeUp() }
        XCTAssertTrue(fibre.isHittable)
    }
    func testHealthNutritionQuickAddAndHistoryAreReachable() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        let add = app.buttons["health-add-nutrition"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(add.isHittable); add.tap()
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
    func testMicronutrientPrioritiesOpenWithOtherNutrientsInDetail() {
        let app = launch()
        app.tabBars.buttons["Salute"].tap()
        let open = app.buttons["health-micronutrients"]
        let scroll = app.scrollViews["health-detail-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<8 where !open.isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.descendants(matching: .any)["health-progress-vitaminC"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["health-progress-zinc"].exists)
        XCTAssertTrue(open.isHittable)
        open.tap()
        XCTAssertTrue(app.navigationBars["Micronutrienti"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Vitamina C"].exists)
        XCTAssertTrue(app.staticTexts["Zinco"].exists)
        XCTAssertTrue(app.staticTexts["Micronutrienti"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Tutti i micronutrienti"].exists)
        XCTAssertTrue(app.buttons["micronutrient-reorder"].exists)
        capture("Micronutrient catalogue detail", app)
    }

    func testRenderHealthWeekAndDashboardAndBloom() {
        let app = launch(["--health-week-review"])
        app.tabBars.buttons["Salute"].tap()
        let week = app.buttons["health-week-previous"]
        XCTAssertTrue(week.waitForExistence(timeout: 10))
        capture("Review 00 Health today and shift accent", app)
        week.tap()
        XCTAssertTrue(app.buttons["health-week-next"].isEnabled)
        capture("Review 01 Health weekly grid", app)

        let scroll = app.scrollViews["health-detail-scroll"]
        let micro = app.buttons["health-micronutrients"]
        for _ in 0..<5 where !micro.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(micro.isHittable)
        capture("Review 02 Health pinned nutrients and diary", app)
        micro.tap()
        XCTAssertTrue(app.navigationBars["Micronutrienti"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Apporto registrato basso · Produzione di collagene"].waitForExistence(timeout: 5))
        capture("Review 03 Micronutrients daily and weekly", app)
        let edit = app.buttons["micronutrient-reorder"]
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        capture("Review 04 Micronutrient ordering", app)
        edit.tap()
        app.navigationBars.buttons.firstMatch.tap()

        let add = app.buttons["health-add-nutrition"]
        XCTAssertTrue(add.isHittable)
        add.tap()
        let date = app.buttons["quick-nutrition-date"]
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        let previousWeekDay = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Locale(identifier: "it_IT"))
        XCTAssertEqual(date.value as? String, previousWeekDay?.formatted(format))
        let form = app.scrollViews["quick-nutrition-scroll"]
        for _ in 0..<4 where !date.isHittable { form.swipeUp(velocity: .slow) }
        capture("Review 05 Backdated food entry", app)
        app.buttons["quick-nutrition-close"].tap()

        app.tabBars.buttons["Dashboard"].tap()
        let dashboard = app.scrollViews["dashboard-scroll"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        capture("Review 06 Dashboard calendar and finance", app)
        for _ in 0..<6 where !app.buttons["quick-nutrition-open"].isHittable { dashboard.swipeUp(velocity: .slow) }
        XCTAssertTrue(app.buttons["quick-nutrition-open"].isHittable)
        capture("Review 07 Dashboard pinned nutrition", app)
        app.tabBars.buttons["Bloom"].tap()
        XCTAssertTrue(app.buttons["bloom-section-library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["bloom-section-map"].exists)
        XCTAssertFalse(app.buttons["bloom-section-rediscovery"].exists)
        capture("Review 08 Bloom sections", app)
    }

    func testRenderHealthDiaryOmegaAndRankedCatalog() {
        let app = launch(["--health-week-review", "--health-catalog-review"])
        app.tabBars.buttons["Salute"].tap()
        let previous = app.buttons["health-week-previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        previous.tap()

        let scroll = app.scrollViews["health-detail-scroll"]
        let meal = app.staticTexts["Pasto di prova"]
        for _ in 0..<5 where !meal.isHittable { scroll.swipeUp() }
        XCTAssertTrue(meal.isHittable)
        capture("Review 09 Health past diary", app)

        app.buttons["health-add-nutrition"].tap()
        app.buttons["quick-nutrition-catalog"].tap()
        let gin = app.buttons["generic-food-cocktail-gin-tonic"]
        let biscuits = app.buttons["generic-food-ciqual-24001"]
        XCTAssertTrue(gin.waitForExistence(timeout: 10))
        XCTAssertTrue(biscuits.isHittable)
        XCTAssertLessThan(gin.frame.minY, biscuits.frame.minY)
        capture("Review 10 Foods ranked by 30 day frequency", app)
        app.buttons["Fine"].tap()
        app.buttons["quick-nutrition-close"].tap()

        let micronutrients = app.buttons["health-micronutrients"]
        for _ in 0..<5 where !micronutrients.isHittable { scroll.swipeDown(velocity: .slow) }
        micronutrients.tap()
        XCTAssertTrue(app.navigationBars["Micronutrienti"].waitForExistence(timeout: 10))
        let omega = app.staticTexts["Omega-3 (EPA + DHA)"]
        for _ in 0..<12 where !omega.isHittable { app.swipeUp() }
        XCTAssertTrue(omega.isHittable)
        capture("Review 11 Omega-3 in Micronutrients", app)
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
        let library = app.buttons["bloom-section-library"]
        func cancelPickerAndWaitForLibrary() {
            XCTAssertTrue(cancel.waitForExistence(timeout: 15))
            cancel.tap()
            // The underlying section exists while UIKit is still dismissing Files.
            // Wait for the actual interaction contract, not mere tree presence.
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: library)
            let result = XCTWaiter.wait(for: [ready], timeout: 15)
            if result != .completed {
                capture("78-bloom-cancel-not-ready", app)
                let tree = XCTAttachment(string: app.debugDescription)
                tree.name = "78-bloom-cancel-not-ready hierarchy"
                tree.lifetime = .keepAlways
                add(tree)
            }
            XCTAssertEqual(result, .completed, "Cancelling Files must restore an interactive Bloom library")
        }
        cancelPickerAndWaitForLibrary()
        app.buttons["bloom-archive-menu"].tap(); app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Importa backup Bloom", "bloom.importBackup")).firstMatch.tap()
        cancelPickerAndWaitForLibrary()
        capture("78-bloom-picker-cancel", app)
    }
    func testBloomSystemFilesSelectionReachesPreviewAndPersists() {
        let app = launch(["--bloom-import-fixture"])
        app.tabBars.buttons["Bloom"].tap()
        let section = app.buttons["bloom-section-library"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        for (id, label) in [("library", "Libreria"), ("map", "Mappa")] {
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
        if name.contains("diagnostic") || name.contains("unavailable") || name.contains("empty") || name.contains("not-found") {
            print("APPLE_HEALTH_REFERENCE_TREE_" + name + " " + app.debugDescription)
        }
    }
    func testCaptureAppleHealthReference() {
        executionTimeAllowance = 300
        let seed = XCUIApplication()
        seed.launchArguments = ["--visual-test", "--apple-health-reference-seed", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        seed.launch()
        let status = seed.staticTexts["apple-health-reference-seed-status"]
        // Health's remote authorization sheet may be visible without belonging to
        // the host app's accessibility tree (see run 43113799496).
        let permissionApps = [seed, XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"), XCUIApplication(bundleIdentifier: "com.apple.springboard")]
        func permissionApp() -> XCUIApplication? {
            permissionApps.first {
                $0.state != .notRunning && $0.state != .unknown &&
                $0.switches["UIA.Health.DietaryEnergy.SwitchCell.Switch"].exists
            }
        }
        let authorization = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (status.exists && status.label == "Dati pronti") || permissionApp() != nil
        }, object: nil)
        guard XCTWaiter.wait(for: [authorization], timeout: 60) == .completed else {
            capture("seed-permission-diagnostic", seed)
            for app in permissionApps.dropFirst() where app.state != .notRunning {
                capture("seed-permission-process-diagnostic", app)
            }
            XCTFail("The Health authorization dialog did not become ready")
            return
        }
        if status.label != "Dati pronti", let permission = permissionApp() {
            let toggles = ["DietaryEnergy", "Weight"].map { permission.switches["UIA.Health." + $0 + ".SwitchCell.Switch"] }
            for toggle in toggles {
                for _ in 0..<5 where !toggle.isHittable { permission.swipeUp(velocity: .slow) }
                for _ in 0..<3 where (toggle.value as? String) != "1" && toggle.isHittable {
                    toggle.tap()
                    let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: toggle)
                    if XCTWaiter.wait(for: [enabled], timeout: 2) == .completed { break }
                }
                guard (toggle.value as? String) == "1" else {
                    capture("seed-toggle-off", permission)
                    XCTFail("Write permission switch is off: " + toggle.identifier)
                    return
                }
            }
            let allow = permission.staticTexts.matching(NSPredicate(format: "label IN %@", ["Consenti", "Allow"])).firstMatch
            for _ in 0..<6 where !allow.isHittable { permission.swipeUp(velocity: .slow) }
            guard allow.isHittable else {
                capture("seed-allow-unavailable", seed)
                XCTFail("The Health permission confirmation is unavailable")
                return
            }
            allow.tap()
        }
        let prepared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Dati pronti"), object: status)
        guard XCTWaiter.wait(for: [prepared], timeout: 30) == .completed else {
            capture("seed-permission-diagnostic", seed)
            XCTFail("Apple Health reference data was not saved")
            return
        }
        // Launching Health backgrounds the fixture app after its save has completed.
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
        let identifiers = ["HKQuantityTypeIdentifierDietaryEnergyConsumed", "HKQuantityTypeIdentifierBodyMass"]
        let feed = health.collectionViews["UIA.Health.SummaryFeedViewController.CollectionView"]
        let editor = health.collectionViews["UIA.Health.EditFavoritesCollectionViewController.CollectionView"]
        let done = health.buttons.matching(NSPredicate(format: "label IN %@", ["Fine", "Done"])).firstMatch
        let prefix = "UIA.Health.FavoritesEdit."
        var firstMetricIdentifier: String?
        for identifier in identifiers {
            let summaryMetric = feed.cells["UIA.Health.Snippet." + identifier]
            if summaryMetric.exists { continue }
            guard edit.waitForExistence(timeout: 15), edit.isHittable else {
                capture("favorites-entry-unavailable", health)
                XCTFail("The Apple Health favorites editor could not be opened")
                return
            }
            edit.tap()
            let firstMetric = editor.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
            guard firstMetric.waitForExistence(timeout: 45) else {
                capture("favorites-editor-empty", health)
                XCTFail("The Apple Health favorites list did not load")
                return
            }
            capture("favorites-editor", health)
            if firstMetricIdentifier == nil { firstMetricIdentifier = firstMetric.identifier }
            if let identifier = firstMetricIdentifier {
                let topMetric = editor.cells[identifier]
                // Stop at the first row so a pull past the top cannot dismiss the sheet.
                for _ in 0..<12 where !topMetric.isHittable {
                    let start = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
                    let end = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                    start.press(forDuration: 0.05, thenDragTo: end)
                }
            }
            let row = editor.cells[prefix + identifier]
            let toggle = row.images["UIA.Health.Toggle"]
            for _ in 0..<24 where !toggle.isHittable {
                let start = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.73))
                let end = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            guard toggle.isHittable else {
                capture("favorite-not-found-" + identifier, health)
                XCTFail("Favorite metric not found: " + identifier)
                return
            }
            // Apple Health can move the selected row out of the editor viewport.
            // Verify the saved values in the summary after closing the editor.
            if !row.isSelected { toggle.tap() }
            capture("favorite-" + identifier, health)
            if done.exists && done.isHittable { done.tap() }
        }
        let summary = health.tabBars.buttons["Riepilogo"]
        if summary.exists && summary.isHittable { summary.tap() }
        XCTAssertTrue(feed.waitForExistence(timeout: 15))
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
