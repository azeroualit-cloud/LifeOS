import XCTest
import UIKit

final class NativeInterfaceTests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 30))
        return app
    }
    private func assertMinimumTouchTarget(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let scale = UIScreen.main.scale
        // Compare physical pixels: CGFloat layout can report 43.99999999999994 for a 44pt target.
        XCTAssertGreaterThanOrEqual((element.frame.width * scale).rounded(), 44 * scale, "Larghezza insufficiente: \(element.identifier), frame \(element.frame)", file: file, line: line)
        XCTAssertGreaterThanOrEqual((element.frame.height * scale).rounded(), 44 * scale, "Altezza insufficiente: \(element.identifier), frame \(element.frame)", file: file, line: line)
    }
    private func selectFinanceSection(_ title: String, in app: XCUIApplication) {
        if title == "Extra" || title == "Piani" {
            let action = app.buttons["finance-budget"]
            for _ in 0..<5 { if action.isHittable { break }; app.scrollViews["finance-scroll"].swipeDown() }
            XCTAssertTrue(action.waitForExistence(timeout: 10)); action.tap()
            XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.staticTexts["finance-heading"].waitForExistence(timeout: 10))
        }
    }
    private func addButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@", "primary-add", "Aggiungi ")).firstMatch
    }
    private func openBudget(_ app: XCUIApplication) {
        let action = app.buttons["finance-budget"]
        for _ in 0..<5 { if action.isHittable { break }; app.scrollViews["finance-scroll"].swipeDown() }
        XCTAssertTrue(action.isHittable); action.tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
    }
    private func revealChecklistButton(_ button: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        let list = app.collectionViews.firstMatch
        let upper = app.navigationBars.firstMatch.frame.maxY
        let lower = app.mainTabBar.frame.minY
        for _ in 0..<16 {
            if button.exists && button.isHittable && button.frame.minY >= upper && button.frame.maxY <= lower { return }
            if towardTop || (button.exists && button.frame.minY < upper) { list.swipeDown(velocity: .slow) }
            else { list.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(button.exists && button.isHittable, "Il completamento deve restare raggiungibile nella propria sezione")
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testInformativeWidgetFitsBothSmallWidths() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--widget-preview", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Anteprima widget"].waitForExistence(timeout: 20))
        let normal = app.otherElements["widget-preview-small"]
        let compact = app.otherElements["widget-preview-compact"]
        XCTAssertTrue(normal.exists); XCTAssertTrue(compact.exists)
        XCTAssertEqual(normal.frame.width, 170, accuracy: 1)
        XCTAssertEqual(compact.frame.width, 141, accuracy: 1)
        let actions = app.descendants(matching: .any).matching(identifier: "widget-add")
        XCTAssertGreaterThanOrEqual(actions.count, 2)
        assertMinimumTouchTarget(actions.firstMatch)
        capture("widget-informative-2x2-dark")
    }

    func testDashboardWeekShiftProgressAndFinanceGlassActions() {
        let app = launch(["--dark", "--active-shift"])
        XCTAssertTrue(app.buttons["home-focus"].waitForExistence(timeout: 10))
        assertMinimumTouchTarget(app.buttons["home-focus"])
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "alla fine")).firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-")).count, 7)
        capture("dashboard-week-80-and-shift-progress")
        app.openOtherDestination("Finanza")
        for name in ["finance-budget", "finance-analysis", "finance-new-plan", "all-movements", "primary-add"] {
            let button = app.buttons[name]; XCTAssertTrue(button.waitForExistence(timeout: 10)); assertMinimumTouchTarget(button)
        }
        capture("finance-native-glass-actions")
    }
    private func revealCalendarDay(_ day: String, in app: XCUIApplication) {
        let cell = app.buttons["calendar-day-" + day], surface = app.scrollViews["calendar-scroll"]
        for attempt in 0..<20 {
            let heading = app.staticTexts["calendar-month-heading-" + String(day.prefix(7))]
            let top = max(surface.frame.minY, heading.exists && heading.frame.minY < surface.frame.minY + 60 ? heading.frame.maxY : surface.frame.minY)
            if cell.exists && cell.isHittable && cell.frame.minY >= top && cell.frame.maxY <= surface.frame.maxY { return }
            let offset: CGFloat
            if cell.exists && cell.frame.height > 0 { offset = cell.frame.midY - (top + surface.frame.maxY) / 2 }
            else { offset = day < Self.today() ? -60 : 60 }
            let limit = min(60, surface.frame.height * 0.35)
            let distance = min(limit, max(-limit, offset))
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            print("QA_CALENDAR_SCROLL step=\(attempt) day=\(day) cell=\(cell.frame) viewport=\(surface.frame) distance=\(distance)")
            // Holding before release removes the fling that overshot both sides of small panes.
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)), withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        print("QA_CALENDAR_GEOMETRY day=\(day) cell=\(cell.frame) viewport=\(surface.frame)")
        capture("calendar-date-unreachable")
        XCTAssertTrue(cell.isHittable, "Selected calendar date must remain reachable in its own pane")
        XCTAssertGreaterThanOrEqual(cell.frame.minY, surface.frame.minY)
        XCTAssertLessThanOrEqual(cell.frame.maxY, surface.frame.maxY)
    }
    func testUnifiedActivityEditorPreservesDescriptionWhenAddingAndRemovingDate() {
        let app = launch(["--dark"])
        app.openMainTab("Attività")
        app.buttons["primary-add"].tap()
        let title = app.textFields["activity-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap(); title.typeText("Attività unificata test")
        let notes = app.textViews["Descrizione"]
        notes.tap(); notes.typeText("Descrizione persistente")
        app.buttons["Salva"].tap()
        let activity = app.buttons["Attività unificata test"]
        revealChecklistButton(activity, in: app); activity.tap()
        XCTAssertTrue(app.textFields["activity-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textViews["Descrizione"].value as? String, "Descrizione persistente")
        app.buttons["activity-date-Inizio"].tap(); app.buttons["Fine"].tap()
        capture("unified-activity-editor-dark")
        app.buttons["Salva"].tap()
        app.mainTabBar.buttons["Dashboard"].tap()
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-")).matching(NSPredicate(format: "label CONTAINS %@", "Attività unificata test")).firstMatch
        reveal(event, in: app)
        XCTAssertTrue(event.isHittable); event.tap()
        XCTAssertTrue(app.textViews["Descrizione"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textViews["Descrizione"].value as? String, "Descrizione persistente")
        app.buttons["Rimuovi inizio"].tap(); app.buttons["Salva"].tap()
        app.openMainTab("Attività")
        let restored = app.buttons["Cambia completamento Attività unificata test"]
        revealChecklistButton(restored, in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "Cambia completamento Attività unificata test").count, 1)
        let collapsed = app.buttons["Attività unificata test"]
        if collapsed.exists { collapsed.tap() }
        XCTAssertTrue(app.textViews["Descrizione"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textViews["Descrizione"].value as? String, "Descrizione persistente")
    }
    func testDashboardEventsAndRoutinesOrderAndCompletion() {
        let app = launch(["--busy-home", "--dark"])
        XCTAssertTrue(app.staticTexts["home-checklist-heading"].waitForExistence(timeout: 10))
        let events = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-"))
        XCTAssertEqual(events.count, 8, "Only today and the next two civil dates belong in Dashboard")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-5-")).firstMatch
        let check = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-event-check-5-")).firstMatch
        let routine = app.buttons["Completa abitudine Abitudine con un nome molto lungo da leggere senza sovrapposizioni"]
        let upcoming = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-1-")).firstMatch
        XCTAssertTrue(row.exists); XCTAssertTrue(routine.exists); XCTAssertTrue(upcoming.exists)
        XCTAssertLessThan(row.frame.minY, routine.frame.minY, "Today's events precede today's habits")
        XCTAssertLessThan(routine.frame.minY, upcoming.frame.minY, "Upcoming events follow today's habits")
        reveal(check, in: app); assertMinimumTouchTarget(check); assertMinimumTouchTarget(row)
        XCTAssertEqual(check.value as? String, "Da completare")
        capture("dashboard-events-and-routines-dark")
        check.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: check)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.navigationBars["Dashboard"].exists)
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        XCTAssertEqual(events.count, 7)
        let remaining = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-10-")).firstMatch
        reveal(remaining, in: app); remaining.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
    }
    private static func today() -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    func testStandardizedHealthAndCompactShiftPalette() {
        let app = launch(["--dark"])
        capture("dashboard-weekly-structure-dark")
        app.mainTabBar.buttons["Salute"].tap()
        let health = app.buttons["health-summary-weight"]
        XCTAssertTrue(health.waitForExistence(timeout: 10))
        // Build 93: the weight card is in Andamento, below the day (HEALTH-TREND-93-2026-11-21).
        for _ in 0..<8 where !health.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
        XCTAssertTrue(health.isHittable)
        XCTAssertLessThan(health.frame.maxY, app.mainTabBar.frame.minY)
        capture("health-standardized-dark")
        app.openOtherDestination("Calendario")
        app.buttons["toggle-shift-paint"].tap()
        let first = app.buttons["shift-brush-morning"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let palette = app.scrollViews["shift-brush-scroll"]
        XCTAssertTrue(palette.exists)
        XCTAssertLessThan(palette.frame.height, app.frame.height * 0.2)
        XCTAssertGreaterThanOrEqual(first.frame.height.rounded(), 44)
        XCTAssertTrue(first.label.contains("Mattina"))
        capture("compact-shift-palette-dark")
    }
    func testActivityAgendaShowsOnlyRelevantItemsAndFoldsCompleted() {
        let app = launch(["--dark", "--activity-agenda"])
        app.openMainTab("Attività")
        XCTAssertTrue(app.staticTexts["Evento oggi"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Evento domani"].exists)
        XCTAssertLessThan(app.staticTexts["Evento oggi"].frame.minY, app.staticTexts["Evento domani"].frame.minY)
        for title in ["Attività futura nascosta", "Evento oltre settimana", "Evento passato", "Evento già completato", "Attività archiviata"] {
            XCTAssertFalse(app.staticTexts[title].exists)
        }
        let week = app.buttons["Cambia completamento evento Evento fra sette giorni"]
        revealChecklistButton(week, in: app)
        let archived = app.buttons["toggle-completed-tasks"]
        revealChecklistButton(archived, in: app)
        XCTAssertEqual(archived.value as? String, "Chiusa")
        capture("agenda-rolling-week-completed-collapsed")
        archived.tap()
        XCTAssertTrue(NSPredicate(format: "value == %@", "Aperta").evaluate(with: archived), "Il centro dell’intestazione deve aprire le completate")
        let completion = app.buttons["Cambia completamento Attività archiviata"]
        revealChecklistButton(completion, in: app)
        XCTAssertEqual(completion.value as? String, "Completata")
        capture("agenda-completed-expanded")
        completion.tap()
        XCTAssertTrue(app.buttons["toggle-completed-tasks"].waitForNonExistence(timeout: 10))
        revealChecklistButton(completion, in: app, towardTop: true)
        XCTAssertEqual(completion.value as? String, "Da completare")
    }

    func testCalendarRepeatedScrollingKeepsMonthAnchorsAndReturnsToToday() {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<8 { scroll.swipeUp(velocity: .fast) }
        for _ in 0..<8 { scroll.swipeDown(velocity: .fast) }
        app.buttons["calendar-today"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date()), cell = app.buttons["calendar-day-" + day]
        capture("calendar-after-repeated-scroll-and-today")
        print("CALENDAR_RETURN_TODAY " + app.debugDescription)
        XCTAssertTrue(cell.waitForExistence(timeout: 10)); XCTAssertTrue(cell.isSelected)
        XCTAssertEqual(app.buttons.matching(identifier: "calendar-day-" + day).count,1)
        capture("calendar-after-repeated-scroll-and-today")
    }

    func testRepeatedTabSwitchesKeepNativeDestinationsUsable() {
        let app = launch(["--dark"])
        for _ in 0..<3 {
            for name in ["Dashboard", "Attività", "Salute", "Bloom"] {
                app.openMainTab(name)
                XCTAssertTrue(app.isMainTabSelected(name))
                if name == "Salute" { XCTAssertTrue(app.buttons["health-summary-tdee"].waitForExistence(timeout: 10)) }
                if name == "Dashboard" || name == "Attività" { XCTAssertTrue(app.buttons["primary-add"].isHittable) }
            }
            app.openOtherDestination("Calendario")
            XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
            app.openOtherDestination("Finanza")
            XCTAssertTrue(app.scrollViews["finance-scroll"].waitForExistence(timeout: 10))
        }
        capture("native-tabs-after-repeated-switches")
    }

    func testShiftExportRemainsReachableFromSettings() {
        let app = launch(["--dark"])
        app.buttons["Impostazioni"].tap()
        let action = app.buttons["shift-export-settings"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<12 { if action.isHittable { break }; form.swipeUp(velocity: .slow) }
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(action.isHittable)
        action.tap()
        XCTAssertTrue(app.navigationBars["Esporta turni"].waitForExistence(timeout: 10))
        capture("shift-export-settings-reachable")
    }
    func testOffDayHabitIsHiddenButRemainsManageable() {
        let app = launch(["--dark", "--off-day-habit"])
        XCTAssertFalse(app.buttons["Completa abitudine Abitudine di domani"].exists)
        app.buttons["Gestisci"].tap(); app.buttons["Abitudini"].tap()
        let habit = app.buttons["routine-edit-999"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<8 { if habit.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
    }

    func testCalendarScrollPerformance() {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            scroll.swipeUp(velocity: .fast)
            scroll.swipeDown(velocity: .fast)
        }
        capture("calendar-scroll-performance")
    }
    func testHabitIntervalAndWeekdaySchedulingPersistInManagement() {
        let app = launch(["--dark"])
        func show(_ element: XCUIElement, towardTop: Bool = false) {
            let form = app.collectionViews.firstMatch
            for _ in 0..<10 {
                if element.isHittable { return }
                if towardTop || (element.exists && element.frame.midY < form.frame.minY) { form.swipeDown() } else { form.swipeUp() }
            }
            XCTAssertTrue(element.isHittable)
        }
        app.buttons["Gestisci"].tap(); app.buttons["Abitudini"].tap()
        XCTAssertTrue(app.navigationBars["Abitudini"].waitForExistence(timeout: 10))
        let name = app.textFields["routine-name"]; show(name); name.tap(); name.typeText("Allenamento programmato")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10))
        name.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 10), "Return must dismiss the keyboard before saving the habit")
        // Build 93: repetition is a segmented control, weekdays are letter buttons.
        let interval = app.buttons["routine-repeat-interval"]; show(interval); interval.tap()
        let save = app.buttons["routine-save"]; show(save); save.tap()
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "routine-edit-", "Allenamento programmato")).firstMatch
        show(edit, towardTop: true); XCTAssertTrue(edit.waitForExistence(timeout: 10)); XCTAssertTrue(edit.label.contains("Ogni 2 giorni")); edit.tap()
        let weekly = app.buttons["routine-repeat-weekdays"]; show(weekly); weekly.tap()
        let monday = app.buttons["routine-weekday-1"]; show(monday); XCTAssertTrue(monday.waitForExistence(timeout: 10))
        XCTAssertFalse(monday.isSelected)
        monday.tap()
        XCTAssertTrue(monday.isSelected, monday.debugDescription)
        capture("habit-weekday-selected")
        show(save); XCTAssertTrue(save.isEnabled, "Save disabled after weekday selection"); save.tap()
        show(edit, towardTop: true)
        print("HABIT_SAVED_ROW: " + edit.debugDescription)
        XCTAssertTrue(edit.label.contains("Lunedì"), "Saved habit label: " + edit.label)
        edit.tap(); show(monday); XCTAssertTrue(monday.isSelected, monday.debugDescription)
        capture("habits-weekday-schedule")
    }
    func testHealthWeightSummaryOpensDetailInEachAppearance() {
        for arguments in [["--dark"], [], ["--dark", "--large-text"]] {
            let app = launch(arguments)
            app.mainTabBar.buttons["Salute"].tap()
            let detail = app.buttons["health-summary-weight"]
            XCTAssertTrue(detail.waitForExistence(timeout: 10))
            let scroll = app.scrollViews["health-detail-scroll"]
            for _ in 0..<8 {
                if detail.isHittable && detail.frame.minY >= scroll.frame.minY && detail.frame.maxY <= app.mainTabBar.frame.minY { break }
                scroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(detail.isHittable)
            XCTAssertGreaterThanOrEqual(detail.frame.minY, scroll.frame.minY)
            XCTAssertLessThanOrEqual(detail.frame.maxY, app.mainTabBar.frame.minY)
            XCTAssertGreaterThanOrEqual(detail.frame.minX, 0)
            XCTAssertLessThanOrEqual(detail.frame.maxX, app.frame.maxX)
            capture(arguments.contains("--large-text") ? "health-summary-large-text" : arguments.isEmpty ? "health-summary-light" : "health-summary-dark")
            detail.tap(); XCTAssertTrue(app.navigationBars["Peso"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "health-weight-chart").firstMatch.waitForExistence(timeout: 10))
            app.terminate()
        }
    }
    func testFourSectionsInLightTheme() { verifyFourSections(dark: false) }
    func testFourSectionsInDarkTheme() { verifyFourSections(dark: true) }
    private func verifyFourSections(dark: Bool) {
        // Independent appearance budgets retain every destination and editor.
        executionTimeAllowance = 300
        let app = launch(dark ? ["--dark"] : [])
        for name in ["Dashboard", "Attività", "Salute", "Bloom"] {
            app.openMainTab(name); XCTAssertTrue(app.isMainTabSelected(name))
            if name == "Salute" {
                XCTAssertTrue(app.buttons["health-summary-tdee"].waitForExistence(timeout: 10))
                capture((dark ? "dark-" : "light-") + "Salute")
            }
            if name == "Bloom" {
                XCTAssertTrue(app.buttons["bloom-section-library"].waitForExistence(timeout: 10))
                capture((dark ? "dark-" : "light-") + "Bloom")
            }
        }
        for page in ["Dashboard", "Attività", "Calendario", "Finanza"] {
            if page == "Calendario" || page == "Finanza" { app.openOtherDestination(page) }
            else { app.openMainTab(page) }
            let add = app.buttons["primary-add"]
            XCTAssertTrue(add.waitForExistence(timeout: 10)); XCTAssertTrue(add.isHittable)
            assertMinimumTouchTarget(add); add.tap()
            let editor = page == "Attività" || page == "Calendario" ? "Nuova attività" : "Nuovo movimento"
            XCTAssertTrue(app.navigationBars[editor].waitForExistence(timeout: 10))
            app.buttons["Annulla"].tap()
            let host = page == "Calendario" || page == "Finanza" ? "Dashboard" : page
            XCTAssertTrue(app.isMainTabSelected(host))
            // Wait for the editor sheet to finish dismissing before checking the action again.
            let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["primary-add"])
            XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
            XCTAssertTrue(app.mainTabBar.exists)
            if page == "Finanza" { XCTAssertTrue(app.staticTexts["finance-budget-value"].exists) }
            capture((dark ? "dark-" : "light-") + page)
        }
        app.terminate()
    }

    func testNativeToolbarRespondsAcross44PointTouchRegion() {
        for dark in [false, true] {
            let app = launch(dark ? ["--dark"] : [])
            // 21.5pt from the centre samples just inside each edge of a 44pt target.
            // Coordinates are relative to the app, so XCTest cannot snap to the
            // button centre or substitute its own inferred hit point.
            for offset in [CGVector(dx: 0, dy: -21.5), CGVector(dx: 0, dy: 21.5),
                           CGVector(dx: -21.5, dy: 0), CGVector(dx: 21.5, dy: 0)] {
                for (identifier, title, dismiss) in [("primary-add", "Nuovo movimento", "Annulla"),
                                                       ("Impostazioni", "Impostazioni", "Fine")] {
                    let button = app.navigationBars.buttons[identifier]
                    XCTAssertTrue(button.isHittable)
                    assertMinimumTouchTarget(button)
                    let frame = button.frame
                    let point = CGVector(dx: frame.midX - app.frame.minX + offset.dx,
                                         dy: frame.midY - app.frame.minY + offset.dy)
                    let touch = app.coordinate(withNormalizedOffset: .zero).withOffset(point)
                    XCTAssertEqual(touch.screenPoint.x, frame.midX + offset.dx, accuracy: 0.1)
                    XCTAssertEqual(touch.screenPoint.y, frame.midY + offset.dy, accuracy: 0.1)
                    touch.tap()
                    XCTAssertTrue((title == "Finanza" ? app.staticTexts["finance-heading"] : app.navigationBars[title]).waitForExistence(timeout: 5),
                                  "Toolbar non risponde a \(offset) dal centro: \(identifier), frame \(frame)")
                    app.buttons[dismiss].tap()
                    XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
                }
            }
            capture(dark ? "native-toolbar-hit-region-dark" : "native-toolbar-hit-region-light")
            app.terminate()
        }
    }
    func testNavigationKeepsSelectionAndGeometryWhenChangingTabs() {
        let app = launch(["--stress-content", "--dark"])
        let initial = app.mainTabBar.buttons["Dashboard"].frame
        for title in ["Finanza", "Attività", "Calendario", "Dashboard", "Calendario", "Attività", "Dashboard"] {
            if title == "Finanza" || title == "Calendario" { app.openOtherDestination(title) }
            else {
                let reselectingDashboard = title == "Dashboard" && app.mainTabBar.buttons["Dashboard"].isSelected
                app.openMainTab(title)
                if title == "Dashboard" && !reselectingDashboard {
                    // Returning from another tab retains Dashboard's calendar stack.
                    XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
                    let back = app.buttons["other-back"]
                    XCTAssertTrue(back.waitForExistence(timeout: 10)); back.tap()
                }
                // Reselecting an already active Dashboard tab returns to its root.
            }
            let destination = title == "Finanza" ? app.staticTexts["finance-heading"] : (title == "Calendario" ? app.scrollViews["calendar-scroll"] : app.navigationBars[title])
            XCTAssertTrue(destination.waitForExistence(timeout: 10))
            let host = title == "Finanza" || title == "Calendario" ? "Dashboard" : title
            XCTAssertTrue(app.isMainTabSelected(host))
            assertMinimumTouchTarget(app.mainTabButton(host))
            for other in ["Dashboard", "Attività", "Salute", "Bloom"] where other != host {
                XCTAssertFalse(app.isMainTabSelected(other))
            }
            let frame = app.mainTabBar.buttons["Dashboard"].frame
            XCTAssertEqual(frame.minY, initial.minY, accuracy: 1)
            XCTAssertEqual(frame.width, initial.width, accuracy: 1)
            XCTAssertTrue(addButton(app).isHittable)
        }
        capture("navigation-selection-after-repeated-changes")
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let detailScroll = app.scrollViews["health-detail-scroll"]
        let scroll = detailScroll.exists ? detailScroll : app.scrollViews["dashboard-scroll"]
        for _ in 0..<12 {
            if element.isHittable { return }
            let above = element.exists && element.frame.midY < scroll.frame.minY
            let from = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.75))
            let to = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.75 : 0.35))
            from.press(forDuration: 0.1, thenDragTo: to)
        }
    }
    func testDashboardFocusTimelineOpensEventWithoutDuplicateSummary() {
        let app = launch(["--dark", "--active-shift"])
        let focus = app.buttons["home-focus"]
        XCTAssertTrue(focus.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(focus)
        XCTAssertFalse(app.staticTexts["home-summary"].exists)
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-")).firstMatch
        reveal(event, in: app)
        XCTAssertTrue(event.isHittable); assertMinimumTouchTarget(event)
        capture("dashboard-focus-timeline-dark")
        event.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        capture("dashboard-timeline-event-editor")
    }

    private func revealExpenseFormElement(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        let top = app.navigationBars.firstMatch.frame.maxY + 4
        let bottom = min(list.frame.maxY, app.frame.maxY) - 8
        for _ in 0..<16 {
            if element.exists {
                let frame = element.frame
                if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
                let above = frame.midY < top
                list.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: above ? 0.4 : 0.65))
                    .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: above ? 0.65 : 0.4)))
            } else {
                list.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.65))
                    .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.4)))
            }
        }
        capture("expense-form-element-unreachable")
        XCTFail("Il controllo deve essere visibile e premibile nel modulo: " + element.identifier)
    }
    func testExpenseAutomaticallyOffersWaterFundAndCanChangeExistingDestination() {
        let app = launch(["--dark", "--expense-routing"])
        addButton(app).tap()
        let amount = app.textFields["movement-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10)); amount.tap(); amount.typeText("30")
        let name = app.textFields["movement-name"]; name.tap(); name.typeText("Acqua UI67")
        app.buttons["movement-hide-keyboard"].tap()
        let category = app.buttons["movement-category"]
        for _ in 0..<5 { if category.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        category.tap()
        // REFERENCE-GAPS-95: Categoria (Casa) first, then the Voce menu holds Acqua.
        let home = app.buttons["Casa"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 5)); home.tap()
        let item = app.buttons["movement-item"]
        for _ in 0..<5 { if item.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        item.tap()
        let water = app.buttons["Acqua"]
        for _ in 0..<6 {
            if water.exists && water.isHittable { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture("expense-category-menu-compact")
        XCTAssertTrue(water.isHittable); water.tap()
        let initialDestination = app.buttons["expense-destination"]
        revealExpenseFormElement(initialDestination, in: app)
        XCTAssertTrue(initialDestination.isHittable)
        XCTAssertTrue(initialDestination.label.contains("Acqua"))
        let savings = app.descendants(matching: .any).matching(identifier: "expense-savings-preview").firstMatch
        revealExpenseFormElement(savings, in: app)
        XCTAssertTrue(savings.isHittable)
        XCTAssertTrue(app.staticTexts["Dagli altri risparmi"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "10,00")).firstMatch.exists)
        capture("expense-water-fund-and-savings-preview")
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.mainTabBar.buttons["Dashboard"].waitForExistence(timeout: 10)); app.openOtherDestination("Finanza")
        let all = app.buttons["all-movements"]
        for _ in 0..<6 { if all.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        all.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Acqua UI67")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        let change = app.buttons["movement-change-destination"]
        revealExpenseFormElement(change, in: app)
        XCTAssertTrue(change.isHittable); change.tap()
        let destination = app.segmentedControls.firstMatch
        revealExpenseFormElement(destination, in: app)
        XCTAssertTrue(destination.waitForExistence(timeout: 10)); XCTAssertTrue(destination.isHittable)
        _ = destination // FINANCE-ENTRY-SIMPLIFY: Budget / Risparmi / Piano is a segment
        app.segmentedControls.buttons.visible("Budget").tap()
        capture("expense-change-existing-destination")
        let confirm = app.buttons["expense-destination-confirm"]
        XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.navigationBars["Modifica movimento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Budget mensile"].exists)
    }
    func testHomeSummaryAndVerticalRoutinesInBothThemes() {
        for dark in [false, true] {
            let app = launch(dark ? ["--dark"] : [])
            let summary = app.staticTexts["home-today"]
            XCTAssertTrue(summary.waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-")).firstMatch.exists)
            XCTAssertFalse(summary.label.contains("dalle")); XCTAssertFalse(app.otherElements["today-condition"].exists)
            let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-"))
            XCTAssertEqual(days.count, 7); XCTAssertTrue(days.element(boundBy: 3).isSelected)
            XCTAssertEqual(days.element(boundBy: 3).frame.midX, app.frame.midX, accuracy: 1)
            capture(dark ? "home-editorial-dark" : "home-editorial-light")
            let routine = app.buttons["Completa abitudine Leggere"]
            reveal(routine, in: app); XCTAssertTrue(routine.isHittable); assertMinimumTouchTarget(routine)
            let before = routine.value as? String; routine.tap()
            expectation(for: NSPredicate(format: "value != %@", before ?? ""), evaluatedWith: routine)
            waitForExpectations(timeout: 10)
            XCTAssertFalse(app.staticTexts["home-todos-heading"].exists)
            app.mainTabBar.buttons["Salute"].tap()
            let weight = app.buttons["health-summary-weight"]
            XCTAssertTrue(weight.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["health-connect"].exists)
            XCTAssertTrue(app.buttons["health-add-weight"].exists)
            let simulation = app.buttons["health-summary-simulation"]
            for _ in 0..<8 where !simulation.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
            XCTAssertTrue(simulation.isHittable); simulation.tap()
            // Build 93 simulation opens on the real trend; the intake field belongs to "Calorie".
            let caloriesMode = app.buttons["simulation-mode-calories"]
            XCTAssertTrue(caloriesMode.waitForExistence(timeout: 10)); caloriesMode.tap()
            XCTAssertTrue(app.textFields["health-intake"].waitForExistence(timeout: 10))
            capture(dark ? "health-scenario-dark" : "health-scenario-light")
            app.terminate()
        }
    }
    func testHomeEmptyStatesRemainActionable() {
        let app = launch(["--empty-home", "--dark"])
        XCTAssertTrue(app.staticTexts["home-today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Nessun impegno da mostrare"].exists)
        XCTAssertFalse(app.buttons["home-focus"].exists)
        let manage = app.buttons["Gestisci"]
        XCTAssertTrue(manage.isHittable); manage.tap(); app.buttons["Abitudini"].tap()
        XCTAssertTrue(app.navigationBars["Abitudini"].waitForExistence(timeout: 10))
        app.buttons["Fine"].tap()
        app.mainTabBar.buttons["Salute"].tap()
        XCTAssertTrue(app.buttons["health-summary-tdee"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["health-connect"].exists)
        app.openMainTab("Attività")
        XCTAssertTrue(app.navigationBars["Attività"].waitForExistence(timeout: 10))
        app.mainTabBar.buttons["Dashboard"].tap()
        capture("home-empty")
    }
    func testHealthQuickWeightEntryPersistsAfterDismiss() {
        let app = launch(["--dark"])
        app.mainTabBar.buttons["Salute"].tap()
        let add = app.buttons["health-add-weight"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        for _ in 0..<6 where !add.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
        XCTAssertTrue(add.isHittable); assertMinimumTouchTarget(add); add.tap()
        XCTAssertTrue(app.navigationBars["Aggiungi peso"].waitForExistence(timeout: 10))
        let save = app.buttons["health-save-weight"]
        XCTAssertFalse(save.isEnabled)
        let field = app.textFields["health-new-weight"]
        field.tap(); field.typeText("83,4")
        XCTAssertTrue(save.isEnabled); save.tap()
        let detail = app.buttons["health-summary-weight"]
        for _ in 0..<8 where !detail.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
        XCTAssertTrue(detail.waitForExistence(timeout: 10)); XCTAssertTrue(detail.label.contains("83,4"))
        XCTAssertEqual(app.mainTabBar.buttons.count, 5)
        add.tap(); app.buttons["Annulla"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 10)); XCTAssertTrue(detail.label.contains("83,4"))
    }
    func testHealthSummaryAndFinanceMonthRoundTrip() {
        let app = launch(["--dark"])
        app.mainTabBar.buttons["Salute"].tap()
        XCTAssertTrue(app.buttons["health-summary-simulation"].waitForExistence(timeout: 10))
        capture("health-forecast-summary")
        app.openOtherDestination("Finanza")
        // Build 95: the month is a chip with a menu (Mese precedente / Mese successivo).
        let month = app.buttons["finance-month"]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        let current = month.label
        for _ in 0..<3 { month.tap(); app.buttons["Mese successivo"].tap() }
        XCTAssertNotEqual(month.label, current)
        for _ in 0..<3 { month.tap(); app.buttons["Mese precedente"].tap() }
        XCTAssertEqual(month.label, current)
        capture("finance-returned-to-current-month")
    }
    func testHealthScenarioCanBeEditedWithoutAddingNavigationTab() {
        let app = launch(["--dark"])
        app.mainTabBar.buttons["Salute"].tap()
        let calories = app.buttons["health-summary-calories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 10)); calories.tap()
        XCTAssertTrue(app.navigationBars["Calorie"].waitForExistence(timeout: 10))
        let caloriesPeriod = app.segmentedControls["health-calories-period"]
        reveal(caloriesPeriod, in: app)
        XCTAssertTrue(caloriesPeriod.isHittable)
        for period in ["Settimana", "Mese", "3 mesi"] {
            caloriesPeriod.buttons[period].tap()
            XCTAssertTrue(caloriesPeriod.buttons[period].isSelected)
        }
        app.navigationBars.buttons.firstMatch.tap()
        let simulation = app.buttons["health-summary-simulation"]
        XCTAssertTrue(simulation.waitForExistence(timeout: 10))
        for _ in 0..<8 where !simulation.isHittable { app.scrollViews["health-detail-scroll"].swipeUp() }
        simulation.tap()
    // Build 93 simulation opens on the real trend; the intake field belongs to "Calorie".
        let caloriesMode = app.buttons["simulation-mode-calories"]
        XCTAssertTrue(caloriesMode.waitForExistence(timeout: 10)); caloriesMode.tap()
        let field = app.textFields["health-intake"]
        let scroll = app.scrollViews["health-detail-scroll"]
        for _ in 0..<5 { if field.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(field.isHittable)
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "2100")
        app.buttons["Fine"].tap()
        XCTAssertEqual(field.value as? String, "2100")
        XCTAssertEqual(app.mainTabBar.buttons.count, 5)
        capture("health-scenario-2100")
    }
    func testHomeManyEventsAndTasksStayBoundedAndReachable() {
        let app = launch(["--busy-home", "--stress-content", "--dark"])
        XCTAssertTrue(app.staticTexts["home-today"].waitForExistence(timeout: 10))
        let events = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-"))
        XCTAssertEqual(events.count, 8, "Show events today and in the next two dates only")
        XCTAssertFalse(app.staticTexts["home-summary"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-todo-")).count, 0)
        let routines = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Completa abitudine "))
        XCTAssertEqual(routines.count, 8)
        for id in [3, 4, 8, 9] {
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-\(id)-")).firstMatch.exists)
        }
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-agenda-5-")).firstMatch
        reveal(first, in: app); XCTAssertTrue(first.isHittable); assertMinimumTouchTarget(first)
        XCTAssertEqual(first.label, "Appuntamento 5")
        capture("home-many-events-agenda")
        first.tap(); XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
    }
    func testKeyboardAndLocalMovementFlow() {
        let app = launch()
        app.openOtherDestination("Finanza")
        let addExpense = app.buttons["primary-add"]
        XCTAssertTrue(addExpense.waitForExistence(timeout: 10)); XCTAssertTrue(addExpense.isHittable); addExpense.tap()
        let description = app.textFields["Descrizione"]
        XCTAssertTrue(description.waitForExistence(timeout: 10))
        XCTAssertEqual(app.steppers.count, 0)
        XCTAssertFalse(app.buttons["Trattamento"].exists)
        description.tap(); description.typeText("Verifica interfaccia")
        capture("movement-keyboard")
        let amount = app.textFields["movement-amount"] // REVIEW-95: the amount is the centred hero field
        amount.tap(); amount.typeText("2")
        app.buttons["Salva"].tap()
        let all = app.buttons["all-movements"]
        for _ in 0..<8 { if all.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        XCTAssertTrue(all.isHittable); all.tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Verifica interfaccia").firstMatch.waitForExistence(timeout: 10))
        capture("movement-saved-locally")
    }
    func testLargeTextAndSixWeekCalendar() {
        let app = launch(["--large-text", "--six-weeks"])
        capture("accessibility-dashboard")
        app.openOtherDestination("Calendario")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let parts = calendar.dateComponents([.year, .month], from: Date())
        let delta = 2026 * 12 + 3 - ((parts.year ?? 2026) * 12 + (parts.month ?? 3))
        let heading = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-month-heading-")).firstMatch
        print("CALENDAR_MONTH_STEP initial=\(heading.label)")
        for index in 0..<abs(delta) {
            app.buttons[delta < 0 ? "Mese precedente" : "Mese successivo"].tap()
            let shifted = calendar.date(byAdding: .month, value: (delta < 0 ? -1 : 1) * (index + 1), to: Date())!
            let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM"
            let expected = "calendar-month-heading-" + formatter.string(from: shifted)
            let headingReached = app.staticTexts[expected].waitForExistence(timeout: 5)
            let firstDay = app.buttons["calendar-day-" + formatter.string(from: shifted) + "-01"]
            let reached = headingReached && firstDay.waitForExistence(timeout: 5) && firstDay.isHittable
            print("CALENDAR_MONTH_STEP index=\(index) expected=\(expected) actual=\(heading.label) state=\(app.scrollViews["calendar-scroll"].value ?? "none")")
            if !reached {
                capture("calendar-large-month-navigation-diagnostic")
                print("CALENDAR_LARGE_DIAGNOSTIC " + app.debugDescription)
            }
            XCTAssertTrue(reached)
        }
        XCTAssertTrue(app.staticTexts["Marzo 2026"].waitForExistence(timeout: 10))
        capture("accessibility-six-weeks")
        app.terminate()
    }
    func testNativeSignInKeyboard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--signin-preview", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let password = app.secureTextFields["Password"]
        XCTAssertTrue(password.waitForExistence(timeout: 30))
        password.tap(); password.typeText("demo-only")
        capture("native-signin-keyboard")
        app.terminate()
    }
    func testBottomAddOpensTheCorrectEditor() {
        let app = launch(["--dark"])
        for (tab, title) in [("Dashboard", "Nuovo movimento"), ("Attività", "Nuova attività"), ("Calendario", "Nuova attività"), ("Finanza", "Nuovo movimento")] {
            if tab == "Calendario" || tab == "Finanza" { app.openOtherDestination(tab) }
            else { app.openMainTab(tab) }
            addButton(app).tap()
            XCTAssertTrue((title == "Finanza" ? app.staticTexts["finance-heading"] : app.navigationBars[title]).waitForExistence(timeout: 10))
            app.buttons["Annulla"].tap()
            XCTAssertTrue(addButton(app).waitForExistence(timeout: 10))
        }
        selectFinanceSection("Extra", in: app)
        let addPlan = app.buttons["plans-add"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(addPlan)
        XCTAssertEqual(addPlan.label, "Nuovo piano")
        addPlan.tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["plan-name"].waitForExistence(timeout: 10))
        capture("budget-add-plan")
        app.buttons["Annulla"].tap()
    }
    func testSharedRowsAndCategoryChoicesKeepAccessibleTargets() {
        let app = launch(["--dark"])
        app.openMainTab("Attività")
        // Categories are one row of chips: one tap selects (22/11/2026).
        let wishes = app.buttons["task-category-wish"], actions = app.buttons["task-category-action"]
        XCTAssertTrue(wishes.waitForExistence(timeout: 10))
        wishes.tap()
        XCTAssertTrue(wishes.isSelected)
        XCTAssertTrue(actions.waitForExistence(timeout: 5)); actions.tap()
        XCTAssertTrue(actions.isSelected); XCTAssertFalse(wishes.isSelected)
        let filter = actions
        assertMinimumTouchTarget(filter)
        let completion = app.buttons["Cambia completamento Organizzare la settimana"]
        XCTAssertTrue(completion.waitForExistence(timeout: 10)); XCTAssertTrue(completion.isHittable)
        assertMinimumTouchTarget(completion)
        app.buttons["task-open-1"].tap()
        XCTAssertTrue(app.textFields["activity-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Modifica attività"].exists)
        app.buttons["Annulla"].tap()
        capture("shared-task-rows")
        completion.tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))
        let archived = app.buttons["toggle-completed-tasks"]
        revealChecklistButton(archived, in: app)
        XCTAssertEqual(archived.value as? String, "Chiusa")
        archived.tap()
        revealChecklistButton(completion, in: app)
        XCTAssertEqual(completion.value as? String, "Completata")
        capture("shared-completed-task-rows")
        completion.tap()
        revealChecklistButton(completion, in: app, towardTop: true)
        XCTAssertEqual(completion.value as? String, "Da completare")
    }
    func testRepeatedBoundaryScrollingKeepsNavigationStable() {
        // All 56 flings remain required. The budget includes XCTest overhead.
        executionTimeAllowance = 300
        let app = launch(["--stress-content", "--dark"])
        for page in ["Dashboard", "Attività", "Calendario", "Finanza"] {
            if page == "Calendario" || page == "Finanza" { app.openOtherDestination(page) }
            else { app.openMainTab(page) }
            let tabs = app.mainTabBar.buttons["Dashboard"], before = app.mainTabBar.buttons["Dashboard"].frame
            let surface = page == "Attività" ? app.collectionViews.firstMatch : app.scrollViews[page == "Dashboard" ? "dashboard-scroll" : page == "Finanza" ? "finance-scroll" : "calendar-scroll"]
            XCTAssertTrue(surface.waitForExistence(timeout: 10))
            for _ in 0..<7 { surface.swipeUp(velocity: .fast) }
            for _ in 0..<7 { surface.swipeDown(velocity: .fast) }
            XCTAssertTrue(tabs.isHittable); XCTAssertTrue(app.mainTabBar.buttons["Bloom"].isHittable)
            XCTAssertEqual(before.height, tabs.frame.height, accuracy: 2)
            capture("boundary-" + page)
        }
    }

    func testCalendarEventCanBeCreatedAfterBoundaryScroll() throws {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let selectedDay = Self.today()
        // Establish a known selected day; scrolling the month does not change it.
        app.buttons["calendar-today"].tap()
        revealCalendarDay(selectedDay, in: app)
        XCTAssertTrue(app.buttons["calendar-day-" + selectedDay].isSelected)
        for _ in 0..<4 { scroll.swipeUp(velocity: .fast) }
        addButton(app).tap()
        let title = app.textFields["activity-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let inputFormat = DateFormatter(); inputFormat.locale = Locale(identifier: "en_US_POSIX")
        inputFormat.timeZone = TimeZone(identifier: "Europe/Rome"); inputFormat.dateFormat = "yyyy-MM-dd"
        let displayFormat = DateFormatter(); displayFormat.locale = Locale(identifier: "it_IT")
        displayFormat.timeZone = inputFormat.timeZone; displayFormat.dateStyle = .medium; displayFormat.timeStyle = .none
        let expectedDate = displayFormat.string(from: try XCTUnwrap(inputFormat.date(from: selectedDay)))
        let editorDate = app.buttons["activity-date-Inizio"]
        XCTAssertTrue(editorDate.waitForExistence(timeout: 10))
        let initialDate = editorDate.label
        print("CALENDAR_DATE_DIAGNOSTIC runnerTimeZone=\(TimeZone.current.identifier) offset=\(TimeZone.current.secondsFromGMT()) selectedCivilDay=\(selectedDay) expected=\(expectedDate) initialEditor=\(initialDate) match=\(initialDate == expectedDate)")
        capture("calendar-date-before-save")
        title.tap(); title.typeText("Evento dopo scorrimento")
        app.buttons["Salva"].tap()
        app.buttons["calendar-today"].tap()
        revealCalendarDay(selectedDay, in: app)
        app.buttons["calendar-day-" + selectedDay].tap()
        // Build 95 day list: the all-day event is a row of the selected day.
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "calendar-timeline-event:", "Evento dopo scorrimento")).firstMatch
        let found = event.waitForExistence(timeout: 10)
        print("CALENDAR_DATE_DIAGNOSTIC selectedCivilDay=\(selectedDay) eventExists=\(found)")
        if !found { capture("calendar-date-event-not-found") }
        XCTAssertTrue(found)
        XCTAssertTrue(event.isHittable); assertMinimumTouchTarget(event)
        capture("calendar-event-after-scroll")
        event.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "Evento dopo scorrimento")
        XCTAssertTrue(editorDate.waitForExistence(timeout: 10))
        let reopenedDate = editorDate.label
        print("CALENDAR_DATE_DIAGNOSTIC selectedCivilDay=\(selectedDay) expected=\(expectedDate) initialEditor=\(initialDate) reopenedEditor=\(reopenedDate) initialMatch=\(initialDate == expectedDate) reopenedMatch=\(reopenedDate == expectedDate)")
        capture("calendar-date-reopened")
        XCTAssertEqual(initialDate, expectedDate, "The editor must display the selected civil day before saving")
        XCTAssertEqual(reopenedDate, expectedDate, "The reopened event must display the saved civil day")
        app.buttons["Annulla"].tap()
    }
    func testCalendarSelectionUpdatesImmediatelyAndKeepsEventIndex() {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        let cells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-day-"))
        XCTAssertGreaterThanOrEqual(cells.count, 28)
        // Resolve each date by identity: lazy months can enter/leave the accessibility tree.
        app.buttons["calendar-today"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: Date())
        for index in [9, 10, 11, 10] {
            let day = month + String(format: "-%02d", index + 1)
            let cell = app.buttons["calendar-day-" + day]
            revealCalendarDay(day, in: app)
            cell.tap()
            XCTAssertTrue(app.scrollViews["calendar-day-pane"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["calendar-day-heading"].isHittable)
            app.buttons["calendar-back-month"].tap()
            XCTAssertTrue(cell.waitForExistence(timeout: 10))
            XCTAssertTrue(cell.isSelected)
        }
        capture("calendar-repeated-selection")
    }
    func testLongTaskOpensAfterScrollingWithoutTriggeringCompletion() {
        let app = launch(["--stress-content"])
        app.buttons["Attività"].tap()
        let title = "Attività lunga di verifica 1: pianificare e organizzare gli impegni della settimana"
        let open = app.buttons["task-open-1"]
        revealChecklistButton(open, in: app); open.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["activity-title"].value as? String, title)
        capture("long-task-editor")
        app.buttons["Annulla"].tap()
        XCTAssertEqual(app.buttons["Cambia completamento " + title].value as? String, "Da completare")
    }

    func testNegativeBudgetAndGroupedAmounts() {
        let app = launch(["--stress-money", "--dark"])
        app.openOtherDestination("Finanza")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1.234,56")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["finance-current-balance"].label.contains("12.345,67"))
        capture("negative-budget-and-grouped-amounts")
    }
    func testFinanceMonthButtonsMoveIndependentlyInBothDirections() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza")
        selectFinanceSection("Extra", in: app)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "it_IT"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "MMMM yyyy"
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = formatter.timeZone
        let current = formatter.string(from: Date()).capitalized
        let previous = formatter.string(from: calendar.date(byAdding: .month, value: -1, to: Date())!).capitalized
        // Build 95: the month is a chip in the title row; its menu moves back and forward.
        let month = app.buttons["finance-month"]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        month.tap(); app.buttons["Mese precedente"].tap()
        XCTAssertTrue(month.label.contains(previous) || app.staticTexts[previous].waitForExistence(timeout: 10), month.label)
        month.tap(); app.buttons["Mese successivo"].tap()
        XCTAssertTrue(month.label.contains(current) || app.staticTexts[current].waitForExistence(timeout: 10), month.label)
        capture("extra-month-navigation")
    }
    func testVisibleShiftBrushPaintsAndUndoRestoresDay() {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        app.buttons["toggle-shift-paint"].tap()
        let brush = app.buttons["shift-brush-afternoon"]
        XCTAssertTrue(brush.waitForExistence(timeout: 10)); brush.tap()
        expectation(for: NSPredicate { element, _ in (element as? XCUIElement)?.isSelected == true }, evaluatedWith: brush)
        waitForExpectations(timeout: 10)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["calendar-day-" + formatter.string(from: Date())]
        capture("calendar-palette-before-paint")
        revealCalendarDay(formatter.string(from: Date()), in: app)
        day.tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Pomeriggio"), evaluatedWith: day)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(day.label.contains("Pomeriggio"))
        capture("calendar-paint-palette")
        app.buttons["Annulla"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Mattina"), evaluatedWith: day)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(day.label.contains("Mattina"))
        app.buttons["toggle-shift-paint"].tap()
    }
    func testSavingsBreakdownAndDirectTaskReorder() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza")
        openBudget(app)
        let assets = app.descendants(matching: .any)["finance-total-assets"]
        for _ in 0..<5 { if assets.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(assets.exists)
        capture("savings-breakdown")
        app.buttons["Attività"].tap()
        XCTAssertTrue(app.buttons["task-category-all"].exists)
        app.buttons["reorder-tasks"].tap()
        capture("task-categories-and-reorder")
        app.buttons["reorder-tasks"].tap()
    }
    func testExtraActualPaymentUsesSavingsAndKeepsMonthlyBudget() {
        let app = launch(["--stress-money", "--dark"])
        app.openOtherDestination("Finanza")
        selectFinanceSection("Extra", in: app)
        let legacyPlan = app.staticTexts["Manutenzione auto"]
        for _ in 0..<12 { if legacyPlan.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(legacyPlan.isHittable, "Il piano storico deve restare raggiungibile nel Budget")
        legacyPlan.tap()
        XCTAssertTrue(app.navigationBars["Spesa extra"].waitForExistence(timeout: 10))
        let payment = app.textFields["Importo pagato €"]
        for _ in 0..<6 { if payment.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(payment.isHittable)
        payment.tap()
        let old = payment.value as? String ?? ""
        payment.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "550,01")
        let done = app.buttons["extra-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10)); done.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let pay = app.buttons["extra-pay-savings"]
        for _ in 0..<6 { if pay.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(pay.isHittable)
        capture("extra-before-actual-payment")
        pay.tap()
        XCTAssertTrue(app.staticTexts["Pagata"].waitForExistence(timeout: 10))
        capture("extra-closed-with-actual-payment")
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        selectFinanceSection("Panoramica", in: app)
        XCTAssertTrue(app.staticTexts["finance-current-balance"].label.contains("11.795,66"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1.234,56")).firstMatch.exists)
    }
    func testPlansInfoAndMonthOnlyAdvanceFlow() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza")
        app.buttons["finance-budget"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Stipendio"].exists) // Build 93 Budget summary
        XCTAssertFalse(app.staticTexts["Ricorrenti"].exists)
        capture("budget-unified-salary-and-plans")
        app.buttons["plans-info"].tap()
        XCTAssertTrue(app.navigationBars["Come funzionano i piani"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["La regola di base"].exists)
        capture("plans-info")
        app.navigationBars.buttons["Fine"].tap()
        app.buttons["plans-add"].tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10))
        app.buttons["plan-kind-advance"].tap()
        let name = app.textFields["plan-name"]
        // The kind change re-lays out the form: wait for the field, then tap until it has the keyboard.
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        for _ in 0..<3 where (name.value(forKey: "hasKeyboardFocus") as? Bool) != true { name.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        name.typeText("Anticipo prova")
        let amount = app.textFields["plan-amount"]; amount.tap(); amount.typeText("250")
        app.buttons["Fine"].tap()
        XCTAssertEqual(app.datePickers.count, 0, "Budget periods must never expose a day picker")
        capture("plans-advance-preview")
        app.buttons["plan-save"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        app.staticTexts["Anticipo prova"].tap()
        XCTAssertTrue(app.navigationBars["Dettagli piano"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["plan-record-payment"].exists)
        capture("plans-advance-detail")
    }
    /// FINANCE-ENTRY-SIMPLIFY-2026-11-24 (replaces the goal payment test): only Anticipo, Fondo and Ricorrente.
    func testNewPlanOffersThreeKindsAndRecurringHasFixedOrEstimated() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza"); app.buttons["finance-budget"].tap()
        app.buttons["plans-add"].tap()
        XCTAssertTrue(app.buttons["plan-kind-fund"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["plan-kind-advance"].exists); XCTAssertTrue(app.buttons["plan-kind-fixed"].exists)
        XCTAssertFalse(app.buttons["plan-kind-goal"].exists); XCTAssertFalse(app.buttons["plan-kind-recovery"].exists)
        XCTAssertFalse(app.buttons["plan-kind-estimated"].exists, "fixed and estimated are one kind, «Ricorrente»")
        app.buttons["plan-kind-fixed"].tap()
        let amount = app.segmentedControls["plan-recurring-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.buttons["Stimato"].tap()
        XCTAssertTrue(app.buttons["plan-kind-fixed"].isSelected, "«Ricorrente» stays selected for an estimated amount")
        capture("plans-three-kinds")
    }
    func testPlansFundCanEditFutureQuotaAndLinkAnExistingMovement() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza"); app.buttons["finance-budget"].tap(); app.buttons["plans-add"].tap()
        app.buttons["plan-kind-fund"].tap()
        let name = app.textFields["plan-name"]; name.tap(); name.typeText("Fondo prova")
        let amount = app.textFields["plan-amount"]; amount.tap(); amount.typeText("50")
        app.buttons["Fine"].tap(); app.buttons["plan-save"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10)); app.staticTexts["Fondo prova"].tap()
        let edit = app.buttons["plan-edit"]; reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.navigationBars["Modifica piano"].waitForExistence(timeout: 10))
        let quota = app.textFields["plan-edit-amount"]; quota.tap()
        quota.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (quota.value as? String ?? "").count) + "80")
        app.buttons["Fine"].tap(); app.buttons["plan-edit-save"].tap()
        XCTAssertTrue(app.navigationBars["Dettagli piano"].waitForExistence(timeout: 10))
        // FINANCE-ENTRY-SIMPLIFY: «Paga con Nuova spesa» opens Nuova spesa with the plan; «Già registrata?» links a movement.
        let pay = app.buttons["plan-record-payment"]; reveal(pay, in: app); pay.tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
        let existing = app.buttons["expense-plan-existing"]
        for _ in 0..<6 { if existing.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(existing.isHittable); existing.tap()
        XCTAssertTrue(app.navigationBars["Spesa già registrata"].waitForExistence(timeout: 10))
        let movement = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan-link-movement-")).firstMatch
        XCTAssertTrue(movement.waitForExistence(timeout: 10)); reveal(movement, in: app)
        assertMinimumTouchTarget(movement)
        movement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirm = app.buttons["plan-payment-confirm"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: confirm)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.textFields["plan-payment-amount"].value as? String == "12.34")
        capture("plans-link-existing-movement")
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Dettagli piano"].waitForExistence(timeout: 10))
        let posted = app.staticTexts["plan-payment-status"].firstMatch
        for _ in 0..<6 { if posted.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(posted.waitForExistence(timeout: 10))
        XCTAssertTrue(posted.label.contains("Pagato · movimento collegato"))
        capture("plans-fund-payment-linked")
        let active = app.staticTexts["plan-status"]
        for _ in 0..<6 { if active.isHittable { break }; app.collectionViews.firstMatch.swipeDown() }
        XCTAssertTrue(active.label.hasSuffix("In corso"))
        let stop = app.buttons["Interrompi le quote future"]
        reveal(stop, in: app); stop.tap(); app.buttons["Conferma"].tap()
        expectation(for: NSPredicate(format: "label ENDSWITH %@", "Interrotto"), evaluatedWith: app.staticTexts["plan-status"])
        waitForExpectations(timeout: 10)
        let payment = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan-payment-detail-")).firstMatch
        reveal(payment, in: app); XCTAssertTrue(payment.waitForExistence(timeout: 10)); payment.tap()
        XCTAssertTrue(app.navigationBars["Pagamento del piano"].waitForExistence(timeout: 10))
        app.buttons["plan-payment-delete"].tap(); app.buttons["Elimina pagamento"].tap()
        XCTAssertTrue(app.navigationBars["Dettagli piano"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["plan-status"].label.hasSuffix("Interrotto"))
        XCTAssertTrue(app.staticTexts["Nessun pagamento registrato"].exists)
        capture("plans-stopped-payment-deleted")
    }
    func testAnalysisShowsFourChartsAndCategoryPeriods() {
        let app = launch(["--stress-money", "--dark"])
        app.openOtherDestination("Finanza")
        app.buttons["finance-analysis"].tap()
        XCTAssertTrue(app.staticTexts["finance-analysis-heading"].waitForExistence(timeout: 10))
        // Build 93 Analisi: cards in the preview order, category periods as a segmented control.
        XCTAssertTrue(app.staticTexts["Ritmo"].waitForExistence(timeout: 10))
        for period in ["3", "6", "12"] {
            let option = app.buttons["category-period-" + period]
            for _ in 0..<6 { if option.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
            option.tap()
            XCTAssertTrue(option.isSelected)
            XCTAssertTrue(app.descendants(matching: .any)["finance-category-average"].waitForExistence(timeout: 10) || app.staticTexts["Nessuna spesa nel periodo"].exists)
            capture("category-period-" + period)
        }
        for title in ["Entrate e uscite", "Stipendi per competenza", "Giorno per giorno", "Patrimonio"] {
            let heading = app.staticTexts[title]
            for _ in 0..<10 { if heading.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(heading.exists, title)
        }
        capture("analysis-four-charts")
    }
    func testGoalsAreIndependentlyEditableAndReloadAfterSave() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza")
        openBudget(app)
        let edit = app.buttons["Obiettivo e fondo emergenza"]
        for _ in 0..<4 { if edit.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(edit.isHittable); edit.tap()
        XCTAssertTrue(app.navigationBars["Obiettivo e fondo"].waitForExistence(timeout: 10))
        for (id, value) in [("emergency-input", "6000,00"), ("savings-target-input", "15000,00")] {
            let field = app.textFields[id]; XCTAssertTrue(field.exists); field.tap()
            let old = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
        }
        app.navigationBars.buttons["Salva"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertEqual(app.textFields["emergency-input"].value as? String, "6000,00")
        XCTAssertEqual(app.textFields["savings-target-input"].value as? String, "15000,00")
        capture("independent-goals-saved")
    }
    func testFinanceHasOpenOverviewAndDirectMovements() {
        let app = launch(["--dark"])
        app.openOtherDestination("Finanza")
        XCTAssertTrue(app.staticTexts["finance-heading"].exists)
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        XCTAssertFalse(app.otherElements["wealth-forecast-chart"].exists)
        let budget = app.buttons["finance-budget"], analysis = app.buttons["finance-analysis"], more = app.buttons["finance-new-plan"]
        revealFinanceControl(budget, in: app)
        for action in [budget, analysis, more] { assertMinimumTouchTarget(action) }
        // One compact row (build 92): adjacent shortcuts may share an edge.
        XCTAssertGreaterThanOrEqual(analysis.frame.minX, budget.frame.maxX - 1)
        XCTAssertFalse(app.buttons["finance-more"].exists, "No hidden overflow menu")
        more.tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10)); app.buttons["Annulla"].tap()
        app.buttons["primary-add"].tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10)); app.buttons["Annulla"].tap()
        let all = app.buttons["all-movements"]
        revealFinanceControl(all, in: app); all.tap()
        XCTAssertTrue(app.navigationBars["Movimenti"].waitForExistence(timeout: 10))
        capture("all-movements-direct")
    }
    func testHomeRestoresNeutralNextTimeWithoutArabicNames() {
        let app = launch(["--dark"])
        let next = app.buttons["home-next-time"]
        reveal(next, in: app)
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(next.label.hasPrefix("Prossimo orario"))
        XCTAssertFalse(next.label.localizedCaseInsensitiveContains("preghier"))
        next.tap()
        XCTAssertTrue(app.navigationBars["Orari"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Alba"].exists)
        XCTAssertTrue(app.staticTexts["Pomeriggio"].exists)
        capture("home-neutral-next-time")
    }
    func testNativeAddKeepsDestinationSelectedAfterRepeatedPresentation() {
        let app = launch(["--dark"])
        for _ in 0..<3 {
            app.openOtherDestination("Calendario")
            addButton(app).tap()
            XCTAssertTrue(app.navigationBars["Nuova attività"].waitForExistence(timeout: 10))
            app.buttons["Annulla"].tap()
            XCTAssertTrue(app.scrollViews["calendar-scroll"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.mainTabBar.buttons["Dashboard"].isSelected)
        }
    }
    private func revealFinanceControl(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["finance-scroll"]
        for _ in 0..<18 {
            let visible = scroll.frame.intersection(app.frame)
            let top = max(visible.minY, app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : visible.minY)
            // Finance pins Add expense above the tab bar; content behind it is not reachable.
            let pinned = app.buttons["primary-add"]
            let pinnedTop = pinned.exists && pinned.frame.minY > visible.midY && pinned.frame != element.frame ? pinned.frame.minY : visible.maxY
            let bottom = min(visible.maxY, app.mainTabBar.frame.minY, pinnedTop)
            guard bottom > top else { return }
            // isHittable alone accepted «Movimenti» under the pinned Add expense bar with
            // accessibility text; the tap then opened Nuovo movimento (run 44024746135).
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            // Short drags avoid flicking past a control on a short screen.
            // Reverse direction if it has already moved above the viewport.
            let target = element.exists ? element.frame : CGRect.null
            let hasFrame = !target.isNull && !target.isEmpty
            let above = hasFrame && target.minY < top
            if hasFrame && target.minY >= top && target.maxY <= bottom {
                return // A visible but untappable control must still fail the assertion.
            }
            let startY = top + (bottom - top) * (above ? 0.35 : 0.65)
            let endY = top + (bottom - top) * (above ? 0.65 : 0.35)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: visible.midX - app.frame.minX, dy: startY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: visible.midX - app.frame.minX, dy: endY - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }
    func testFinanceOverviewSupportsLargeTextAndEmptySnapshot() {
        for args in [["--dark", "--large-text", "--stress-money"], ["--dark", "--empty-home"]] {
            let app = launch(args)
            app.openOtherDestination("Finanza")
            let expense = app.buttons["primary-add"]
            revealFinanceControl(expense, in: app)
            XCTAssertTrue(expense.isHittable, "Spesa irraggiungibile: args \(args), frame \(expense.frame), scroll \(app.scrollViews["finance-scroll"].frame)"); assertMinimumTouchTarget(expense)
            expense.tap()
            XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
            app.buttons["Annulla"].tap()
            let all = app.buttons["all-movements"]
            revealFinanceControl(all, in: app)
            XCTAssertTrue(all.isHittable, "Movimenti irraggiungibili: args \(args), frame \(all.frame)"); all.tap()
            XCTAssertTrue(app.navigationBars["Movimenti"].waitForExistence(timeout: 10))
            capture(args.contains("--large-text") ? "finance-large-text" : "finance-empty-snapshot")
            app.terminate()
        }
    }

    func testReducedMotionKeepsChecklistAndFinanceActionsFunctional() {
        let app = launch(["--dark", "--reduce-motion"])
        app.openMainTab("Attività")
        // Categories are one row of chips: one tap selects (22/11/2026).
        let wishes = app.buttons["task-category-wish"], actions = app.buttons["task-category-action"]
        XCTAssertTrue(wishes.waitForExistence(timeout: 10))
        wishes.tap()
        XCTAssertTrue(wishes.isSelected)
        XCTAssertTrue(actions.waitForExistence(timeout: 5)); actions.tap()
        XCTAssertTrue(actions.isSelected); XCTAssertFalse(wishes.isSelected)
        let completion = app.buttons["Cambia completamento Organizzare la settimana"]
        XCTAssertTrue(completion.waitForExistence(timeout: 10))
        completion.tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))
        let archived = app.buttons["toggle-completed-tasks"]
        revealChecklistButton(archived, in: app)
        XCTAssertEqual(archived.value as? String, "Chiusa")
        archived.tap()
        revealChecklistButton(completion, in: app)
        XCTAssertEqual(completion.value as? String, "Completata")
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        completion.tap(); revealChecklistButton(completion, in: app, towardTop: true); XCTAssertEqual(completion.value as? String, "Da completare")
        app.openOtherDestination("Finanza")
        let expense = app.buttons["primary-add"]
        for _ in 0..<5 { if expense.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        expense.tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.mainTabBar.buttons["Dashboard"].isSelected)
        capture("reduced-motion-finance")
    }

    func testCalendarTodayRestoresMonthAndSelection() {
        let app = launch(["--dark"])
        app.openOtherDestination("Calendario")
        app.buttons["Mese precedente"].tap()
        let today = app.buttons["calendar-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 10)); assertMinimumTouchTarget(today); today.tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let current = app.buttons["calendar-day-" + formatter.string(from: Date())]
        XCTAssertTrue(current.waitForExistence(timeout: 10))
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { element, _ in (element as? XCUIElement)?.isSelected == true }, object: current)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        assertMinimumTouchTarget(current)
        XCTAssertTrue(app.buttons["toggle-shift-paint"].isHittable)
        capture("calendar-compact-apple-dark")
    }

}
