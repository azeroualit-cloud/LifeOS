import XCTest

/// Screenshot tour of every main screen (build 95 review loop): it never asserts layout,
/// it only walks the app and attaches one named screenshot per screen.
final class NativeScreenTourUITests: XCTestCase {
    private func launch(_ theme: String) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--expense-routing", theme, "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
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
    private func tap(_ query: XCUIElement) -> Bool {
        // A day can appear twice (this month and the next one's leading days): always the first match.
        let element = query.firstMatch
        guard element.waitForExistence(timeout: 8) else { return false }
        if element.isHittable { element.tap(); return true }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); return true
    }
    private func type(_ field: XCUIElement, _ text: String, _ app: XCUIApplication) {
        guard field.waitForExistence(timeout: 5) else { return }
        for _ in 0..<3 where !field.isHittable { app.swipeUp(velocity: .slow) }
        guard field.isHittable else { return }
        field.tap()
        let old = field.value as? String ?? ""
        if !old.isEmpty && old != field.placeholderValue { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(text)
        if app.buttons["Fine"].exists { app.buttons["Fine"].firstMatch.tap() }
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
        // LIFE-STATS-2026-11-25: Statistiche at the bottom of the Dashboard.
        for _ in 0..<3 where !(app.buttons["home-stats"].exists && app.buttons["home-stats"].isHittable) { app.swipeUp(velocity: .slow) }
        if tap(app.buttons["home-stats"]) {
            shot(prefix + " 03i Statistiche", app)
            app.swipeUp(velocity: .slow); shot(prefix + " 03j Statistiche sotto", app)
            if tap(app.buttons["stats-private-unlock"]) {
                app.swipeUp(velocity: .slow); shot(prefix + " 03k Statistiche privato", app)
            }
            if app.buttons["stats-back"].exists { app.buttons["stats-back"].tap() }
        }
        // Avvisi: always reachable from Impostazioni, also when every alert was ignored.
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        // REVIEW-95E: the next time opens its sheet, then the month of times.
        if tap(app.buttons["home-next-time"]) {
            shot(prefix + " 01b Orari", app)
            if tap(app.buttons["times-month-open"]) { shot(prefix + " 01c Calendario degli orari", app) }
            for _ in 0..<3 where !app.tabBars.firstMatch.isHittable {
                let back = app.navigationBars.buttons.firstMatch
                if back.exists && back.isHittable { back.tap() } else { dismissSheet(app) }
            }
        }
        if tap(app.buttons["Impostazioni"].firstMatch) {
            shot(prefix + " 03b Impostazioni", app)
            if tap(app.buttons["settings-guide"]) {
                shot(prefix + " 03f Guida", app)
                app.swipeUp(velocity: .slow); shot(prefix + " 03g Guida sotto", app)
                app.swipeUp(velocity: .slow); shot(prefix + " 03h Guida fondo", app)
                let back = app.navigationBars.buttons.firstMatch
                if back.exists && back.isHittable { back.tap() }
            }
            for _ in 0..<3 where !app.buttons["settings-finance-alerts"].isHittable { app.swipeUp(velocity: .slow) }
            if tap(app.buttons["settings-finance-alerts"]) {
                shot(prefix + " 03c Avvisi", app)
                app.swipeUp(velocity: .slow); shot(prefix + " 03d Avvisi sotto", app)
                app.swipeUp(velocity: .slow); shot(prefix + " 03e Avvisi fondo", app)
            }
            // Back to the Dashboard: the back button of Avvisi, then close Impostazioni (a swipe only scrolls the longer Avvisi page).
            for _ in 0..<4 where !(app.scrollViews["dashboard-scroll"].exists && app.tabBars.firstMatch.isHittable) {
                let back = app.navigationBars.buttons.firstMatch
                if back.exists && back.isHittable { back.tap() } else { dismissSheet(app) }
            }
        }

        app.openMainTab("Attività")
        shot(prefix + " 04 Attività", app)

        app.openMainTab("Calendario")
        shot(prefix + " 05 Calendario mese", app)
        if tap(app.buttons["calendar-view-agenda"]) {
            shot(prefix + " 06 Calendario agenda", app)
            if tap(app.buttons["calendar-private"]) {
                shot(prefix + " 06c Privato", app)
                // LIFE-STATS-2026-11-25: the summary opens (no Face ID on the simulator).
                if tap(app.buttons["private-unlock"]) { app.swipeUp(velocity: .slow); shot(prefix + " 06d Privato riepilogo", app) }
                dismissSheet(app)
            }
        }
        // REVIEW-95: a day without events still opens its agenda.
        if tap(app.buttons["calendar-view-month"]) {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
            let later = formatter.string(from: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date())
            if tap(app.buttons["calendar-day-" + later]) {
                shot(prefix + " 06b Calendario giorno", app)
            }
        }

        app.openMainTab("Salute")
        shot(prefix + " 07 Salute", app)
        // FOOD-QUICK-ADD and SUPPLEMENT-STACK: the search with grams, the stacks, the stack editor.
        if tap(app.buttons["health-add-nutrition"]) {
            shot(prefix + " 07b Aggiungi alimento", app)
            if tap(app.buttons["supplement-stack-new"]) { shot(prefix + " 07c Nuova stack", app); dismissSheet(app) }
            if app.buttons["Fine"].exists { app.buttons["Fine"].firstMatch.tap() } else { dismissSheet(app) }
        }
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
        if tap(app.buttons["finance-new-plan"]) {
            shot(prefix + " 20 Nuovo piano", app)
            // FINANCE-ENTRY-SIMPLIFY: three kinds; «Ricorrente» with fixed or estimated amount. A fund is paid with Nuova spesa.
            if tap(app.buttons["plan-kind-fixed"]) { shot(prefix + " 20b Piano ricorrente", app) }
            _ = tap(app.buttons["plan-kind-fund"])
            type(app.textFields["plan-name"], "Vacanza", app)
            type(app.textFields["plan-amount"], "50", app)
            _ = tap(app.buttons["plan-save"]); Thread.sleep(forTimeInterval: 1.5)
            if !app.buttons["finance-budget"].isHittable { app.swipeDown(velocity: .fast) }
            _ = tap(app.buttons["finance-budget"])
            shot(prefix + " 20c Budget con spese a rate", app)
            if tap(app.staticTexts["Vacanza"].firstMatch), tap(app.buttons["plan-record-payment"]) {
                type(app.textFields["movement-amount"], "120", app)
                for _ in 0..<5 where !app.buttons["expense-plan-existing"].isHittable { app.swipeUp(velocity: .slow) }
                shot(prefix + " 20d Paga con Nuova spesa", app)
                dismissSheet(app)
            }
            back(app); back(app)
        }
        if tap(app.buttons["primary-add"]) {
            shot(prefix + " 21 Nuova spesa", app)
            if tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tipo'")).firstMatch) { shot(prefix + " 21b Tipo", app); _ = tap(app.buttons["Spesa"].firstMatch) }
            // REVIEW-95: the split between savings and budget months appears with an amount.
            let field = app.textFields["movement-amount"]
            if field.waitForExistence(timeout: 5) {
                field.tap(); field.typeText("186")
                if app.keyboards.count > 0 { app.collectionViews.firstMatch.swipeDown(velocity: .slow) }
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
                    if app.buttons["Casa"].exists { app.buttons["Casa"].firstMatch.tap() } else { app.tap() }
                    if tap(app.buttons["movement-item"]) { shot(prefix + " 24b Voci di Casa", app); if app.buttons["Acqua"].exists { app.buttons["Acqua"].firstMatch.tap() } }
                    for _ in 0..<3 { app.swipeUp(velocity: .slow) }
                    // With the Acqua demo plan the destination is the plan: the uncovered part goes partly to budget months.
                    for _ in 0..<5 where app.buttons["expense-split-less"].exists { app.buttons["expense-split-less"].tap() }
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
