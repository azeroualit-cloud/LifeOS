import XCTest

final class NativeBloomGridUITests: XCTestCase {
    func testMixedLibraryStaysInTwoColumnsAndShowsLinkPreviews() {
        checkGrid(large: false)
    }
    func testMixedLibraryWithLargeTextRemainsBounded() {
        checkGrid(large: true)
    }
    private func checkGrid(large: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--bloom-grid-fixture", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] + (large ? ["--large-text"] : [])
        app.launch()
        app.openMainTab("Bloom")
        let first = app.buttons["bloom-note-BA000000-0000-4000-8000-000000000000"]
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        let preview = app.images["bloom-link-image"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let scroll = app.scrollViews["bloom-library-scroll"]
        XCTAssertTrue(scroll.exists)
        let initialWidth = first.frame.width
        for page in 0..<4 {
            let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bloom-note-")).allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(scroll.frame) }
            XCTAssertFalse(cards.isEmpty)
            for card in cards {
                XCTAssertEqual(card.frame.width, initialWidth, accuracy: 1)
                XCTAssertLessThanOrEqual(card.frame.maxX, scroll.frame.maxX + 1)
                XCTAssertGreaterThanOrEqual(card.frame.minX, scroll.frame.minX - 1)
                for other in cards where other.identifier != card.identifier {
                    XCTAssertFalse(card.frame.insetBy(dx: 1, dy: 1).intersects(other.frame.insetBy(dx: 1, dy: 1)), "Overlapping cards")
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Bloom mixed grid \(large ? "large" : "standard") page \(page)"
            attachment.lifetime = .keepAlways; add(attachment)
            let bottom = min(scroll.frame.maxY, app.mainTabBar.frame.minY) - 24
            let top = scroll.frame.minY + 24
            XCTAssertGreaterThan(bottom - top, 44, "Insufficient reachable scroll area")
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: scroll.frame.midX, dy: bottom))
            let end = origin.withOffset(CGVector(dx: scroll.frame.midX, dy: max(top, bottom - 200)))
            let tracked = app.buttons[cards[0].identifier]
            let previousY = tracked.frame.minY
            start.press(forDuration: 0.05, thenDragTo: end)
            XCTAssertTrue(!tracked.exists || tracked.frame.minY < previousY - 1, "The library must actually scroll")
            XCTAssertTrue(app.isMainTabSelected("Bloom"), "Scroll must not hit the tab bar")
        }
    }
}
