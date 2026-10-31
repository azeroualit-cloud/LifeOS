import XCTest
import UIKit
@testable import LifeOSProbe

@MainActor final class NativeRevision71Tests: XCTestCase {
    func testShiftOnlyChangesReturnExactlyEditedAndErasedDays() {
        let base: Record = ["month": .string("2026-10"), "events": .array([.object(["id": .int(1), "title": .string("Unchanged event")])]), "shifts": .array([.object(["day": .string("2026-10-30"), "kind": .string("morning")])])]
        var next = base
        next["shifts"] = .array([.object(["day": .string("2026-11-01"), "kind": .string("rest")])])
        let before = NativeCalendarSource(life: base, demo: false, origin: "fixture")
        let after = NativeCalendarSource(life: next, demo: false, origin: "fixture")
        XCTAssertEqual(after.shiftChanges(from: before), ["2026-10-30": "erase", "2026-11-01": "rest"])
        next["events"] = .array([])
        XCTAssertNil(NativeCalendarSource(life: next, demo: false, origin: "fixture").shiftChanges(from: before))
        XCTAssertNil(NativeCalendarSource(life: base, demo: true, origin: "fixture").shiftChanges(from: before))
        XCTAssertNil(NativeCalendarSource(life: base, demo: false, origin: "other").shiftChanges(from: before))
    }
    func testUrgentAlarmRejectsMalformedCivilDatesAndClocks() {
        XCTAssertNil(NativeUrgentAlarm.date(day: "2026-02-30", time: "10:00"))
        XCTAssertNil(NativeUrgentAlarm.date(day: "2026-11-01", time: "24:00"))
        XCTAssertNil(NativeUrgentAlarm.date(day: "2026-11-01", time: "09:60"))
        XCTAssertNil(NativeUrgentAlarm.date(day: "2026-11-01", time: "9:00"))
        XCTAssertNil(NativeUrgentAlarm.date(day: "", time: "10:00"))
        let date = NativeUrgentAlarm.date(day: "2026-11-01", time: "09:30")
        XCTAssertEqual(date.map(CivilDate.day), "2026-11-01")
        XCTAssertEqual(date.map { CivilDate.calendar.component(.hour, from: $0) }, 9)
        XCTAssertEqual(date.map { CivilDate.calendar.component(.minute, from: $0) }, 30)
    }
    func testCalendarNavigationDistinguishesDefaultMonthAndExplicitDay() {
        let router = NativeRouter()
        _ = router.enterCalendar(today: "2026-10-31")
        XCTAssertFalse(router.calendarOpensDay)
        router.showCalendar(day: "2026-11-02")
        XCTAssertTrue(router.calendarOpensDay)
        XCTAssertEqual(router.enterCalendar(today: "2026-10-31"), "2026-11-02")
        XCTAssertTrue(router.calendarOpensDay)
        _ = router.enterCalendar(today: "2026-10-31")
        XCTAssertFalse(router.calendarOpensDay)
        XCTAssertEqual(router.calendarDay, "2026-10-31")
    }
    func testContinuousMonthWeeksHaveNoDuplicatesOrGapsAtBoundaries() {
        let months = ["2026-10", "2026-11", "2026-12"]
        let days = months.enumerated().flatMap { index, month -> [String] in
            let grid = CivilDate.gridDates(month)
            return NativeCalendarWindow.weekIndexes(month, includeLeading: index == 0).flatMap { week in
                (0..<7).map { CivilDate.day(grid[week * 7 + $0]) }
            }
        }
        XCTAssertEqual(days.count, Set(days).count)
        XCTAssertEqual(days.filter { $0 == "2026-11-01" }.count, 1)
        XCTAssertTrue(days.contains("2027-01-01"))
        for (a, b) in zip(days, days.dropFirst()) { XCTAssertEqual(CivilDate.adding(1, to: a), b) }
    }
    func testDemoCannotCancelARealUrgentAlarmWithTheSameLegacyIdentity() throws {
        let previous = NativeUrgentAlarm.entries
        defer { NativeUrgentAlarm.entries = previous }
        let entry = NativeUrgentAlarm.Entry(id: UUID(), identity: "event:1", day: "2099-01-01", title: "Real event fixture", date: .distantFuture)
        NativeUrgentAlarm.entries = [entry]
        try NativeUrgentAlarm.cancel(identity: "event:1", demo: true)
        XCTAssertEqual(NativeUrgentAlarm.entries, [entry])
    }
    func testWidgetUsesTheNewGalleryIdentityAndKeepsTheSharedDataGroup() {
        XCTAssertEqual(LifeOSWidgetStorage.kind, "LifeOSOverview")
        XCTAssertEqual(LifeOSWidgetStorage.group, "group.com.nas.lifeos")
    }
    func testHealthAccentIsChromaticInBothThemes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let color = UIColor(NativeDesign.healthAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertGreaterThan(max(red, green, blue) - min(red, green, blue), 0.2)
        }
    }
}
