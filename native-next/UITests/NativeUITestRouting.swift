import XCTest

extension XCUIApplication {
    // Build 92: the system TabView (Liquid Glass on iOS 26) replaces the custom bar.
    var mainTabBar: XCUIElement { tabBars.firstMatch }

    func openMainTab(_ name: String) {
        let destination = mainTabButton(name)
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Missing visible destination " + name)
        XCTAssertTrue(destination.isHittable, "Destination must remain directly reachable: " + name)
        destination.tap()
        // Keep the native tap path. Selection may be published after the event;
        // require the actual selected trait rather than an immediate snapshot.
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { element, _ in
            (element as? XCUIElement)?.isSelected == true
        }, object: destination)
        let result = XCTWaiter.wait(for: [selected], timeout: 10)
        if result != .completed {
            let capture = XCTAttachment(screenshot: screenshot())
            let activityName = "Navigation selection failure " + name
            capture.name = activityName
            capture.lifetime = .keepAlways
            XCTContext.runActivity(named: activityName) { activity in
                activity.add(capture)
            }
            print("TAB_SELECTION_FAILURE " + name + "\n" + debugDescription)
        }
        XCTAssertEqual(result, .completed, "The tapped destination must become selected: " + name)
    }

    func mainTabButton(_ name: String) -> XCUIElement {
        mainTabBar.buttons[name]
    }

    func isMainTabSelected(_ name: String) -> Bool {
        mainTabButton(name).isSelected
    }

    // Historical helper name retained for existing behavioral regressions.
    func openOtherDestination(_ name: String) {
        if name == "Bloom" { openMainTab("Bloom"); return }
        openMainTab("Dashboard")
        for _ in 0..<8 {
            if scrollViews["dashboard-scroll"].exists { break }
            if buttons["calendar-back-month"].exists { buttons["calendar-back-month"].tap(); continue }
            if buttons["other-back"].exists { buttons["other-back"].tap(); continue }
            let back = navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap() } else { break }
        }
        if name == "Calendario" {
            let day = buttons["home-calendar"]
            for _ in 0..<12 { if day.isHittable { break }; scrollViews["dashboard-scroll"].swipeDown(velocity: .slow) }
            XCTAssertTrue(day.isHittable); day.tap()
        } else {
            let destination = buttons["home-finance"]
            for _ in 0..<16 { if destination.isHittable { break }; scrollViews["dashboard-scroll"].swipeUp(velocity: .slow) }
            XCTAssertTrue(destination.isHittable); destination.tap()
        }
    }
}

extension XCUIElementQuery {
    /// When a sheet is open over another one (quick add over the catalog, a menu over a form) the same identifier or
    /// label can match twice: this returns the one the user can actually touch, else the last (top-most) match.
    func visible(_ key: String) -> XCUIElement {
        let matches = matching(NSPredicate(format: "identifier == %@ OR label == %@", key, key))
        let all = matches.allElementsBoundByIndex
        return all.first(where: { $0.exists && $0.isHittable }) ?? all.last ?? matches.firstMatch
    }
}

extension XCUIApplication {
    /// SALUTE-SINGLE-ENTRY-2026-11-26: weight, TDEE, simulation and calories live in «Obiettivi e statistiche».
    /// Opens it from the Salute page; does nothing when it is already open.
    func openHealthStats() {
        if navigationBars["Obiettivi e statistiche"].exists { return }
        let entry = buttons["health-open-stats"]
        guard entry.waitForExistence(timeout: 10) else { return }
        let scroll = scrollViews["health-detail-scroll"]
        for _ in 0..<10 where !entry.isHittable || entry.frame.maxY > mainTabBar.frame.minY - 60 { scroll.swipeUp(velocity: .slow) }
        entry.tap()
        _ = navigationBars["Obiettivi e statistiche"].waitForExistence(timeout: 10)
    }
}

extension XCUIApplication {
    /// CALENDAR-TAP-SELECT-97: tapping a day only selects it; the day list opens from «Agenda».
    func openCalendarAgenda() {
        if scrollViews["calendar-day-pane"].exists { return }
        let agenda = buttons["calendar-view-agenda"] // the Mese/Agenda switch; «Agenda» can also be a title
        if agenda.waitForExistence(timeout: 5) { agenda.tap() }
        _ = scrollViews["calendar-day-pane"].waitForExistence(timeout: 10)
    }
}
