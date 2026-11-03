import XCTest

final class NativeRevision77UITests: XCTestCase {
    func testFourTabsAndDirectHealthAndBloom() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home"]
        app.launch()
        for name in ["Dashboard", "Attività", "Salute", "Bloom"] {
            XCTAssertTrue(app.tabBars.buttons[name].waitForExistence(timeout: 15))
        }
        XCTAssertFalse(app.tabBars.buttons["Altro"].exists)
        app.tabBars.buttons["Salute"].tap()
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
        capture("Salute diretta", app)
        app.tabBars.buttons["Bloom"].tap()
        XCTAssertTrue(app.navigationBars["Bloom"].waitForExistence(timeout: 10))
        capture("Bloom", app)
        app.tabBars.buttons["Dashboard"].tap()
        capture("Dashboard", app)
    }
    func testLargeTextDashboardAndHealth() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--large-text", "--reduce-motion"]
        app.launch()
        XCTAssertTrue(app.scrollViews["dashboard-scroll"].waitForExistence(timeout: 15))
        capture("Dashboard testo grande", app)
        app.tabBars.buttons["Salute"].tap()
        XCTAssertTrue(app.scrollViews["health-detail-scroll"].waitForExistence(timeout: 10))
        capture("Salute testo grande", app)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
