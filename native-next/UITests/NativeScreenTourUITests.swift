import XCTest

/// Screenshot tour of every main screen (build 95 review loop): it never asserts layout,
/// it only walks the app and attaches one named screenshot per screen.
final class NativeScreenTourUITests: XCTestCase {
    private func launch(_ theme: String) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", theme, "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        _ = app.mainTabBar.buttons["Dashboard"].waitForExistence(timeout: 20)
        return app
    }
    private func shot(_ name: String, _ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.8)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func scroll(_ app: XCUIApplication, _ name: String) {
        let view = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app.collectionViews.firstMatch
        guard view.exists else { return }
        view.swipeUp(velocity: .slow)
        shot(name, app)
    }
    private func tap(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 8), element.isHittable else { return false }
        element.tap(); return true
    }
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        if button.exists && button.isHittable { button.tap() }
    }
    private func dismissSheet(_ app: XCUIApplication) {
        for label in ["Annulla", "Chiudi", "Fine"] where app.buttons[label].exists && app.buttons[label].isHittable {
            app.buttons[label].tap(); return
        }
        app.swipeDown(velocity: .fast)
    }

    private func tour(_ theme: String, _ prefix: String) {
        let app = launch(theme)
        shot(prefix + " 01 Dashboard", app)
        scroll(app, prefix + " 02 Dashboard sotto")
        scroll(app, prefix + " 03 Dashboard fondo")

        app.openMainTab("Attività")
        shot(prefix + " 04 Attività", app)

        app.openMainTab("Calendario")
        shot(prefix + " 05 Calendario mese", app)
        if tap(app.buttons["calendar-view-agenda"]) { shot(prefix + " 06 Calendario agenda", app) }

        app.openMainTab("Salute")
        shot(prefix + " 07 Salute", app)
        scroll(app, prefix + " 08 Salute sotto")
        scroll(app, prefix + " 09 Salute andamento")

        app.openMainTab("Bloom")
        shot(prefix + " 10 Bloom libreria", app)
        if tap(app.buttons["bloom-section-map"]) { shot(prefix + " 11 Bloom mappa", app) }

        app.openOtherDestination("Finanza")
        shot(prefix + " 12 Finanza", app)
        scroll(app, prefix + " 13 Finanza sotto")
        scroll(app, prefix + " 14 Finanza stipendio")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        if tap(app.buttons["finance-budget"]) { shot(prefix + " 15 Budget", app); back(app) }
        if tap(app.buttons["finance-analysis"]) {
            shot(prefix + " 16 Analisi", app)
            scroll(app, prefix + " 17 Analisi sotto")
            scroll(app, prefix + " 18 Analisi giorno per giorno")
            back(app)
        }
        if tap(app.buttons["all-movements"]) { shot(prefix + " 19 Movimenti", app); back(app) }
        if tap(app.buttons["finance-new-plan"]) { shot(prefix + " 20 Nuovo piano", app); dismissSheet(app) }
        if tap(app.buttons["primary-add"]) { shot(prefix + " 21 Nuova spesa", app); dismissSheet(app) }
    }

    func testTourDark() { tour("--dark", "Scuro") }
    func testTourLight() { tour("--light", "Chiaro") }
}
