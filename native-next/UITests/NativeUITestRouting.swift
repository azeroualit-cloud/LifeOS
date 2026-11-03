import XCTest

extension XCUIApplication {
    // Historical helper name retained for existing behavioral regressions.
    func openOtherDestination(_ name: String) {
        if name == "Bloom" { tabBars.buttons["Bloom"].tap(); return }
        tabBars.buttons["Dashboard"].tap()
        for _ in 0..<8 {
            if scrollViews["dashboard-scroll"].exists { break }
            if buttons["calendar-back-month"].exists { buttons["calendar-back-month"].tap(); continue }
            if buttons["other-back"].exists { buttons["other-back"].tap(); continue }
            let back = navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap() } else { break }
        }
        if name == "Calendario" {
            let day = buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard-day-")).firstMatch
            for _ in 0..<12 { if day.isHittable { break }; scrollViews["dashboard-scroll"].swipeDown(velocity: .slow) }
            XCTAssertTrue(day.isHittable); day.tap()
        } else {
            let destination = buttons["home-finance"]
            for _ in 0..<16 { if destination.isHittable { break }; scrollViews["dashboard-scroll"].swipeUp(velocity: .slow) }
            XCTAssertTrue(destination.isHittable); destination.tap()
        }
    }
}
