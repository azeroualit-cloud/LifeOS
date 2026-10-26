import XCTest
@testable import LifeOSProbe
final class NativeActivityCatalogTests: XCTestCase {
    private let today = "2026-10-31"
    private func event(_ id: Int, _ offset: Int, status: String = "open") -> Record {
        ["id": .int(id), "day": .string(CivilDate.adding(offset, to: today)), "title": .string("Event"), "occurrence_status": .string(status)]
    }
    func testRollingWeekSeparatesActiveAndWaitingEvents() {
        let task: Record = ["id": .int(1), "list_kind": .string("action"), "status": .string("todo")]
        let events = [event(7,7), event(8,8), event(2,1), event(3,2), event(1,0), event(4,-1), event(5,0,status:"done"), event(6,1,status:"skipped"), event(1,0)]
        let rows = NativeActivityCatalog.rows(tasks:[task],events:events,category:"action",section:"todo",today:today)
        XCTAssertEqual(rows.map(\.id),["event:1:2026-10-31","event:2:2026-11-01","task:1"])
        XCTAssertEqual(NativeActivityCatalog.rows(tasks:[],events:events,category:"action",section:"waiting",today:today).map(\.id),["event:3:2026-11-02","event:7:2026-11-07"])
        XCTAssertTrue(NativeActivityCatalog.rows(tasks:[],events:events,category:"wish",section:"todo",today:today).isEmpty)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks:[],events:events,category:"action",section:"done",today:today).isEmpty)
    }
    func testScheduledTasksWaitUntilTheirDayAndArchivedTasksRemainRecoverable() {
        let task: Record = ["id":.int(1),"list_kind":.string("action"),"status":.string("waiting"),"scheduled_date":.string("2026-11-01")]
        XCTAssertTrue(NativeTaskList.rows([task],category:"action",section:"waiting",today:today).isEmpty)
        XCTAssertEqual(NativeTaskList.rows([task],category:"action",section:"waiting",today:"2026-11-01").count,1)
        var completed=task; completed["status"] = .string("done"); completed["section_status"] = .string("waiting")
        XCTAssertEqual(NativeTaskList.rows([completed],category:"action",section:"done",today:today).count,1)
        XCTAssertEqual(NativeTaskList.completionStatus(completed),"waiting")
    }
    func testPastEventsAppearConcludedWithoutChangingOriginalOrSeries() {
        let past=event(1,-1); let concluded=NativeActivityCatalog.calendarRecord(past,today:today)
        XCTAssertEqual(concluded.text("occurrence_status"),"done")
        XCTAssertEqual(past.text("occurrence_status"),"open")
        XCTAssertEqual(NativeActivityCatalog.calendarRecord(event(1,1),today:today).text("occurrence_status"),"open")
        XCTAssertEqual(NativeActivityCatalog.calendarRecord(event(2,-1,status:"skipped"),today:today).text("occurrence_status"),"skipped")
    }
    func testRolloverPromotesFutureEventAndRemovesYesterdayWithoutDuplicates() {
        let e=event(4,2)
        XCTAssertEqual(NativeActivityCatalog.rows(tasks:[],events:[e,e],category:"action",section:"waiting",today:today).count,1)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks:[],events:[e],category:"action",section:"todo",today:today).isEmpty)
        XCTAssertEqual(NativeActivityCatalog.rows(tasks:[],events:[e,e],category:"action",section:"todo",today:"2026-11-01").count,1)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks:[],events:[e],category:"action",section:"waiting",today:"2026-11-01").isEmpty)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks:[],events:[e],category:"action",section:"todo",today:"2026-11-03").isEmpty)
    }
    func testReorderIncludesHiddenScheduledTasksAndExcludesWaitingAndArchive() {
        let rows: [Record] = [(1,"todo"),(2,"todo"),(3,"todo"),(4,"waiting"),(5,"done")].map { id,status in
            ["id":.int(id),"status":.string(status),"list_kind":.string("action"),"sort_order":.int(id)]
        }
        XCTAssertEqual(NativeTaskList.reorderIDs(tasks:rows,category:"action",visibleIDs:[3,1]),[3,1,2])
    }
    func testOfflineCompletionUpdatesTheOperationalProjectionAndKeepsNextOccurrence() throws {
        let day = CivilDate.day(), next = CivilDate.adding(7,to:day)
        let current: Record = ["id":.int(1),"day":.string(day)]
        let future: Record = ["id":.int(1),"day":.string(next)]
        var life: Record = ["activityEvents":.array([.object(current),.object(future)])]
        try LocalLifeMutation.apply("setEventOccurrence",["id":.int(1),"day":.string(day),"status":.string("done")],to:&life)
        let rows = NativeActivityCatalog.rows(tasks:[],events:life.records("activityEvents"),category:"action",section:"waiting",today:day)
        XCTAssertEqual(rows.map { $0.record.text("day") },[next])
        try LocalLifeMutation.apply("setEventOccurrence",["id":.int(1),"day":.string(day),"status":.string("open")],to:&life)
        XCTAssertEqual(NativeActivityCatalog.rows(tasks:[],events:life.records("activityEvents"),category:"action",section:"todo",today:day).count,1)
    }
}
