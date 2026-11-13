import XCTest

extension XCUIApplication {
    /// Native iPhone tab bars place destinations after the fourth in More.
    func openMainTab(_ name: String) {
        let direct = tabBars.buttons[name]
        if direct.exists && direct.isHittable { direct.tap(); return }
        let more = tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["Altro", "More"])).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "Missing native overflow tab for " + name)
        more.tap()
        let destination = tables.staticTexts[name].firstMatch
        if !destination.waitForExistence(timeout: 3) {
            let back = navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["Altro", "More"])).firstMatch
            if back.exists && back.isHittable { back.tap() }
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Missing overflow destination " + name)
        destination.tap()
    }

    func mainTabButton(_ name: String) -> XCUIElement {
        let direct = tabBars.buttons[name]
        if direct.exists { return direct }
        return tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["Altro", "More"])).firstMatch
    }

    func isMainTabSelected(_ name: String) -> Bool {
        if tabBars.buttons[name].exists && tabBars.buttons[name].isSelected { return true }
        let more = tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["Altro", "More"])).firstMatch
        return more.exists && more.isSelected && navigationBars[name].exists
    }

    // Historical helper name retained for existing behavioral regressions.
    func openOtherDestination(_ name: String) {
        if name == "Bloom" { openMainTab("Bloom"); return }
        tabBars.buttons["Dashboard"].tap()
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
