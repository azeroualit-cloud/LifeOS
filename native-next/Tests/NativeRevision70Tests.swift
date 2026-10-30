import XCTest
@testable import LifeOSProbe

@MainActor final class NativeRevision70Tests: XCTestCase {
    private func moment(_ day: String, _ hour: Int, _ minute: Int = 0) -> Date {
        CivilDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: CivilDate.date(day))!
    }
    func testProgressIsProportionalAndNightDSTHasPartialLastSlot() throws {
        let start = moment("2026-10-24",22), now = moment("2026-10-25",5)
        let focus = NativeDashboardFocus(now: now, todayShift: .rest, previousShift: .night)
        let interval = try XCTUnwrap(focus.workInterval)
        XCTAssertEqual(interval.start,start);XCTAssertEqual(interval.duration,9*3600)
        let slots = NativeShiftProgress.slots(interval: interval, now: now)
        XCTAssertEqual(slots.map(\.duration),[7200,7200,7200,7200,3600])
        XCTAssertEqual(slots.last?.fraction,0)
        XCTAssertEqual(NativeShiftProgress.latestCompleted(interval:interval,now:now),3)
        XCTAssertNil(NativeShiftProgress.latestCompleted(interval:interval,now:interval.end))
    }
    func testBurstIsConsumedOnlyOnActivationAndPersistsAcrossLaunches() throws {
        let suite = "lifeos-burst-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let start = moment("2026-10-30",6), interval = DateInterval(start:start,duration:8*3600)
        let ledger = NativeShiftBurstLedger(defaults:defaults)
        let first = start.addingTimeInterval(4*3600+60)
        XCTAssertEqual(ledger.claim(interval:interval,activation:first,now:first),1)
        XCTAssertNil(ledger.claim(interval:interval,activation:first,now:first.addingTimeInterval(5)))
        let later = first.addingTimeInterval(60)
        XCTAssertNil(NativeShiftBurstLedger(defaults:defaults).claim(interval:interval,activation:later,now:later))
        let next = start.addingTimeInterval(6*3600+60)
        XCTAssertEqual(ledger.claim(interval:interval,activation:next,now:next),2)
        let stale = start.addingTimeInterval(2*3600+60)
        XCTAssertNil(ledger.claim(interval:interval,activation:stale,now:stale.addingTimeInterval(60)))
    }
    func testCalendarDefaultsToTodayButKeepsExplicitNavigationDayOnce() {
        let router = NativeRouter()
        router.calendarDay = "2026-09-15"
        XCTAssertEqual(router.enterCalendar(today:"2026-10-30"),"2026-10-30")
        router.showCalendar(day:"2026-11-02")
        XCTAssertEqual(router.enterCalendar(today:"2026-10-30"),"2026-11-02")
        router.tab = .dashboard;router.tab = .calendar
        XCTAssertEqual(router.enterCalendar(today:"2026-10-30"),"2026-10-30")
        router.showCalendar(day:"2026-12-01")
        XCTAssertNil(router.requestedCalendarDay,"Same-tab navigation does not leave an old request for the next entry")
    }
    func testMovementOrderUsesCreationNotAccountingDayWithStableLegacyFallback() {
        let rows:[Record] = [
            ["row":.int(1),"date":.string("2026-10-30")],
            ["row":.int(2),"date":.string("2026-09-01")],
            ["row":.int(3),"date":.string("2026-08-01"),"created_at":.string("2026-10-30T11:00:00.000Z")],
            ["row":.int(4),"date":.string("2026-10-30"),"created_at":.string("2026-10-30T10:00:00.000Z")]
        ]
        XCTAssertEqual(NativeMovementOrder.sorted(rows).map{$0.integer("row")},[3,4,2,1])
    }
    func testWidgetProjectionHasNoPrivateArchiveFieldsAndRespectsRoutinesAndOccurrences() throws {
        let now = moment("2026-10-30",12), today = CivilDate.day(now)
        let life:Record = ["today":.string(today),"password":.string("fixture-private-password"),"health":.array([.object(["weight":.int(80)])]),
            "routines":.array([.object(["id":.int(1),"title":.string("Habit"),"checked":.bool(true)])]),
            "tasks":.array([.object(["id":.int(2),"title":.string("Task"),"notes":.string("fixture-private-note"),"status":.string("todo"),"list_kind":.string("action")])]),
            "events":.array([.object(["id":.int(4),"title":.string("Event"),"day":.string(today),"frequency":.string("weekly")])]),
            "occurrences":.object(["4:"+today:.string("done")]),
            "shifts":.array([.object(["day":.string(today),"kind":.string("morning")])])]
        let value = NativeWidgetBridge.snapshot(life:life,demo:true,now:now)
        XCTAssertEqual(value.days.count,14);XCTAssertEqual(value.days[0].shift,"morning")
        XCTAssertEqual(value.days[0].checked,1);XCTAssertEqual(value.days[1].checked,0)
        XCTAssertEqual(value.days[0].tasks,1);XCTAssertEqual(value.days[0].events,0)
        XCTAssertEqual(value.days[7].events,1)
        let encoded = String(decoding:try JSONEncoder().encode(value),as:UTF8.self)
        for text in ["fixture-private-password","fixture-private-note","health","password"] { XCTAssertFalse(encoded.contains(text)) }
        XCTAssertEqual(value.week(at:now).count,7)
    }
    func testWidgetAtomicSnapshotReadRolloverAndCorruptionNeverInventData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let now = moment("2026-10-30",12)
        let snapshot = NativeWidgetBridge.snapshot(life:DemoData.make().life,demo:true,now:now)
        try LifeOSWidgetStorage.write(snapshot,directory:folder)
        XCTAssertEqual(LifeOSWidgetStorage.read(directory:folder,now:now),snapshot)
        XCTAssertTrue(snapshot.isStale(at:now.addingTimeInterval(7*3600)))
        let tomorrow = CivilDate.calendar.date(byAdding:.day,value:1,to:now)!
        XCTAssertEqual(snapshot.week(at:tomorrow).first?.day,"2026-10-31")
        XCTAssertTrue(LifeOSWidgetStorage.timelineDates(now:now,snapshot:snapshot).contains(CivilDate.date("2026-10-31")))
        try Data("broken".utf8).write(to:folder.appendingPathComponent(LifeOSWidgetStorage.filename))
        XCTAssertNil(LifeOSWidgetStorage.read(directory:folder,now:now));XCTAssertNil(LifeOSWidgetStorage.read(directory:nil,now:now))
    }
    func testOpeningOfflineDoesNotRefreshOldWidgetSourceTime() {
        let now = moment("2026-10-30",12), old = moment("2026-10-28",12)
        let life:Record = ["today":.string("2026-10-28"),"upcomingEvents":.array([]),"routines":.array([])]
        let snapshot = NativeWidgetBridge.snapshot(life:life,demo:false,updatedAt:old,now:now)
        XCTAssertEqual(snapshot.generatedAt,now);XCTAssertEqual(snapshot.updatedAt,old)
        XCTAssertTrue(snapshot.isStale(at:now))
        let unknown = NativeWidgetBridge.snapshot(life:life,demo:false,now:now)
        XCTAssertTrue(unknown.isStale(at:now))
    }

}
