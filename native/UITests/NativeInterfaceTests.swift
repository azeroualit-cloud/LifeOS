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
        if title == "Extra" {
            let action = app.buttons["finance-extra"]
            for _ in 0..<5 { if action.isHittable { break }; app.scrollViews["finance-scroll"].swipeDown() }
            XCTAssertTrue(action.waitForExistence(timeout: 10)); action.tap()
            XCTAssertTrue(app.navigationBars["Extra"].waitForExistence(timeout: 10))
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
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
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
        let scroll = app.scrollViews["dashboard-scroll"]
        for _ in 0..<10 { if element.isHittable { return }; scroll.swipeUp() }
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
            let routines = app.staticTexts["home-routines-heading"]
            let todos = app.staticTexts["home-todos-heading"]
            XCTAssertTrue(routines.exists); XCTAssertTrue(todos.exists)
            XCTAssertLessThan(routines.frame.minY, todos.frame.minY)
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-todo-"))
            XCTAssertLessThanOrEqual(rows.count, 3)
            XCTAssertGreaterThan(rows.count, 0)
            let budget = app.buttons["home-budget"]
            reveal(budget, in: app); XCTAssertTrue(budget.isHittable)
            capture(dark ? "home-budget-dark" : "home-budget-light")
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
        let todos = app.buttons["home-empty-todos"]
        reveal(todos, in: app); XCTAssertTrue(todos.isHittable)
        todos.tap()
        XCTAssertTrue(app.navigationBars["Nuova attività"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        let budget = app.buttons["home-budget"]
        reveal(budget, in: app)
        XCTAssertEqual(budget.value as? String, "Da aggiornare")
        capture("home-empty")
    }
    func testHomeAllTodosRestoresActionCategory() {
        let app = launch(["--dark"])
        app.buttons["Attività"].tap()
        app.buttons["Desideri"].tap()
        XCTAssertFalse(app.staticTexts["Organizzare la settimana"].exists)
        app.buttons["Dashboard"].tap()
        let all = app.buttons["home-all-todos"]
        reveal(all, in: app); XCTAssertTrue(all.isHittable); all.tap()
        XCTAssertTrue(app.navigationBars["Attività"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Organizzare la settimana"].exists)
    }
    func testHomeManyEventsAndTasksStayBoundedAndReachable() {
        let app = launch(["--busy-home", "--stress-content", "--dark"])
        let summary = app.staticTexts["home-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("Appuntamento 5"))
        XCTAssertFalse(summary.label.contains("Appuntamento 10"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-todo-")).count, 3)
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
        XCTAssertEqual(addButton(app).label, "Aggiungi straordinaria")
        addButton(app).tap()
        XCTAssertTrue(app.textFields["Nome"].waitForExistence(timeout: 10))
        capture("bottom-add-extra")
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
        app.staticTexts["Organizzare la settimana"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inline-task-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        app.buttons["inline-task-details"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        app.buttons["Annulla"].tap()
        capture("shared-task-rows")
        completion.tap()
        XCTAssertTrue(app.staticTexts["Attivo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Completate"].exists)
        XCTAssertEqual(completion.value as? String, "Completata")
        capture("shared-completed-task-rows")
        completion.tap()
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
        for _ in 0..<8 { if eventTitle.isHittable { break }; scroll.swipeUp(velocity: .slow) }
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
        // Repeated day changes exercise selection without changing the month/data indexes.
        for index in [9, 10, 11, 10] {
            let cell = cells.element(boundBy: index)
            let day = String(cell.identifier.dropFirst("calendar-day-".count))
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
        app.staticTexts[title].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inline-task-title"].waitForExistence(timeout: 10))
        app.buttons["inline-task-details"].tap()
        XCTAssertTrue(app.navigationBars["Modifica attività"].waitForExistence(timeout: 10))
        capture("long-task-editor")
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.staticTexts[title].exists)
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
        app.staticTexts["Manutenzione auto"].tap()
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
        selectFinanceSection("Panoramica", in: app)
        XCTAssertTrue(app.staticTexts["finance-current-balance"].label.contains("11.795,66"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1.234,56")).firstMatch.exists)
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
        let expense = app.buttons["finance-expense"], extra = app.buttons["finance-extra"], budget = app.buttons["finance-budget"]
        XCTAssertTrue(expense.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(expense.frame.minX, extra.frame.maxX)
        XCTAssertGreaterThan(extra.frame.minX, budget.frame.maxX)
        for action in [expense, extra, budget] { assertMinimumTouchTarget(action) }
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
        XCTAssertFalse(app.staticTexts["Completate"].exists)
        XCTAssertEqual(completion.value as? String, "Completata")
        XCTAssertFalse(app.navigationBars["Modifica attività"].exists)
        completion.tap(); XCTAssertEqual(completion.value as? String, "Da completare")
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
