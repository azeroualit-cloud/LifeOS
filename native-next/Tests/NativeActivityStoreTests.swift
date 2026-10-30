import Foundation
import XCTest
@testable import LifeOSProbe

@MainActor final class NativeActivityStoreTests: XCTestCase {
    func testOperationalEventsIgnoreCalendarFocusAndRolloverWithoutRoutines() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let today = CivilDate.day()
        var archive = NativeArchive()
        archive.demo = false; archive.routineDay = today
        archive.life = ["today": .string(today), "routines": .array([]), "events": .array([]), "activityEvents": .array([
            .object(["id": .int(1), "day": .string(today)]),
            .object(["id": .int(1), "day": .string(CivilDate.adding(7,to:today))])
        ])]
        try JSONEncoder().encode(archive).write(to: directory.appendingPathComponent("lifeos-native-v2.json"))
        let store = NativeStore(directory: directory, migrateLegacy: false, automaticallySyncsWrites: false)
        store.calendarMonth = "2099-10"
        XCTAssertEqual(store.activityEvents.count,2)
        let tomorrow = CivilDate.adding(1,to:today)
        store.rollover(today:tomorrow)
        XCTAssertEqual(store.life.text("today"),tomorrow)
        XCTAssertEqual(store.state.routineDay,tomorrow)
        XCTAssertTrue(store.routines.isEmpty)
        XCTAssertEqual(store.activityEvents.count,2,"The source occurrences remain stored as the visible window changes")
    }
    func testDashboardCompletionPersistsOfflineAndOnlyCompletesSelectedDay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let today = CivilDate.day(), tomorrow = CivilDate.adding(1, to: CivilDate.day())
        let rows: [JSONValue] = [today, tomorrow].map { .object(["id": .int(42), "day": .string($0), "title": .string("Ricorrente"), "occurrence_status": .string("open")]) }
        var archive = NativeArchive()
        archive.demo = false; archive.routineDay = today; archive.endpoint = "https://example.invalid"
        archive.life = ["today": .string(today), "events": .array(rows), "upcomingEvents": .array(rows), "activityEvents": .array(rows)]
        try JSONEncoder().encode(archive).write(to: directory.appendingPathComponent("lifeos-native-v2.json"))
        let store = NativeStore(directory: directory, migrateLegacy: false, automaticallySyncsWrites: false)
        try await store.perform("setEventOccurrence", ["id": .int(42), "day": .string(today), "status": .string("done")])
        XCTAssertEqual(store.state.pending.count, 1)
        XCTAssertEqual(store.dashboardEvents.first { $0.text("day") == today }?.text("occurrence_status"), "done")
        XCTAssertEqual(store.dashboardEvents.first { $0.text("day") == tomorrow }?.text("occurrence_status"), "open")
        let reopened = NativeStore(directory: directory, migrateLegacy: false, automaticallySyncsWrites: false)
        XCTAssertEqual(reopened.state.pending.count, 1)
        XCTAssertEqual(reopened.dashboardEvents.first { $0.text("day") == today }?.text("occurrence_status"), "done")
        try await reopened.perform("setEventOccurrence", ["id": .int(42), "day": .string(today), "status": .string("open")])
        XCTAssertEqual(reopened.dashboardEvents.first { $0.text("day") == today }?.text("occurrence_status"), "open")
    }

}
