import XCTest
@testable import LifeOSProbe

final class NativeCalendarPerformanceTests: XCTestCase {
    func testWindowStaysBoundedAndContiguousAcrossYearsAndReverseScrolling() {
        var window = NativeCalendarWindow.months(around: "2026-10")
        for offset in Array(0...120) + Array((0...120).reversed()) {
            let month = NativeCalendarWindow.offset("2026-10", by: offset)
            window = NativeCalendarWindow.extended(window, around: month)
            XCTAssertLessThanOrEqual(window.count, NativeCalendarWindow.capacity)
            XCTAssertTrue(window.contains(month))
            XCTAssertEqual(Set(window).count, window.count)
            for pair in zip(window,window.dropFirst()) { XCTAssertEqual(NativeCalendarWindow.offset(pair.0,by:1),pair.1) }
        }
        XCTAssertEqual(NativeCalendarWindow.extended(window, around: "2099-01"), NativeCalendarWindow.months(around:"2099-01"))
    }
    func testSnapshotsOutsideTheRetainedWindowCannotGrowTheCache() {
        let window = NativeCalendarWindow.months(around: "2028-03", radius: 6)
        XCTAssertTrue(NativeCalendarWindow.coveredMonths(around:"2026-10", within:window).isEmpty)
        var keys = Set<String>()
        for month in window { keys.formUnion(NativeCalendarWindow.coveredMonths(around:month, within:window)) }
        XCTAssertEqual(keys,Set(window)); XCTAssertEqual(keys.count,NativeCalendarWindow.capacity)
    }
    func testNonCalendarUpdatesDoNotInvalidateMonthlySnapshots() {
        let life: Record = ["month": .string("2026-10"), "events": .array([]), "shifts": .array([]), "tasks": .array([])]
        let key = NativeCalendarSource(life:life,demo:false,origin:"https://example.com")
        var changed=life; changed["routines"] = .array([.object(["checked":.bool(true)])]); changed["health"] = .array([])
        XCTAssertEqual(key,NativeCalendarSource(life:changed,demo:false,origin:"https://example.com"))
        changed["events"] = .array([.object(["id":.int(1)])])
        XCTAssertNotEqual(key,NativeCalendarSource(life:changed,demo:false,origin:"https://example.com"))
        XCTAssertNotEqual(key,NativeCalendarSource(life:life,demo:true,origin:"https://example.com"))
        XCTAssertNotEqual(key,NativeCalendarSource(life:life,demo:false,origin:"https://other.example.com"))
    }
    func testGridPreservesLeapDaysSixWeeksAndRomeDaylightSaving() {
        for month in ["2024-02","2026-03","2026-10","2027-01"] {
            let dates = CivilDate.gridDates(month), days = CivilDate.grid(month)
            XCTAssertEqual(days, dates.map { CivilDate.day($0) })
            XCTAssertEqual(days.count % 7,0)
            XCTAssertEqual(CivilDate.calendar.component(.weekday,from:dates[0]),2)
            for pair in zip(days,days.dropFirst()) { XCTAssertEqual(CivilDate.adding(1,to:pair.0),pair.1) }
            for pair in zip(days,dates) { XCTAssertEqual(CivilDate.label(pair.0),CivilDate.label(pair.1)) }
        }
        XCTAssertTrue(CivilDate.grid("2024-02").contains("2024-02-29"))
        XCTAssertEqual(CivilDate.grid("2026-03").count,42)
        XCTAssertEqual(CivilDate.day(CivilDate.date("2026-10-25")),"2026-10-25")
        XCTAssertEqual(NativeCalendarWindow.monthLabel("2026-10"),"Ott")
        XCTAssertEqual(Input.day(CivilDate.date("2026-03-29")),"2026-03-29")
    }
}
