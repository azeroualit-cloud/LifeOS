import XCTest

extension XCUIApplication {
    var mainTabBar: XCUIElement { otherElements["lifeos-main-tabs"] }

    func openMainTab(_ name: String) {
        let destination = mainTabButton(name)
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Missing visible destination " + name)
        XCTAssertTrue(destination.isHittable, "Destination must remain directly reachable: " + name)
        destination.tap()
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
