import XCTest
@testable import LifeOSProbe

final class NativeRoutineNextTests: XCTestCase {
    private func routine(_ mode: String, interval: Int = 1, weekdays: [Int] = [], start: String, checked: Bool) -> Record {
        ["id": .int(1), "title": .string("Prova"), "checked": .bool(checked),
         "schedule": .object(["mode": .string(mode), "intervalDays": .int(interval), "weekdays": .array(weekdays.map(JSONValue.int)), "startDate": .string(start)])]
    }

    func testIntervalHabitShowsNextOccurrenceNotStartDate() {
        let today = "2026-11-18"
        XCTAssertEqual(NativeRoutineSchedule.nextDue(routine("interval", interval: 3, start: "2026-11-16", checked: false), today: today), "2026-11-19")
        XCTAssertEqual(NativeRoutineSchedule.nextLabel(routine("interval", interval: 3, start: "2026-11-16", checked: false), today: today), "Prossima: domani")
    }

    func testDoneTodayMovesToTheFollowingOccurrence() {
        let today = "2026-11-18"
        XCTAssertEqual(NativeRoutineSchedule.nextLabel(routine("daily", start: "", checked: false), today: today), "Prossima: oggi")
        XCTAssertEqual(NativeRoutineSchedule.nextDue(routine("daily", start: "", checked: true), today: today), "2026-11-19")
        XCTAssertEqual(NativeRoutineSchedule.nextDue(routine("interval", interval: 2, start: today, checked: true), today: today), "2026-11-20")
    }
}
