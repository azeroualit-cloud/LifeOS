import XCTest

final class HealthChartVisualTests: XCTestCase {
    func testEntireHomeHealthChartIsVisible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 30))
        let detail = app.buttons["home-health-detail"]
        let scroll = app.scrollViews["dashboard-scroll"]
        for _ in 0..<5 {
            if detail.exists && detail.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(detail.label.contains("kcal a sinistra, kg a destra"))
        XCTAssertLessThan(detail.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "complete-home-health-chart"
        image.lifetime = .keepAlways
        add(image)
    }
}
