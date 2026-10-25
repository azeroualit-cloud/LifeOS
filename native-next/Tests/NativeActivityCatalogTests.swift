import XCTest
@testable import LifeOSProbe
final class NativeActivityCatalogTests: XCTestCase {
    func testEventsHaveSeparateIdentityAndCompletedActivitiesSortLast() {
        let task: Record = ["id": .int(1), "title": .string("Pasta"), "list_kind": .string("action"), "status": .string("done")]
        let event: Record = ["id": .int(1), "title": .string("Visita"), "day": .string("2026-10-25")]
        let rows = NativeActivityCatalog.rows(tasks: [task], events: [event, event], category: "action", section: "todo")
        XCTAssertEqual(rows.map(\.id), ["event:1:2026-10-25", "task:1"])
        XCTAssertEqual(rows[0].record, event)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks: [], events: [event], category: "shopping", section: "todo").isEmpty)
    }
}
