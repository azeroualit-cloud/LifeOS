import XCTest

extension XCUIApplication {
    func openOtherDestination(_ name: String) {
        tabBars.buttons["Altro"].tap()
        for _ in 0..<8 {
            if navigationBars["Altro"].exists { break }
            if buttons["calendar-back-month"].exists { buttons["calendar-back-month"].tap(); continue }
            if buttons["other-back"].exists { buttons["other-back"].tap(); continue }
            let back = navigationBars.buttons.firstMatch
            if back.exists && back.isHittable { back.tap() } else { break }
        }
        let destination = buttons[name]
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Altro destination must remain reachable: " + name)
        destination.tap()
    }
}
