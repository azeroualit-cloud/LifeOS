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
            XCTAssertTrue(app.navigationBars["Finanza"].waitForExistence(timeout: 10))
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
        let lower = app.tabBars.firstMatch.frame.minY
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
    func testActivityAgendaShowsOnlyRelevantItemsAndFoldsCompleted() {
        let app = launch(["--dark", "--activity-agenda"])
        app.tabBars.buttons["Attività"].tap()
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
        let completion = app.buttons["Cambia completamento Attività archiviata"]
        revealChecklistButton(completion, in: app)
        XCTAssertEqual(completion.value as? String, "Completata")
        capture("agenda-completed-expanded")
        completion.tap()
        XCTAssertTrue(app.buttons["toggle-completed-tasks"].waitForNonExistence(timeout: 10))
        revealChecklistButton(completion, in: app, towardTop: true)
        XCTAssertEqual(completion.value as? String, "Da completare")
    }
    func testEventContextActionsUseFullSizeChipsAndOwnEditor() {
        let app = launch(["--dark", "--activity-agenda"])
        app.tabBars.buttons["Attività"].tap()
        app.staticTexts["Evento oggi"].tap()
        let details = app.buttons["inline-event-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 10)); assertMinimumTouchTarget(details)
        XCTAssertFalse(app.navigationBars["Modifica evento"].exists)
        let time = app.buttons["inline-event-time"]
        assertMinimumTouchTarget(time)
        capture("event-context-action-chips")
        time.tap()
        XCTAssertTrue(app.navigationBars["Modifica evento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["Ora iniziale"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["Ora iniziale"].value as? String, "1")
        app.buttons["Annulla"].tap()
        let task = app.buttons["Cambia completamento Da fare libera"]
        revealChecklistButton(task, in: app)
        app.buttons["Da fare libera"].tap()
        let reminder = app.buttons["inline-task-reminder"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10)); assertMinimumTouchTarget(reminder)
        capture("task-context-action-chips")
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["Orario promemoria"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["Orario promemoria"].value as? String, "1")
        XCTAssertFalse(app.navigationBars["Impostazioni"].exists)
    }
    func testCalendarRepeatedScrollingKeepsMonthAnchorsAndReturnsToToday() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Calendario"].tap()
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<8 { scroll.swipeUp(velocity: .fast) }
        for _ in 0..<8 { scroll.swipeDown(velocity: .fast) }
        app.buttons["calendar-today"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date()), cell = app.buttons["calendar-day-" + day]
        XCTAssertTrue(cell.waitForExistence(timeout: 10)); XCTAssertTrue(cell.isSelected)
        XCTAssertEqual(app.buttons.matching(identifier: "calendar-day-" + day).count,1)
        capture("calendar-after-repeated-scroll-and-today")
    }
    func testEditingKeepsTaskTitleGeometryAndDraftAcrossTabs() {
        let app = launch(["--dark", "--activity-agenda"])
        app.tabBars.buttons["Attività"].tap()
        let open = app.buttons["task-open-101"]
        revealChecklistButton(open, in: app)
        let before = open.frame
        capture("task-title-before-edit")
        open.tap()
        let title = app.descendants(matching: .any)["inline-task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "Da fare libera")
        XCTAssertEqual(title.frame.minX,before.minX,accuracy:2)
        XCTAssertEqual(title.frame.width,before.width,accuracy:2)
        XCTAssertEqual(title.frame.height,before.height,accuracy:2)
        capture("task-title-during-edit")
        title.tap(); title.typeText(" prova")
        let edited = title.value as? String
        XCTAssertTrue(edited?.contains("prova") == true)
        app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        for target in ["Calendario","Finanza","Dashboard","Attività"] {
            let tab = app.tabBars.buttons[target]
            XCTAssertTrue(tab.waitForExistence(timeout:10)); tab.tap(); XCTAssertTrue(tab.isSelected)
        }
        XCTAssertTrue(title.waitForExistence(timeout:10))
        XCTAssertEqual(title.value as? String,edited)
        let close = app.buttons["inline-task-close"]
        revealChecklistButton(close,in:app)
        close.tap()
        XCTAssertTrue(app.buttons["Salva e chiudi"].waitForExistence(timeout:10))
        app.buttons["Salva e chiudi"].tap()
        XCTAssertTrue(open.waitForExistence(timeout:10))
        XCTAssertEqual(open.label,edited)
        open.tap()
        XCTAssertEqual(title.value as? String,edited)
        capture("task-title-saved-after-tab-switches")
    }
    func testRepeatedTabSwitchesKeepNativeDestinationsUsable() {
        let app = launch(["--dark"])
        for _ in 0..<3 {
            for name in ["Attività","Calendario","Finanza","Dashboard"] {
                let tab = app.tabBars.buttons[name]
                tab.tap(); XCTAssertTrue(tab.isSelected)
                XCTAssertTrue(app.navigationBars[name].exists)
                XCTAssertTrue(addButton(app).isHittable)
            }
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
        XCTAssertFalse(app.buttons["home-routine-999"].exists)
        app.buttons["home-manage-routines"].tap()
        let habit = app.buttons["routine-edit-999"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<8 { if habit.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
    }
    func testCalendarDayCanBeDeselectedWithASecondTap() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Calendario"].tap()
        app.buttons["calendar-today"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["calendar-day-" + formatter.string(from: Date())]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        XCTAssertTrue(day.isSelected)
        day.tap()
        XCTAssertFalse(day.isSelected)
        capture("calendar-neutral-deselected")
        day.tap()
        XCTAssertTrue(day.isSelected)
    }
    func testCalendarScrollPerformance() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Calendario"].tap()
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
        app.buttons["home-manage-routines"].tap()
        XCTAssertTrue(app.navigationBars["Abitudini"].waitForExistence(timeout: 10))
        let name = app.textFields["routine-name"]; show(name); name.tap(); name.typeText("Allenamento programmato")
        let repeatPicker = app.buttons["routine-repeat"]; show(repeatPicker); repeatPicker.tap(); app.buttons["Ogni N giorni"].tap()
        let save = app.buttons["routine-save"]; show(save); save.tap()
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "routine-edit-", "Allenamento programmato")).firstMatch
        show(edit, towardTop: true); XCTAssertTrue(edit.waitForExistence(timeout: 10)); XCTAssertTrue(edit.label.contains("Ogni 2 giorni")); edit.tap()
        show(repeatPicker); repeatPicker.tap(); app.buttons["Giorni della settimana"].tap()
        let monday = app.switches["routine-weekday-1"]; show(monday); XCTAssertTrue(monday.waitForExistence(timeout: 10))
        print("HABIT_SWITCH_BEFORE: " + monday.debugDescription)
        XCTAssertEqual(monday.value as? String, "0")
        // SwiftUI can expose the full labelled row as a switch. Tap the control end.
        monday.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        print("HABIT_SWITCH_AFTER: " + monday.debugDescription)
        XCTAssertEqual(monday.value as? String, "1", monday.debugDescription)
        capture("habit-weekday-selected")
        show(save); XCTAssertTrue(save.isEnabled, "Save disabled after weekday selection"); save.tap()
        show(edit, towardTop: true)
        print("HABIT_SAVED_ROW: " + edit.debugDescription)
        XCTAssertTrue(edit.label.contains("Lunedì"), "Saved habit label: " + edit.label)
        edit.tap(); show(monday); XCTAssertEqual(monday.value as? String, "1")
        capture("habits-weekday-schedule")
    }
    func testHomeHealthCardRemainsCompactAndOpensDetail() {
        let app = launch(["--dark"]), detail = app.buttons["home-health-detail"]
        let scroll = app.scrollViews["dashboard-scroll"]
        for _ in 0..<6 { if detail.exists && detail.frame.maxY < app.tabBars.firstMatch.frame.minY { break }; scroll.swipeUp() }
        XCTAssertTrue(detail.exists); XCTAssertLessThanOrEqual(detail.frame.height, 300)
        XCTAssertLessThan(detail.frame.maxY, app.tabBars.firstMatch.frame.minY)
        capture("compact-home-health-card")
        detail.tap(); XCTAssertTrue(app.navigationBars["Peso e calorie"].waitForExistence(timeout: 10))
    }
    func testFourSectionsInBothThemes() {
        for dark in [false, true] {
            let app = launch(dark ? ["--dark"] : [])
            for tab in ["Dashboard", "Attività", "Calendario", "Finanza"] {
                app.buttons[tab].tap()
                XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 10))
                let add = addButton(app)
                XCTAssertTrue(add.isHittable)
                assertMinimumTouchTarget(add)
                add.tap()
                let editor = tab == "Attività" ? "Nuova attività" : tab == "Calendario" ? "Nuovo evento" : "Nuovo movimento"
                XCTAssertTrue(app.navigationBars[editor].waitForExistence(timeout: 10))
                app.buttons["Annulla"].tap()
                XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 10))
                XCTAssertTrue(app.navigationBars.buttons["primary-add"].exists)
                XCTAssertTrue(app.tabBars.firstMatch.exists)
                if tab == "Finanza" { XCTAssertTrue(app.staticTexts["finance-budget-value"].exists) }
                capture((dark ? "dark-" : "light-") + tab)
            }
            app.terminate()
        }
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
                    XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
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
        let initial = app.tabBars.buttons["Dashboard"].frame
        for (key, title) in [("finance", "Finanza"), ("tasks", "Attività"), ("calendar", "Calendario"), ("dashboard", "Dashboard"), ("calendar", "Calendario"), ("tasks", "Attività"), ("dashboard", "Dashboard")] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.isHittable); assertMinimumTouchTarget(tab); tab.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
            XCTAssertTrue(tab.isSelected)
            for other in ["dashboard", "tasks", "calendar", "finance"] where other != key {
                XCTAssertFalse(app.tabBars.buttons[["dashboard": "Dashboard", "tasks": "Attività", "calendar": "Calendario", "finance": "Finanza"][other]!].isSelected)
            }
            let frame = app.tabBars.buttons["Dashboard"].frame
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
    func testHomeSummaryAndVerticalRoutinesInBothThemes() {
        for dark in [false, true] {
            let app = launch(dark ? ["--dark"] : [])
            let summary = app.staticTexts["home-summary"]
            XCTAssertTrue(summary.waitForExistence(timeout: 10))
            XCTAssertTrue(summary.label.contains("Allenamento"))
            XCTAssertFalse(summary.label.contains("dalle"))
            XCTAssertFalse(app.otherElements["today-condition"].exists)
            let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-"))
            XCTAssertEqual(days.count, 7)
            XCTAssertTrue(days.element(boundBy: 3).isSelected)
            XCTAssertEqual(days.element(boundBy: 3).frame.midX, app.frame.midX, accuracy: 1)
            capture(dark ? "home-editorial-dark" : "home-editorial-light")
            let routine = app.buttons["home-routine-1"]
            reveal(routine, in: app)
            XCTAssertTrue(routine.isHittable)
            assertMinimumTouchTarget(routine)
            let before = routine.value as? String
            routine.tap()
            let changed = NSPredicate(format: "value != %@", before ?? "")
            expectation(for: changed, evaluatedWith: routine)
            waitForExpectations(timeout: 10)
            let detail = app.buttons["home-health-detail"]
            reveal(detail, in: app)
            XCTAssertTrue(detail.waitForExistence(timeout: 10), "Health detail missing. Demo label: \(app.staticTexts["Dati illustrativi · nessun accesso a Salute"].exists). Buttons: \(app.buttons.allElementsBoundByIndex.map { $0.identifier + ":" + $0.label }.suffix(12))")
            reveal(detail, in: app); XCTAssertTrue(detail.isHittable)
            XCTAssertFalse(app.staticTexts["home-todos-heading"].exists)
            XCTAssertFalse(app.buttons["home-budget"].exists)
            XCTAssertGreaterThan(detail.frame.midY, routine.frame.midY)
            XCTAssertFalse(app.buttons["health-connect"].exists)
            XCTAssertTrue(detail.label.contains("peso e calorie dell’ultimo mese"))
            XCTAssertTrue(detail.label.contains("previsione del peso del prossimo mese"))
            XCTAssertTrue(detail.label.contains("TDEE medio storico stimato"))
            XCTAssertTrue(app.buttons["home-health-add-weight"].exists)
            capture(dark ? "home-health-dark" : "home-health-light")
            detail.tap()
            XCTAssertTrue(app.navigationBars["Peso e calorie"].waitForExistence(timeout: 10))
            let intake = app.textFields["health-intake"]
            reveal(intake, in: app)
            XCTAssertTrue(intake.isHittable)
            app.terminate()
        }
    }
    func testHomeEmptyStatesRemainActionable() {
        let app = launch(["--empty-home", "--dark"])
        let summary = app.staticTexts["home-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("Nessun appuntamento"))
        XCTAssertTrue(summary.label.contains("Turni non disponibili"))
        XCTAssertFalse(app.buttons["home-events"].exists)
        let routines = app.buttons["home-empty-routines"]
        reveal(routines, in: app); XCTAssertTrue(routines.isHittable)
        XCTAssertFalse(app.buttons["home-empty-todos"].exists)
        XCTAssertFalse(app.buttons["home-budget"].exists)
        let health = app.buttons["home-health-detail"]
        reveal(health, in: app)
        XCTAssertTrue(health.isHittable)
        XCTAssertFalse(app.buttons["health-connect"].exists)
        health.tap()
        XCTAssertTrue(app.staticTexts["Dati insufficienti"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Attività"].tap()
        XCTAssertTrue(app.navigationBars["Attività"].waitForExistence(timeout: 10))
        app.buttons["Dashboard"].tap()
        capture("home-empty")
    }
    func testQuickWeightEntryFromDashboard() {
        let app = launch(["--dark"])
        let add = app.buttons["home-health-add-weight"]
        reveal(add, in: app)
        XCTAssertTrue(add.isHittable)
        assertMinimumTouchTarget(add)
        add.tap()
        XCTAssertTrue(app.navigationBars["Aggiungi peso"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Peso e calorie"].exists)
        let save = app.buttons["health-save-weight"]
        XCTAssertFalse(save.isEnabled)
        let field = app.textFields["health-new-weight"]
        field.tap()
        field.typeText("83,4")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        let detail = app.buttons["home-health-detail"]
        XCTAssertTrue(detail.label.contains("83,4"))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        add.tap()
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(detail.label.contains("83,4"))
    }

    func testHealthChartTransitionAndFinanceMonthRoundTrip() {
        let app = launch(["--dark"])
        let detail = app.buttons["home-health-detail"]
        reveal(detail, in: app)
        XCTAssertTrue(detail.label.contains("kcal a sinistra, kg a destra"))
        capture("home-health-continuous-forecast")
        app.tabBars.buttons["Finanza"].tap()
        let month = app.staticTexts["finance-month"]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        let current = month.label
        for _ in 0..<3 { app.buttons["Mese successivo"].tap() }
        XCTAssertNotEqual(month.label, current)
        for _ in 0..<3 { app.buttons["Mese precedente"].tap() }
        XCTAssertEqual(month.label, current)
        capture("finance-returned-to-current-month")
    }
    func testHealthScenarioCanBeEditedWithoutAddingNavigationTab() {
        let app = launch(["--dark"])
        let detail = app.buttons["home-health-detail"]
        reveal(detail, in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Health detail missing. Demo label: \(app.staticTexts["Dati illustrativi · nessun accesso a Salute"].exists). Buttons: \(app.buttons.allElementsBoundByIndex.map { $0.identifier + ":" + $0.label }.suffix(12))")
        reveal(detail, in: app); XCTAssertTrue(detail.isHittable); detail.tap()
        XCTAssertTrue(app.navigationBars["Peso e calorie"].waitForExistence(timeout: 10))
        let caloriesPeriod = app.segmentedControls["health-calories-period"]
        reveal(caloriesPeriod, in: app)
        XCTAssertTrue(caloriesPeriod.isHittable)
        for period in ["Settimana", "Mese", "3 mesi"] {
            caloriesPeriod.buttons[period].tap()
            XCTAssertTrue(caloriesPeriod.buttons[period].isSelected)
        }
        let field = app.textFields["health-intake"]
        let scroll = app.scrollViews["health-detail-scroll"]
        for _ in 0..<5 { if field.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(field.isHittable)
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "2100")
        app.buttons["Fine"].tap()
        XCTAssertEqual(field.value as? String, "2100")
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        capture("health-scenario-2100")
    }
    func testHomeManyEventsAndTasksStayBoundedAndReachable() {
        let app = launch(["--busy-home", "--stress-content", "--dark"])
        let summary = app.staticTexts["home-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("Appuntamento 5"))
        XCTAssertFalse(summary.label.contains("Appuntamento 10"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-todo-")).count, 0)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-routine-")).count, 8)
        let events = app.buttons["home-events"]
        reveal(events, in: app); XCTAssertTrue(events.isHittable)
        events.tap()
        XCTAssertTrue(app.navigationBars["Prossimi appuntamenti"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Appuntamento 5"].exists)
        capture("home-many-events-agenda")
    }
    func testKeyboardAndLocalMovementFlow() {
        let app = launch()
        app.buttons["Aggiungi spesa"].tap()
        let description = app.textFields["Descrizione"]
        XCTAssertTrue(description.waitForExistence(timeout: 10))
        XCTAssertEqual(app.steppers.count, 0)
        XCTAssertFalse(app.buttons["Trattamento"].exists)
        description.tap(); description.typeText("Verifica interfaccia")
        capture("movement-keyboard")
        let amount = app.textFields["Importo €"]
        amount.tap(); amount.typeText("2")
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.buttons["Finanza"].waitForExistence(timeout: 10))
        app.buttons["Finanza"].tap()
        let all = app.buttons["all-movements"]
        for _ in 0..<8 { if all.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        XCTAssertTrue(all.isHittable); all.tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Verifica interfaccia").firstMatch.waitForExistence(timeout: 10))
        capture("movement-saved-locally")
    }
    func testLargeTextAndSixWeekCalendar() {
        let app = launch(["--large-text", "--six-weeks"])
        capture("accessibility-dashboard")
        app.buttons["Calendario"].tap()
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
        for (tab, title) in [("Dashboard", "Nuovo movimento"), ("Attività", "Nuova attività"), ("Calendario", "Nuovo evento"), ("Finanza", "Nuovo movimento")] {
            app.buttons[tab].tap()
            addButton(app).tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
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
        app.tabBars.buttons["Attività"].tap()
        let wishes = app.buttons["task-category-wish"], actions = app.buttons["task-category-action"]
        XCTAssertTrue(wishes.waitForExistence(timeout: 10)); wishes.tap()
        XCTAssertTrue(wishes.isSelected)
        actions.tap(); XCTAssertTrue(actions.isSelected)
        assertMinimumTouchTarget(actions)
        let completion = app.buttons["Cambia completamento Organizzare la settimana"]
        XCTAssertTrue(completion.waitForExistence(timeout: 10)); XCTAssertTrue(completion.isHittable)
        assertMinimumTouchTarget(completion)
        app.buttons["task-open-1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inline-task-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        app.buttons["inline-task-details"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        capture("shared-task-rows")
        completion.tap()
        XCTAssertTrue(app.staticTexts["Attivo"].waitForExistence(timeout: 10))
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
        let app = launch(["--stress-content", "--dark"])
        for tab in ["Dashboard", "Attività", "Calendario", "Finanza"] {
            app.buttons[tab].tap()
            let tabs = app.buttons["Dashboard"]
            let before = tabs.frame
            let surface = tab == "Attività" ? app.collectionViews.firstMatch : app.scrollViews[tab == "Dashboard" ? "dashboard-scroll" : tab == "Finanza" ? "finance-scroll" : "calendar-scroll"]
            XCTAssertTrue(surface.waitForExistence(timeout: 10))
            for _ in 0..<4 { surface.swipeUp(velocity: .fast) }
            for _ in 0..<3 { surface.swipeUp(velocity: .fast) }
            for _ in 0..<7 { surface.swipeDown(velocity: .fast) }
            XCTAssertTrue(app.buttons["Dashboard"].isHittable)
            XCTAssertTrue(app.buttons["Calendario"].isHittable)
            XCTAssertEqual(before.height, tabs.frame.height, accuracy: 2)
            capture("boundary-" + tab)
        }
    }
    func testCalendarEventCanBeCreatedAfterBoundaryScroll() {
        let app = launch(["--dark"])
        app.buttons["Calendario"].tap()
        let scroll = app.scrollViews["calendar-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<4 { scroll.swipeUp(velocity: .fast) }
        // With continuous months there is no bottom boundary; use the persistent toolbar action.
        let add = app.buttons["primary-add"]
        XCTAssertTrue(add.isHittable)
        XCTAssertLessThan(add.frame.maxY, app.buttons["Dashboard"].frame.minY - 4)
        add.tap()
        let title = app.textFields["Titolo"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap(); title.typeText("Evento dopo scorrimento")
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.buttons["Calendario"].waitForExistence(timeout: 10))
        // A single-line native Button exposes its title as the button label, not a child StaticText.
        let eventTitle = app.buttons.matching(NSPredicate(format: "label == %@", "Evento dopo scorrimento")).firstMatch
        app.buttons["calendar-today"].tap()
        // SwiftUI can report a clipped button as hittable beneath a safe-area inset.
        // Keep the complete row inside the visible content before tapping it.
        let upperEdge = app.buttons["calendar-today"].frame.maxY + 60
        let lowerEdge = app.tabBars.firstMatch.frame.minY
        for _ in 0..<16 {
            let frame = eventTitle.frame
            if eventTitle.exists && frame.minY >= upperEdge && frame.maxY <= lowerEdge { break }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            let delta: CGFloat = frame.minY < upperEdge ? 0.14 : -0.14
            start.press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6 + delta)))
        }
        XCTAssertGreaterThanOrEqual(eventTitle.frame.minY, upperEdge)
        XCTAssertLessThanOrEqual(eventTitle.frame.maxY, lowerEdge)
        XCTAssertTrue(eventTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(eventTitle.isHittable)
        let titleFrame = eventTitle.frame
        let checkboxes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "event-check-"))
        let nearest = checkboxes.allElementsBoundByIndex.min { abs($0.frame.midY - titleFrame.midY) < abs($1.frame.midY - titleFrame.midY) }
        XCTAssertNotNil(nearest)
        if let nearest { assertMinimumTouchTarget(nearest); XCTAssertEqual(nearest.frame.midY, titleFrame.midY, accuracy: 2, "Senza orario o luogo il titolo deve essere centrato sul controllo") }
        capture("calendar-event-after-scroll")
        eventTitle.tap()
        XCTAssertTrue(app.navigationBars["Modifica evento"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["Titolo"].value as? String, "Evento dopo scorrimento")
        app.buttons["Annulla"].tap()
        for _ in 0..<4 { scroll.swipeDown(velocity: .fast) }
        addButton(app).tap()
        XCTAssertTrue(app.textFields["Titolo"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
    }
    func testCalendarSelectionUpdatesImmediatelyAndKeepsEventIndex() {
        let app = launch(["--dark"])
        app.buttons["Calendario"].tap()
        let cells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-day-"))
        XCTAssertGreaterThanOrEqual(cells.count, 28)
        // Resolve each date by identity: lazy months can enter/leave the accessibility tree.
        app.buttons["calendar-today"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: Date())
        for index in [9, 10, 11, 10] {
            let day = month + String(format: "-%02d", index + 1)
            let cell = app.buttons["calendar-day-" + day]
            cell.tap()
            XCTAssertTrue(cell.isSelected, "Il giorno deve essere selezionato al termine del tocco: \(day)")
        }
        capture("calendar-repeated-selection")
    }
    func testLongTaskOpensAfterScrollingWithoutTriggeringCompletion() {
        let app = launch(["--stress-content"])
        app.buttons["Attività"].tap()
        let title = "Attività lunga di verifica 1: pianificare e organizzare gli impegni della settimana"
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
        app.buttons["task-open-1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inline-task-title"].waitForExistence(timeout: 10))
        app.buttons["inline-task-details"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        capture("long-task-editor")
        app.buttons["Annulla"].tap()
        let inlineTitle = app.descendants(matching: .any)["inline-task-title"]
        XCTAssertTrue(inlineTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(inlineTitle.value as? String, title)
        XCTAssertEqual(app.buttons["Cambia completamento " + title].value as? String, "Da completare")
    }
    func testDashboardDayRestoresCalendarMonthAndSelection() {
        let app = launch()
        app.buttons["Calendario"].tap()
        app.buttons["Mese precedente"].tap()
        app.buttons["Dashboard"].tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date())
        app.buttons["dashboard-day-" + day].tap()
        let selected = app.buttons["calendar-day-" + day]
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        XCTAssertTrue(selected.isSelected)
    }
    func testNegativeBudgetAndGroupedAmounts() {
        let app = launch(["--stress-money", "--dark"])
        app.buttons["Finanza"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1.234,56")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["finance-current-balance"].label.contains("12.345,67"))
        capture("negative-budget-and-grouped-amounts")
    }
    func testFinanceMonthButtonsMoveIndependentlyInBothDirections() {
        let app = launch(["--dark"])
        app.buttons["Finanza"].tap()
        selectFinanceSection("Extra", in: app)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "it_IT"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "MMMM yyyy"
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = formatter.timeZone
        let current = formatter.string(from: Date()).capitalized
        let previous = formatter.string(from: calendar.date(byAdding: .month, value: -1, to: Date())!).capitalized
        app.buttons["Mese precedente"].tap()
        XCTAssertTrue(app.staticTexts[previous].waitForExistence(timeout: 10))
        app.buttons["Mese successivo"].tap()
        XCTAssertTrue(app.staticTexts[current].waitForExistence(timeout: 10))
        capture("extra-month-navigation")
    }
    func testVisibleShiftBrushPaintsAndUndoRestoresDay() {
        let app = launch(["--dark"])
        app.buttons["Calendario"].tap()
        app.buttons["toggle-shift-paint"].tap()
        let brush = app.buttons["shift-brush-afternoon"]
        XCTAssertTrue(brush.waitForExistence(timeout: 10)); brush.tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Rome"); formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["calendar-day-" + formatter.string(from: Date())]
        day.tap()
        XCTAssertTrue(day.label.contains("Pomeriggio"))
        capture("calendar-paint-palette")
        app.buttons["Annulla"].tap()
        XCTAssertTrue(day.label.contains("Mattina"))
        app.buttons["toggle-shift-paint"].tap()
    }
    func testSavingsBreakdownAndDirectTaskReorder() {
        let app = launch(["--dark"])
        app.buttons["Finanza"].tap()
        openBudget(app)
        let assets = app.descendants(matching: .any)["finance-total-assets"]
        for _ in 0..<5 { if assets.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(assets.exists)
        capture("savings-breakdown")
        app.buttons["Attività"].tap()
        XCTAssertTrue(app.buttons["Desideri"].exists)
        app.buttons["reorder-tasks"].tap()
        capture("task-categories-and-reorder")
        app.buttons["reorder-tasks"].tap()
    }
    func testExtraActualPaymentUsesSavingsAndKeepsMonthlyBudget() {
        let app = launch(["--stress-money", "--dark"])
        app.buttons["Finanza"].tap()
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
        app.tabBars.buttons["Finanza"].tap()
        app.buttons["finance-budget"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Stipendio di riferimento"].exists)
        XCTAssertFalse(app.staticTexts["Ricorrenti"].exists)
        capture("budget-unified-salary-and-plans")
        app.buttons["plans-info"].tap()
        XCTAssertTrue(app.navigationBars["Come funzionano i piani"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["La regola di base"].exists)
        capture("plans-info")
        app.navigationBars.buttons["Fine"].tap()
        app.buttons["plans-add"].tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10))
        app.buttons["plan-kind"].tap()
        app.buttons["Anticipa budget"].tap()
        let name = app.textFields["plan-name"]; name.tap(); name.typeText("Anticipo prova")
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
    func testPlansGoalPaymentWithOptionalOverageRecovery() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Finanza"].tap(); app.buttons["finance-budget"].tap()
        app.buttons["plans-add"].tap()
        let name = app.textFields["plan-name"]; XCTAssertTrue(name.waitForExistence(timeout: 10)); name.tap(); name.typeText("Obiettivo prova")
        let amount = app.textFields["plan-amount"]; amount.tap(); amount.typeText("600")
        app.buttons["Fine"].tap(); app.buttons["plan-save"].tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))
        app.staticTexts["Obiettivo prova"].tap()
        app.buttons["plan-record-payment"].tap()
        let field = app.textFields["plan-payment-amount"]; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "700")
        app.buttons["Fine"].tap()
        let recovery = app.switches["Recupera la differenza nei budget futuri"]
        for _ in 0..<5 { if recovery.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(recovery.isHittable); recovery.tap()
        capture("plans-goal-overage")
        app.buttons["plan-payment-confirm"].tap()
        XCTAssertTrue(app.navigationBars["Dettagli piano"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["plan-status"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["plan-status"].label.hasSuffix("Concluso"))
        XCTAssertFalse(app.buttons["plan-record-payment"].exists)
        capture("plans-goal-closed")
    }
    func testPlansFundCanEditFutureQuotaAndLinkAnExistingMovement() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Finanza"].tap(); app.buttons["finance-budget"].tap(); app.buttons["plans-add"].tap()
        app.buttons["plan-kind"].tap(); app.buttons["Fondo senza scadenza"].tap()
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
        let pay = app.buttons["plan-record-payment"]; reveal(pay, in: app); pay.tap()
        XCTAssertTrue(app.navigationBars["Registra pagamento"].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["Già registrato"].tap()
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
        app.tabBars.buttons["Finanza"].tap()
        app.buttons["finance-analysis"].tap()
        XCTAssertTrue(app.navigationBars["Analisi"].waitForExistence(timeout: 10))
        let picker = app.segmentedControls["category-period"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        for period in ["3 mesi", "6 mesi", "12 mesi"] {
            picker.buttons[period].tap()
            XCTAssertTrue(picker.buttons[period].isSelected)
            XCTAssertTrue(app.buttons["Tutte le categorie"].waitForExistence(timeout: 10) || app.staticTexts["Tutte le categorie"].exists)
            capture("category-period-" + period)
        }
        XCTAssertFalse(app.staticTexts["Entrate e uscite"].exists)
        for title in ["Previsione patrimonio", "Patrimonio", "Stipendi per competenza"] {
            let heading = app.staticTexts[title]
            for _ in 0..<8 { if heading.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
            XCTAssertTrue(heading.exists)
        }
        capture("analysis-four-charts")
    }
    func testGoalsAreIndependentlyEditableAndReloadAfterSave() {
        let app = launch(["--dark"])
        app.buttons["Finanza"].tap()
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
        app.buttons["Finanza"].tap()
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        XCTAssertFalse(app.otherElements["wealth-forecast-chart"].exists)
        let expense = app.buttons["finance-expense"], extra = app.buttons["finance-new-plan"], budget = app.buttons["finance-budget"]
        XCTAssertTrue(expense.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(expense.frame.minX, extra.frame.maxX)
        XCTAssertGreaterThan(extra.frame.minX, budget.frame.maxX)
        let analysis = app.buttons["finance-analysis"]
        XCTAssertGreaterThan(analysis.frame.minX, expense.frame.maxX)
        for action in [expense, extra, budget, analysis] { assertMinimumTouchTarget(action) }
        extra.tap()
        XCTAssertTrue(app.navigationBars["Nuovo piano"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        expense.tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        let all = app.buttons["all-movements"]
        for _ in 0..<6 { if all.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        XCTAssertTrue(all.isHittable); all.tap()
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
            app.tabBars.buttons["Calendario"].tap()
            addButton(app).tap()
            XCTAssertTrue(app.navigationBars["Nuovo evento"].waitForExistence(timeout: 10))
            app.buttons["Annulla"].tap()
            XCTAssertTrue(app.navigationBars["Calendario"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.tabBars.buttons["Calendario"].isSelected)
        }
    }
    private func revealFinanceControl(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["finance-scroll"]
        for _ in 0..<18 {
            if element.isHittable { return }
            let visible = scroll.frame.intersection(app.frame)
            let top = max(visible.minY, app.navigationBars.firstMatch.frame.maxY)
            let bottom = min(visible.maxY, app.tabBars.firstMatch.frame.minY)
            guard bottom > top else { return }
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
            app.tabBars.buttons["Finanza"].tap()
            let expense = app.buttons["finance-expense"]
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
        app.tabBars.buttons["Attività"].tap()
        let wishes = app.buttons["task-category-wish"], actions = app.buttons["task-category-action"]
        wishes.tap(); XCTAssertTrue(wishes.isSelected)
        actions.tap(); XCTAssertTrue(actions.isSelected)
        let completion = app.buttons["Cambia completamento Organizzare la settimana"]
        XCTAssertTrue(completion.waitForExistence(timeout: 10))
        completion.tap()
        XCTAssertTrue(app.staticTexts["Attivo"].waitForExistence(timeout: 10))
        let archived = app.buttons["toggle-completed-tasks"]
        revealChecklistButton(archived, in: app)
        XCTAssertEqual(archived.value as? String, "Chiusa")
        archived.tap()
        revealChecklistButton(completion, in: app)
        XCTAssertEqual(completion.value as? String, "Completata")
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        completion.tap(); revealChecklistButton(completion, in: app, towardTop: true); XCTAssertEqual(completion.value as? String, "Da completare")
        app.tabBars.buttons["Finanza"].tap()
        let expense = app.buttons["finance-expense"]
        for _ in 0..<5 { if expense.isHittable { break }; app.scrollViews["finance-scroll"].swipeUp() }
        expense.tap()
        XCTAssertTrue(app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.tabBars.buttons["Finanza"].isSelected)
        capture("reduced-motion-finance")
    }

    func testCalendarTodayRestoresMonthAndSelection() {
        let app = launch(["--dark"])
        app.tabBars.buttons["Calendario"].tap()
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
