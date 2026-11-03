import XCTest
@testable import LifeOSProbe

final class NativeHomeChecklistTests: XCTestCase {
    func testOrderingAndSourceIdentitiesRemainDistinct() {
        let today = "2026-11-03"
        let overdue: Record = ["id": .int(1), "title": .string("Overdue"), "due_date": .string("2026-11-02"), "status": .string("todo")]
        let event: Record = ["id": .int(1), "day": .string(today), "start_time": .string("09:00")]
        let routine: Record = ["id": .int(1), "title": .string("Routine")]
        let rows = NativeHomeChecklist.rows(tasks: [overdue], events: [event, event], routines: [routine], today: today)
        XCTAssertEqual(rows.map(\.id), ["task:1", "event:1:2026-11-03", "routine:1"])
        XCTAssertEqual(rows.map(\.kind), [.task, .event, .routine])
    }
    func testCompletedAndFutureScheduledTasksAndClosedEventsAreExcluded() {
        let tasks: [Record] = [
            ["id": .int(1), "status": .string("done")],
            ["id": .int(2), "status": .string("waiting")],
            ["id": .int(3), "scheduled_date": .string("2026-11-04")]
        ]
        let events: [Record] = [["id": .int(4), "day": .string("2026-11-03"), "occurrence_status": .string("done")]]
        XCTAssertTrue(NativeHomeChecklist.rows(tasks: tasks, events: events, routines: [], today: "2026-11-03").isEmpty)
    }
}
