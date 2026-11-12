import XCTest
@testable import LifeOSProbe

@MainActor final class NativeNutritionHistoryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func entry(_ day: Int, hour: Int = 12, name: String? = "Alimento") -> NativeNutritionEntry {
        var entry = NativeNutritionEntry(id: UUID(), revision: 1, date: date(day, hour: hour), protein: 10, carbohydrate: 20, fat: 5, confirmed: true)
        entry.foodName = name
        return entry
    }

    func testHistoryGroupsAllStatesByCivilDayAcrossDaylightSavingAndKeepsNewestFirst() {
        let morning = entry(25, hour: 1)
        let evening = entry(25, hour: 23)
        var pending = entry(24, name: nil)
        pending.confirmed = false
        var deleting = entry(26)
        deleting.deletionPending = true
        let groups = NativeNutritionHistory.days([morning, deleting, pending, evening], calendar: calendar)
        XCTAssertEqual(groups.map(\.date), [26, 25, 24].map { calendar.startOfDay(for: date($0)) })
        XCTAssertEqual(groups.flatMap(\.entries).map(\.id), [deleting.id, evening.id, morning.id, pending.id])
        XCTAssertFalse(groups[2].entries[0].confirmed, "Grouping must preserve pending retries and unnamed macro entries")
    }

    func testPreviewContainsOnlyNamedFoodsOnSelectedDayAndKeepsDeletionRetry() {
        let selected = entry(25)
        let otherDay = entry(24)
        let macro = entry(25, name: nil)
        let blank = entry(25, name: " \n ")
        var incomplete = entry(25)
        incomplete.confirmed = false
        var deleting = entry(25, hour: 18)
        deleting.deletionPending = true
        let rows = NativeNutritionHistory.foods(on: date(25), entries: [selected, otherDay, macro, blank, incomplete, deleting], calendar: calendar)
        XCTAssertEqual(rows.map(\.id), [deleting.id, selected.id])
        XCTAssertEqual(rows.first?.deletionPending, true)
    }

    func testPreviewDeletionFailureSurvivesRestartThenDisappearsOnlyAfterSuccessfulRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = HistoryDeletionWriter()
        let store = NativeNutritionStore(directory: directory, writer: writer)
        let food = entry(25)
        let saved = await store.save(food)
        XCTAssertTrue(saved)
        writer.failDeletion = true
        let firstDeletion = await store.delete(food.id)
        XCTAssertFalse(firstDeletion)
        XCTAssertNotNil(store.error)
        let restarted = NativeNutritionStore(directory: directory, writer: writer)
        let pending = NativeNutritionHistory.foods(on: date(25), entries: restarted.entries, calendar: calendar)
        XCTAssertEqual(pending.map(\.id), [food.id])
        XCTAssertEqual(pending.first?.deletionPending, true)
        writer.failDeletion = false
        let retried = await restarted.delete(food.id)
        XCTAssertTrue(retried)
        XCTAssertTrue(NativeNutritionHistory.foods(on: date(25), entries: restarted.entries, calendar: calendar).isEmpty)
        XCTAssertTrue(NativeNutritionStore(directory: directory, writer: writer).entries.isEmpty)
        XCTAssertEqual(writer.deletedIDs, [food.id, food.id])
    }
}

@MainActor private final class HistoryDeletionWriter: NativeNutritionWriting {
    var failDeletion = false
    var deletedIDs: [UUID] = []
    func authorize(includeFibre: Bool) async throws {}
    func write(_ entry: NativeNutritionEntry) async throws {}
    func delete(_ entry: NativeNutritionEntry) async throws {
        deletedIDs.append(entry.id)
        if failDeletion { throw Message(text: "Eliminazione interrotta") }
    }
}
