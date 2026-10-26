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
}
