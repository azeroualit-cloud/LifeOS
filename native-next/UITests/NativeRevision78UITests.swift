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
        let date = app.staticTexts["home-today"], prayer = app.buttons["home-next-time"]
        XCTAssertTrue(prayer.waitForExistence(timeout: 10))
        XCTAssertLessThan(prayer.frame.minX, app.frame.maxX)
        XCTAssertGreaterThan(prayer.frame.midX, date.frame.midX)
        XCTAssertLessThan(abs(prayer.frame.midY - date.frame.midY), 20)
        XCTAssertLessThan(prayer.frame.width, app.frame.width / 3)
        prayer.tap()
        XCTAssertTrue(app.navigationBars["Orari"].waitForExistence(timeout: 10))
        capture("78-prayers", app)
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
    func testBloomSystemFilesSelectionReachesPreviewAndPersists() {
        let app = launch(["--bloom-import-fixture"])
        app.tabBars.buttons["Bloom"].tap()
        let section = app.buttons["bloom-section-library"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(section.frame.height, 44)
        XCTAssertLessThanOrEqual(section.frame.height, 48)
        app.buttons["Archivio"].tap()
        app.buttons["Importa backup Bloom"].tap()
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
    func testCaptureAppleHealthReference() {
        let health = XCUIApplication(bundleIdentifier: "com.apple.Health")
        health.launchArguments = ["-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        health.launch()
        for index in 0..<12 {
            let image = XCTAttachment(screenshot: health.screenshot())
            image.name = "Apple-Health-reference-\(index)"; image.lifetime = .keepAlways; add(image)
            print("APPLE_HEALTH_REFERENCE_TREE_\(index) " + health.debugDescription)
            let names = ["Continua", "Continue", "Avanti", "Next", "Salta", "Skip", "Fine", "Done", "Non ora", "Not Now"]
            guard let next = names.map({ health.buttons[$0] }).first(where: { $0.exists && $0.isHittable }) else { break }
            next.tap()
        }
    }
}
