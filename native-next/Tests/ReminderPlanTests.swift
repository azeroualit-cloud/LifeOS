import XCTest
@testable import LifeOSProbe

final class ReminderPlanTests: XCTestCase {
    private let day = "2026-10-26"
    func testPlanUsesRomeAndExcludesDoneTasksAndRestDays() throws {
        let life: Record = [
            "tasks": .array([.object(["id": .int(1), "title": .string("Scadenza demo"), "status": .string("todo"), "due_date": .string(day)]), .object(["id": .int(2), "status": .string("done"), "due_date": .string(day)])]),
            "shifts": .array([.object(["day": .string(day), "kind": .string("morning")]), .object(["day": .string("2026-10-27"), "kind": .string("rest")])]),
            "upcomingEvents": .array([.object(["id": .int(3), "title": .string("Evento demo"), "day": .string(day), "start_time": .string("14:30")])])]
        let plan = ReminderPlan.make(life: life, now: CivilDate.date("2026-10-25"))
        XCTAssertEqual(plan.map(\.id), ["shift-2026-10-26", "task-1", "event-3-2026-10-26"])
        XCTAssertEqual(plan.map { CivilDate.calendar.component(.hour, from: $0.date) }, [5, 9, 14])
        XCTAssertEqual(CivilDate.calendar.component(.minute, from: plan[2].date), 15)
        XCTAssertTrue(ReminderPlan.make(life: life, now: CivilDate.date("2026-10-28")).isEmpty)
    }
    func testScheduledTimeAndOriginalIdentityDriveNotification() throws {
        let task: Record = ["id": .int(7), "status": .string("todo"), "scheduled_date": .string(day), "due_date": .string("2026-11-01"), "scheduled_time": .string("16:30")]
        let plan = ReminderPlan.make(life: ["tasks": .array([.object(task)])], now: CivilDate.date("2026-10-25"))
        let reminder = try XCTUnwrap(plan.first)
        XCTAssertEqual(CivilDate.calendar.component(.hour, from: reminder.date),16)
        XCTAssertEqual(CivilDate.calendar.component(.minute, from: reminder.date),30)
        XCTAssertEqual(reminder.route,"activities?task=7")
        var completed = task; completed["status"] = .string("done")
        XCTAssertTrue(ReminderPlan.make(life:["tasks":.array([.object(completed)])],now:CivilDate.date("2026-10-25")).isEmpty)
    }
    func testPlanLimitsTo48AndDeduplicates() {
        let tasks = (1...70).map { id in JSONValue.object(["id": .int(id), "status": .string("todo"), "due_date": .string(day)]) }
        let plan = ReminderPlan.make(life: ["tasks": .array(tasks + tasks)], now: CivilDate.date("2026-10-25"))
        XCTAssertEqual(plan.count, 48)
        XCTAssertEqual(Set(plan.map(\.id)).count, 48)
    }
}
