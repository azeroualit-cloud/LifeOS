import XCTest
@testable import LifeOSProbe

final class NativeTaskListTests: XCTestCase {
    private func row(_ id: Int, status: String, section: String = "todo", order: Int = 0, category: String = "shopping") -> Record {
        ["id": .int(id), "status": .string(status), "section_status": .string(section), "sort_order": .int(order), "list_kind": .string(category), "title": .string("Articolo \(id)")]
    }
    func testCompletedItemsRemainAtBottomOfTheirOwnSection() {
        let tasks = [row(1, status: "done", order: 0), row(2, status: "todo", order: 5), row(3, status: "done", section: "waiting"), row(4, status: "waiting"), row(5, status: "todo", category: "action")]
        XCTAssertEqual(NativeTaskList.rows(tasks, category: "shopping", section: "todo").map { $0.integer("id") }, [2, 1])
        XCTAssertEqual(NativeTaskList.rows(tasks, category: "shopping", section: "waiting").map { $0.integer("id") }, [4, 3])
        XCTAssertEqual(NativeTaskList.completionStatus(tasks[2]), "waiting")
        XCTAssertEqual(NativeTaskList.completionStatus(tasks[0]), "todo")
    }
    func testLegacyCompletionsRemainVisibleAndOrderingIsDeterministic() {
        var legacy = row(1, status: "done"); legacy.removeValue(forKey: "section_status")
        XCTAssertEqual(NativeTaskList.section(legacy), "todo")
        XCTAssertEqual(NativeTaskList.rows([row(3, status: "todo"), legacy, row(2, status: "todo")], category: "shopping", section: "todo").map { $0.integer("id") }, [2, 3, 1])
    }
    func testWaitingCompletionSurvivesEditingAndArchiveRoundTrip() throws {
        var state = DemoData.make()
        state.life["tasks"] = .array([.object(row(1, status: "waiting"))])
        try DemoActions.apply("setTaskStatus", ["id": .int(1), "status": .string("done")], args: nil, state: &state)
        try DemoActions.apply("saveTask", ["id": .int(1), "title": .string("Pasta"), "list_kind": .string("shopping")], args: nil, state: &state)
        let restored = try JSONDecoder().decode(NativeArchive.self, from: JSONEncoder().encode(state))
        let task = try XCTUnwrap(restored.life.records("tasks").first)
        XCTAssertEqual(task.text("status"), "done")
        XCTAssertEqual(NativeTaskList.section(task), "waiting")
        var reopened = restored
        try DemoActions.apply("setTaskStatus", ["id": .int(1), "status": .string(NativeTaskList.completionStatus(task))], args: nil, state: &reopened)
        XCTAssertEqual(reopened.life.records("tasks").first?.text("status"), "waiting")
        XCTAssertEqual(reopened.life.records("tasks").count, 1)
    }
    func testMonthWindowCrossesYearAndLeapBoundariesWithoutGaps() {
        XCTAssertEqual(NativeCalendarWindow.months(around: "2026-01", radius: 1), ["2025-12", "2026-01", "2026-02"])
        XCTAssertEqual(NativeCalendarWindow.offset("2024-02", by: 1), "2024-03")
        let initial = NativeCalendarWindow.months(around: "2026-10")
        let extended = Array(Set(initial + NativeCalendarWindow.months(around: initial[0]))).sorted()
        XCTAssertEqual(extended.filter { initial.contains($0) }, initial)
        XCTAssertEqual(Set(extended).count, extended.count)
        for pair in zip(extended, extended.dropFirst()) { XCTAssertEqual(NativeCalendarWindow.offset(pair.0, by: 1), pair.1) }
    }
}
