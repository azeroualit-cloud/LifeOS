import XCTest
@testable import LifeOSProbe

final class NativeHomeChecklistTests: XCTestCase {
    func testAttentionWindowOrdersTodayThenRoutinesThenNextTwoDays() {
        let today = "2026-11-03"
        func event(_ id: Int, _ day: String) -> Record { ["id": .int(id), "day": .string(day), "start_time": .string("09:00")] }
        let events = [event(4,"2026-11-06"), event(3,"2026-11-05"), event(2,"2026-11-04"), event(1,today), event(1,today), event(5,"2026-11-02")]
        let rows = NativeHomeChecklist.rows(events: events, routines: [["id": .int(1)]], today: today)
        XCTAssertEqual(rows.map(\.id), ["event:1:2026-11-03", "routine:1", "event:2:2026-11-04", "event:3:2026-11-05"])
    }
    func testClosedEventsNeverAppearOnHome() {
        let events: [Record] = [["id": .int(4), "day": .string("2026-11-03"), "occurrence_status": .string("done")]]
        XCTAssertTrue(NativeHomeChecklist.rows(events: events, routines: [], today: "2026-11-03").isEmpty)
    }
}
