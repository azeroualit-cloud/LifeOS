import XCTest
import UIKit

final class NativeRevision71UITests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + arguments
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 30))
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func exists(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        let found = element.waitForExistence(timeout: 10)
        if !found { print("CALENDAR_DAY_DIAGNOSTIC " + app.debugDescription); capture("71-calendar-day-entry-failure") }
        return found
    }
    private func day(_ offset: Int = 0) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.date(byAdding: .day, value: offset, to: Date())!)
    }
    private func reveal(_ element: XCUIElement, in surface: XCUIElement, app: XCUIApplication) {
        for _ in 0..<24 {
            let top = max(surface.frame.minY, app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : surface.frame.minY)
            let bottom = min(surface.frame.maxY, app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY)
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let above = element.exists && element.frame.minY < top
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: above ? 90 : -90)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.isHittable, "Control must remain reachable: \(element.identifier)")
    }
    func testMonthUsesScreenAndTapOpensDayThenReturns() {
        let app = launch()
        app.tabBars.buttons["Calendario"].tap()
        let months = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(months.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(months.frame.height, app.frame.height * 0.55)
        XCTAssertFalse(app.scrollViews["calendar-day-pane"].exists)
        XCTAssertFalse(app.buttons["Esporta turni su Apple (facoltativo)"].exists)
        let today = app.buttons["calendar-day-" + day()]
        reveal(today, in: months, app: app); today.tap()
        XCTAssertTrue(exists(app.scrollViews["calendar-day-pane"], app: app))
        XCTAssertTrue(app.buttons["calendar-week-day-" + day()].isSelected)
        XCTAssertFalse(months.exists)
        capture("71-calendar-day-timeline")
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(months.waitForExistence(timeout: 10))
        capture("71-calendar-full-month")
    }
    func testDashboardExplicitDayAndCalendarEntryResumeDefaults() {
        let app = launch()
        app.buttons["dashboard-day-" + day(1)].tap()
        let explicit = app.buttons["calendar-week-day-" + day(1)]
        XCTAssertTrue(exists(explicit, app: app)); XCTAssertTrue(explicit.isSelected)
        app.tabBars.buttons["Finanza"].tap(); app.tabBars.buttons["Calendario"].tap()
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
        let today = app.buttons["calendar-day-" + day()]
        reveal(today, in: app.scrollViews["calendar-scroll"], app: app); XCTAssertTrue(today.isSelected)
        app.buttons["Mese successivo"].tap()
        XCUIDevice.shared.press(.home); app.activate()
        reveal(today, in: app.scrollViews["calendar-scroll"], app: app); XCTAssertTrue(today.isSelected)
    }
    func testAllDayEventsStayVisibleWhileTheHourTimelineScrolls() {
        let app = launch(["--activity-agenda"])
        app.tabBars.buttons["Calendario"].tap()
        let today = app.buttons["calendar-day-" + day()]
        reveal(today, in: app.scrollViews["calendar-scroll"], app: app); today.tap()
        let allDay = app.scrollViews["calendar-all-day-pane"]
        XCTAssertTrue(exists(allDay, app: app))
        let event = app.buttons["Evento oggi"]
        XCTAssertTrue(event.isHittable)
        let y = event.frame.minY
        app.scrollViews["calendar-day-pane"].swipeUp()
        XCTAssertTrue(event.isHittable); XCTAssertEqual(event.frame.minY, y, accuracy: 1)
        event.tap(); XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
    }
    func testTaskAndEventOpenTheSameBottomEditorWithoutInlineChips() {
        let app = launch(["--activity-agenda"])
        app.tabBars.buttons["Attività"].tap()
        app.buttons["Evento oggi"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["activity-title"].exists)
        XCTAssertTrue(app.buttons["activity-date-Inizio"].exists)
        XCTAssertFalse(app.buttons["inline-event-time"].exists)
        capture("71-event-editor-bottom-sheet")
        app.buttons["Annulla"].tap()
        let task = app.buttons["task-open-101"]
        reveal(task, in: app.collectionViews.firstMatch, app: app); task.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["activity-title"].value as? String, "Da fare libera")
        XCTAssertFalse(app.buttons["inline-task-delete"].exists)
        let waiting = app.buttons["Metti in attesa"]
        reveal(waiting, in: app.collectionViews.firstMatch, app: app); XCTAssertTrue(waiting.isHittable)
        XCTAssertGreaterThanOrEqual(waiting.frame.height.rounded(), 44)
        capture("71-task-editor-actions")
    }
    func testDatesEnableInOneTapClearAndKeepTimeBeforeCategory() {
        let app = launch()
        app.tabBars.buttons["Attività"].tap(); app.buttons["primary-add"].tap()
        let start = app.buttons["activity-date-Inizio"], due = app.buttons["activity-date-Scadenza"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertEqual(start.frame.midY, due.frame.midY, accuracy: 2)
        XCTAssertFalse(app.buttons["Rimuovi inizio"].exists); XCTAssertFalse(app.buttons["Rimuovi scadenza"].exists)
        start.tap()
        XCTAssertTrue(app.buttons["Fine"].waitForExistence(timeout: 10)); app.buttons["Fine"].tap()
        XCTAssertTrue(app.buttons["Rimuovi inizio"].exists)
        due.tap(); app.buttons["Fine"].tap()
        let startTime = app.buttons["Ora iniziale"], endTime = app.buttons["Ora finale"]
        XCTAssertTrue(startTime.exists); XCTAssertTrue(endTime.exists)
        XCTAssertLessThan(startTime.frame.minY, app.textFields["Luogo"].frame.minY)
        XCTAssertLessThan(endTime.frame.minY, app.textFields["Luogo"].frame.minY)
        startTime.tap()
        XCTAssertTrue(app.datePickers.firstMatch.exists)
        app.buttons["Rimuovi inizio"].tap(); app.buttons["Rimuovi scadenza"].tap()
        XCTAssertFalse(app.buttons["Rimuovi inizio"].exists); XCTAssertFalse(app.buttons["Rimuovi scadenza"].exists)
        capture("71-editor-inline-date-time")
    }
    func testSheetSavesTitleAndDescriptionAcrossReopen() {
        let app = launch()
        app.tabBars.buttons["Attività"].tap(); app.buttons["task-open-1"].tap()
        let title = app.textFields["activity-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText(" prova")
        let edited = title.value as? String
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Dashboard"].tap(); app.tabBars.buttons["Attività"].tap()
        app.buttons["task-open-1"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10)); XCTAssertEqual(title.value as? String, edited)
        app.buttons["Annulla"].tap()
    }
    func testPaintingHasGlassPaletteAndRapidEditsPreserveLastIntentAndUndo() {
        let app = launch()
        app.tabBars.buttons["Calendario"].tap(); app.buttons["toggle-shift-paint"].tap()
        for kind in ["morning", "afternoon", "night", "rest", "holiday", "erase"] {
            let brush = app.buttons["shift-brush-" + kind]
            XCTAssertTrue(brush.exists); XCTAssertGreaterThanOrEqual(brush.frame.width.rounded(), 44)
            XCTAssertGreaterThanOrEqual(brush.frame.height.rounded(), 44)
        }
        let today = app.buttons["calendar-day-" + day()]
        reveal(today, in: app.scrollViews["calendar-scroll"], app: app)
        for (kind, label) in [("morning", "Mattina"), ("afternoon", "Pomeriggio"), ("rest", "Riposo")] {
            app.buttons["shift-brush-" + kind].tap(); today.tap()
            expectation(for: NSPredicate(format: "label CONTAINS %@", label), evaluatedWith: today); waitForExpectations(timeout: 5)
        }
        XCTAssertFalse(app.scrollViews["calendar-day-pane"].exists)
        app.buttons["Annulla"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Pomeriggio"), evaluatedWith: today); waitForExpectations(timeout: 5)
        capture("71-supershift-glass-painting")
    }
    func testFinanceMatchesOpenLayoutAndKeepsBudgetAnalysisAndExpense() {
        let app = launch()
        app.tabBars.buttons["Finanza"].tap()
        let surface = app.scrollViews["finance-scroll"]
        let hero = app.staticTexts["finance-budget-value"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertLessThan(hero.frame.minX, app.frame.width * 0.15)
        XCTAssertTrue(app.staticTexts["CONTO PRINCIPALE"].exists)
        let budget = app.buttons["finance-budget"], analysis = app.buttons["finance-analysis"]
        reveal(budget, in: surface, app: app); XCTAssertTrue(analysis.exists)
        XCTAssertGreaterThanOrEqual(budget.frame.height.rounded(), 44)
        capture("71-finance-reference-layout")
        analysis.tap(); XCTAssertTrue(app.navigationBars["Analisi"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(budget, in: surface, app: app); budget.tap(); XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["finance-more"].tap(); app.buttons["Nuovo piano"].tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10)); app.buttons["Annulla"].tap()
        app.buttons["primary-add"].tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        let all = app.buttons["all-movements"]
        reveal(all, in: surface, app: app); all.tap()
        XCTAssertTrue(app.navigationBars["Movimenti"].waitForExistence(timeout: 10))
    }
    func testDashboardShowsDateWithoutGreetingOrWeatherAndHealthOpens() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["home-today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["home-greeting"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "A Empoli,")).firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-")).count, 7)
        let health = app.buttons["home-health-detail"]
        reveal(health, in: app.scrollViews["dashboard-scroll"], app: app)
        capture("71-dashboard-health-accent")
        health.tap(); XCTAssertTrue(app.navigationBars["Peso e calorie"].waitForExistence(timeout: 10))
    }
    func testReducedMotionAndLargeTextKeepMonthDayAndEditorUsable() {
        let app = launch(["--reduce-motion", "--large-text"])
        app.tabBars.buttons["Calendario"].tap()
        let today = app.buttons["calendar-day-" + day()]
        reveal(today, in: app.scrollViews["calendar-scroll"], app: app); today.tap()
        XCTAssertTrue(exists(app.buttons["calendar-back-month"], app: app))
        app.buttons["primary-add"].tap()
        XCTAssertTrue(app.navigationBars["Nuova attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["activity-date-Inizio"].exists)
        app.buttons["Annulla"].tap()
        app.buttons["calendar-back-month"].tap()
        XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
        capture("71-calendar-large-text-reduced-motion")
    }
}
