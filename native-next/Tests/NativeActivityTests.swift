import XCTest
@testable import LifeOSProbe

final class NativeActivityTests: XCTestCase {
    private var draft: Record { ["uid": .string("task:7"), "source": .string("task"), "sourceId": .int(7), "localID": .int(-1), "title": .string("Attività unica"), "notes": .string("Descrizione"), "frequency": .string("none"), "list_kind": .string("action")] }
    func testLocalDateConversionHasOneIdentityAndNoDuplicate() throws {
        var life: Record = ["tasks": .array([.object(["id": .int(7), "title": .string("Prima"), "status": .string("todo")])])]
        var p = draft; p["day"] = .string("2026-11-01")
        try NativeLocalActivity.apply(p, life: &life)
        XCTAssertTrue(life.records("tasks").isEmpty)
        XCTAssertEqual(life.records("events").count, 1)
        XCTAssertEqual(life.records("events").first?.text("activity_uid"), "task:7")
        p["day"] = .null
        try NativeLocalActivity.apply(p, life: &life)
        XCTAssertTrue(life.records("events").isEmpty)
        XCTAssertEqual(life.records("tasks").count, 1)
        XCTAssertEqual(life.records("tasks").first?.text("notes"), "Descrizione")
    }
    func testPendingReplaysAreIdempotentAndEditsShareOneQueueKey() throws {
        var life = DemoData.emptyLife(), p = draft
        try NativeLocalActivity.apply(p, life: &life)
        p["title"] = .string("Modificata offline")
        try NativeLocalActivity.apply(p, life: &life)
        XCTAssertEqual(life.records("tasks").count, 1)
        XCTAssertEqual(life.records("tasks").first?.text("title"), "Modificata offline")
        let a = PendingWrite(id: "a", method: "saveActivity", payload: draft)
        let b = PendingWrite(id: "b", method: "saveActivity", payload: p)
        XCTAssertEqual(LocalLifeMutation.key(a), LocalLifeMutation.key(b))
        XCTAssertEqual(NativeSyncPolicy.scope(for: "saveActivity"), .life)
    }
    func testDatedActivityKeepsItsOriginalCategoryAndStableIdentity() {
        let day = CivilDate.day()
        let event: Record = ["id": .int(5), "activity_uid": .string("task:7"), "day": .string(day), "list_kind": .string("books"), "occurrence_status": .string("open")]
        let rows = NativeActivityCatalog.rows(tasks: [], events: [event], category: "books", section: "todo", today: day)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, "task:7:" + day)
        XCTAssertTrue(NativeActivityCatalog.rows(tasks: [], events: [event], category: "action", section: "todo", today: day).isEmpty)
    }
    func testPendingCompletionReplacesLocalStateAndPreservesIdentity() throws {
        var life = DemoData.emptyLife(), p = draft
        try NativeLocalActivity.apply(p, life: &life)
        p["sourceId"] = .int(0); p["statusIntent"] = .bool(true); p["taskStatus"] = .string("done"); p["completed"] = .bool(true)
        try NativeLocalActivity.apply(p, life: &life)
        XCTAssertEqual(life.records("tasks").count, 1)
        XCTAssertEqual(life.records("tasks").first?.text("status"), "done")
        XCTAssertEqual(life.records("tasks").first?.text("activity_uid"), "task:7")
    }
    func testInvalidDatesAndEndTimesAreRejectedBeforeEnqueueing() {
        var p = draft
        p["day"] = .string("2026-02-30")
        XCTAssertThrowsError(try NativeActivityDraft.validate(p))
        p["day"] = .string("2026-11-02"); p["due_date"] = .string("2026-11-01")
        XCTAssertThrowsError(try NativeActivityDraft.validate(p))
        p["due_date"] = .null; p["start_time"] = .string("10:00"); p["end_time"] = .string("09:00")
        XCTAssertThrowsError(try NativeActivityDraft.validate(p))
    }
}
