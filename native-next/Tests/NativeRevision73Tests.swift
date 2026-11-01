import XCTest
@testable import LifeOSProbe

final class NativeRevision73Tests: XCTestCase {
    private func entry(_ id: Int, category: String = "action", day: String = "2026-11-01", completed: Bool = false) -> NativeCalendarAgendaEntry {
        .init(id: "event:\(id):\(day)", record: ["id": .int(id), "list_kind": .string(category), "day": .string(day), "status": .string(completed ? "done" : "todo")], source: "event", start: 360, end: 840)
    }
    func testGenericEventsAreDistinguishedWithoutUsingDatesOrCompletionAsColourKeys() {
        let colours = (1...6).map { NativeCalendarEventStyle.paletteIndex(for: entry($0)) }
        XCTAssertEqual(Set(colours).count, 6)
        XCTAssertEqual(NativeCalendarEventStyle.paletteIndex(for: entry(1)), NativeCalendarEventStyle.paletteIndex(for: entry(1, day: "2026-12-20", completed: true)))
    }
    func testExplicitCategoryKeepsTheSameColourAcrossActivities() {
        XCTAssertEqual(NativeCalendarEventStyle.paletteIndex(for: entry(1, category: "reading")), NativeCalendarEventStyle.paletteIndex(for: entry(27, category: "reading")))
    }
}
