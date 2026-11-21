import XCTest
@testable import LifeOSProbe

/// Build 93 Dashboard data (DASHBOARD-93-2026-11-21).
final class NativeDashboard93Tests: XCTestCase {
    private let today = "2026-11-21"
    private func event(_ id: Int, _ day: String, time: String = "", status: String = "open") -> Record {
        ["id": .int(id), "day": .string(day), "start_time": .string(time), "title": .string("E\(id)"), "occurrence_status": .string(status)]
    }

    func testUpcomingStartsAfterTheChecklistWindowAndIsSorted() {
        let rows = NativeDashboard93.upcoming(events: [
            event(1, "2026-11-22"), event(2, "2026-11-23"), event(3, "2026-12-04", time: "09:30"),
            event(4, "2026-11-24"), event(5, "2026-12-04", time: "08:00"), event(6, "2026-11-30", status: "done")
        ], today: today)
        XCTAssertEqual(rows.map { $0.integer("id") }, [4, 5, 3], "Today+2 belongs to Cose da fare; done events are hidden")
    }

    func testUpcomingRemovesDuplicatesAndKeepsThree() {
        let rows = NativeDashboard93.upcoming(events: [event(7, "2026-11-25"), event(7, "2026-11-25"), event(8, "2026-11-26"), event(9, "2026-11-27"), event(10, "2026-11-28")], today: today)
        XCTAssertEqual(rows.map { $0.integer("id") }, [7, 8, 9])
    }

    func testNextShiftSkipsRestAndStartedShifts() throws {
        let shifts: [String: ShiftKind] = ["2026-11-21": .morning, "2026-11-22": .rest, "2026-11-23": .afternoon]
        let noon = try XCTUnwrap(CivilDate.calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 12)))
        let next = try XCTUnwrap(NativeDashboard93.nextShift(now: noon, shift: { shifts[$0] }))
        XCTAssertEqual(next, .init(day: "2026-11-23", kind: .afternoon, start: "14:00"))
        let early = try XCTUnwrap(CivilDate.calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 5)))
        XCTAssertEqual(NativeDashboard93.nextShift(now: early, shift: { shifts[$0] })?.day, "2026-11-21")
        XCTAssertNil(NativeDashboard93.nextShift(now: noon, shift: { _ in .rest }))
    }

    func testNextShiftLabel() {
        XCTAssertEqual(NativeDashboard93.label(.init(day: today, kind: .afternoon, start: "14:00"), today: today), "oggi 14:00")
        XCTAssertEqual(NativeDashboard93.label(.init(day: "2026-11-22", kind: .morning, start: "06:00"), today: today), "domani 6:00")
    }

    func testSpentFraction() {
        XCTAssertEqual(try XCTUnwrap(NativeDashboard93.spentFraction(spent: 540, remaining: 210)), 0.72, accuracy: 0.001)
        XCTAssertEqual(NativeDashboard93.spentFraction(spent: 800, remaining: -50), 1)
        XCTAssertNil(NativeDashboard93.spentFraction(spent: 0, remaining: 0))
        XCTAssertNil(NativeDashboard93.spentFraction(spent: 100, remaining: nil))
    }
}
