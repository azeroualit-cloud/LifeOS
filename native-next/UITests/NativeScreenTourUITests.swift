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
        let custom = app.buttons["finance-analysis-back"]
        if custom.exists && custom.isHittable { custom.tap(); return }
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
        // REVIEW-95: a day without events still opens its agenda.
        if tap(app.buttons["calendar-view-month"]) {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
            let later = formatter.string(from: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date())
            if tap(app.buttons["calendar-day-" + later]) { shot(prefix + " 06b Calendario giorno", app) }
        }

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
        // REVIEW-95: a salary group opens its own map.
        if tap(app.buttons["finance-salary-tile-Impegni del mese"]) { shot(prefix + " 14b Stipendio gruppo", app); dismissSheet(app) }
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
        if tap(app.buttons["primary-add"]) {
            shot(prefix + " 21 Nuova spesa", app)
            if tap(app.buttons["Tipo"]) { shot(prefix + " 21b Tipo", app); app.buttons["Spesa"].firstMatch.tap() }
            // REVIEW-95: the split between savings and budget months appears with an amount.
            let field = app.textFields["movement-amount"]
            if field.waitForExistence(timeout: 5) {
                field.tap(); field.typeText("186")
                if app.buttons["movement-hide-keyboard"].exists { app.buttons["movement-hide-keyboard"].tap() }
                for _ in 0..<4 where app.buttons["expense-split-more"].exists && !app.buttons["expense-split-more"].isHittable { app.swipeUp(velocity: .slow) }
                for _ in 0..<6 where app.buttons["expense-split-more"].exists { app.buttons["expense-split-more"].tap() }
                let next = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'expense-split-month-'")).element(boundBy: 1)
                if next.exists && next.isHittable { next.tap() }
                shot(prefix + " 22 Nuova spesa ripartita", app)
                // Categories and items (nine groups), then a bill with its period and plan.
                app.swipeDown(velocity: .slow)
                if tap(app.buttons["movement-category"]) {
                    shot(prefix + " 23 Categorie", app)
                    app.swipeUp(velocity: .slow); shot(prefix + " 24 Categorie sotto", app)
                    if app.buttons["Elettricità"].exists { app.buttons["Elettricità"].tap() } else { app.tap() }
                    for _ in 0..<3 { app.swipeUp(velocity: .slow) }
                    shot(prefix + " 25 Bolletta", app)
                    app.swipeUp(velocity: .slow); shot(prefix + " 26 Bolletta sotto", app)
                }
            }
            dismissSheet(app)
            if app.buttons["Elimina modifiche"].exists { app.buttons["Elimina modifiche"].tap() }
        }
    }

    func testTourDark() { tour("--dark", "Scuro") }
    func testTourLight() { tour("--light", "Chiaro") }
}
