import XCTest

final class NativeTabHitRegionUITests: XCTestCase {
    func testEveryTabRespondsAtCenterIconAndCaption() { checkHitRegions(large: false) }
    func testEveryLargeTextTabRespondsAtCenterAndIcon() { checkHitRegions(large: true) }

    private func checkHitRegions(large: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--busy-home", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + (large ? ["--large-text"] : [])
        app.launch()
        XCTAssertTrue(app.mainTabBar.waitForExistence(timeout: 15))
        // The first action reproduces the failing fresh-launch Calendar center tap.
        let titles = ["Calendario", "Dashboard", "Attività", "Salute", "Bloom", "Finanza"]
        let regions = large ? ["center", "icon"] : ["center", "icon", "caption"]
        for region in regions {
            for title in titles {
                let button = app.mainTabButton(title)
                XCTAssertTrue(button.exists && button.isHittable, title)
                let target: XCUIElement
                switch region {
                case "icon":
                    target = button.images.firstMatch
                case "caption":
                    target = button.staticTexts[title]
                default:
                    target = button
                }
                XCTAssertTrue(target.exists, "Missing " + region + " for " + title)
                target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let selected = XCTNSPredicateExpectation(predicate: NSPredicate { element, _ in (element as? XCUIElement)?.isSelected == true }, object: button)
                XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, title + " must respond to " + region)
                let destination: XCUIElement
                switch title {
                case "Calendario": destination = app.scrollViews["calendar-scroll"]
                case "Dashboard": destination = app.scrollViews["dashboard-scroll"]
                case "Attività": destination = app.navigationBars["Attività"]
                case "Salute": destination = app.scrollViews["health-detail-scroll"]
                case "Bloom": destination = app.navigationBars["Bloom"]
                default: destination = app.scrollViews["finance-scroll"]
                }
                XCTAssertTrue(destination.waitForExistence(timeout: 15), title + " content must be visible")
            }
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Six tab hit regions " + region + (large ? " large" : " standard")
            capture.lifetime = .keepAlways
            add(capture)
        }
    }
}
