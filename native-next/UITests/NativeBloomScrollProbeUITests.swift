import XCTest

/// Same fixture and progress requirement; only the gesture's horizontal origin
/// differs, separating a real scroll freeze from a transparent-column-gap miss.
final class NativeBloomScrollProbeUITests: XCTestCase {
    func testDraggingInsideColumnMovesLibrary() { probe(column: true) }
    func testDraggingBetweenColumnsMovesLibrary() { probe(column: false) }

    private func probe(column: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-test", "--bloom-grid-fixture", "--dark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        app.openMainTab("Bloom")
        let first = app.buttons["bloom-note-BA000000-0000-4000-8000-000000000000"]
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        let scroll = app.scrollViews["bloom-library-scroll"]
        XCTAssertTrue(scroll.exists)
        let bounds = scroll.frame.intersection(app.frame)
        let top = bounds.minY + 24
        let bottom = min(bounds.maxY, app.mainTabBar.frame.minY) - 24
        XCTAssertGreaterThan(bottom - top, 44)
        let x = column ? first.frame.midX : bounds.midX
        let oldY = first.frame.minY
        capture(column ? "Bloom column before drag" : "Bloom gap before drag")
        print("BLOOM_DRAG_PROBE column=\(column) x=\(x) startY=\(bottom) endY=\(max(top, bottom - 200)) first=\(first.frame) scroll=\(bounds)")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: x - app.frame.minX, dy: bottom - app.frame.minY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x - app.frame.minX, dy: max(top, bottom - 200) - app.frame.minY)))
        let movement = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !first.exists || first.frame.minY < oldY - 1
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [movement], timeout: 5), .completed, "The library must actually scroll")
        XCTAssertTrue(app.isMainTabSelected("Bloom"))
        capture(column ? "Bloom column after drag" : "Bloom gap after drag")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
