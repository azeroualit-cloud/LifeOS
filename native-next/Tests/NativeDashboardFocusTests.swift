import XCTest
@testable import LifeOSProbe

final class NativeDashboardFocusTests: XCTestCase {
    private func time(_ hour: Int, _ minute: Int = 0, day: String = "2026-10-28") -> Date {
        CivilDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: CivilDate.date(day))!
    }
    func testUpcomingActiveAndFinishedShiftBoundaries() {
        let before = NativeDashboardFocus(now: time(5, 30), todayShift: .morning, previousShift: .rest)
        XCTAssertEqual(before.phase, "Più tardi"); XCTAssertEqual(before.remainingText, "30 min")
        let active = NativeDashboardFocus(now: time(13, 40), todayShift: .morning, previousShift: .rest)
        XCTAssertEqual(active.phase, "Adesso"); XCTAssertEqual(active.remainingText, "20 min")
        let finished = NativeDashboardFocus(now: time(14), todayShift: .morning, previousShift: .rest)
        XCTAssertNil(finished.interval); XCTAssertTrue(finished.detail.contains("terminato"))
    }
    func testNightContinuesOnRestDayUntilSixThenRestHasNoCountdown() {
        let night = NativeDashboardFocus(now: time(5), todayShift: .rest, previousShift: .night)
        XCTAssertEqual(night.shift, .night); XCTAssertEqual(night.remainingText, "1 h")
        let rest = NativeDashboardFocus(now: time(6), todayShift: .rest, previousShift: .night)
        XCTAssertEqual(rest.shift, .rest); XCTAssertNil(rest.interval)
    }
    func testUnknownHolidayAndEraseNeverInventWorkingHours() {
        for shift: ShiftKind? in [nil, .erase, .rest, .holiday] {
            let result = NativeDashboardFocus(now: time(12), todayShift: shift, previousShift: nil)
            XCTAssertNil(result.interval); XCTAssertEqual(result.remainingText, "")
        }
    }
    func testOvernightDaylightSavingUsesCivilHours() {
        let now = time(22, day: "2026-10-24")
        let night = NativeDashboardFocus(now: now, todayShift: .night, previousShift: .rest)
        XCTAssertEqual(night.remainingText, "9 h")
        XCTAssertEqual(CivilDate.calendar.component(.hour, from: night.interval!.end), 6)
    }
}
