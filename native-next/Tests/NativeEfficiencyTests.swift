import XCTest
@testable import LifeOSProbe

/// PERF-EFFICIENCY-01: cached projections must return what the uncached
/// expressions returned, before and after every archive change.
@MainActor final class NativeEfficiencyTests: XCTestCase {
    private func makeStore() -> NativeStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("efficiency-" + UUID().uuidString)
        return NativeStore(directory: directory, migrateLegacy: false, automaticallySyncsWrites: false)
    }
    private func linearShift(_ store: NativeStore, _ day: String) -> ShiftKind? {
        store.life.records("shifts").first { $0.text("day") == day }.flatMap { ShiftKind(rawValue: $0.text("kind")) }
    }
    private func sortedCategories(_ store: NativeStore) -> [Record] {
        store.life.records("categories").sorted { $0.amount("position") < $1.amount("position") }
    }

    func testCachedShiftLookupMatchesLinearSearchAfterArchiveChanges() {
        let store = makeStore()
        let today = CivilDate.day()
        let days = (-14...45).map { CivilDate.adding($0, to: today) }
        for day in days { XCTAssertEqual(store.shift(day), linearShift(store, day), day) }
        store.seedVisualCompactCalendar()
        XCTAssertTrue(days.contains { store.shift($0) != nil })
        for day in days { XCTAssertEqual(store.shift(day), linearShift(store, day), day) }
        store.seedVisualHome(empty: true)
        for day in days { XCTAssertNil(store.shift(day), day) }
    }

    func testCachedTasksAndCategoriesFollowTheArchive() {
        let store = makeStore()
        XCTAssertEqual(store.tasks, store.life.records("tasks"))
        XCTAssertEqual(store.categories, sortedCategories(store))
        store.seedVisualTasks()
        XCTAssertEqual(store.tasks.count, 60)
        XCTAssertEqual(store.tasks, store.life.records("tasks"))
        XCTAssertEqual(store.categories, sortedCategories(store))
        store.seedVisualHome(empty: true)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testCatalogPartitionKeepsThePickerOrder() {
        let catalog = NativeGenericFood.catalog
        XCTAssertEqual(NativeFoodPicker.items(in: .all, personal: []).map(\.id), catalog.filter { $0.family != .supplement }.map(\.id))
        XCTAssertEqual(NativeFoodPicker.items(in: .supplements, personal: []).map(\.id), catalog.filter { $0.family == .supplement }.map(\.id))
        XCTAssertEqual(NativeGenericFood.catalogFoods.count + NativeGenericFood.catalogSupplements.count, catalog.count)
    }

    func testRankingWithoutRecentUseKeepsTheOriginalOrder() {
        let foods = Array(NativeGenericFood.catalog.prefix(80))
        XCTAssertEqual(NativeGenericFood.ranked(foods, entries: []).map(\.id), foods.map(\.id))
    }

    func testFoodSearchTime() {
        let foods = NativeFoodPicker.items(in: .all, personal: [])
        XCTAssertFalse(NativeGenericFood.matches("pollo", in: foods).isEmpty)
        measure { _ = NativeGenericFood.matches("pollo", in: foods) }
    }

    func testShiftLookupTime() {
        let store = makeStore()
        store.seedVisualCompactCalendar()
        let today = CivilDate.day()
        let days = (-21...21).map { CivilDate.adding($0, to: today) }
        measure { for _ in 0..<50 { for day in days { _ = store.shift(day) } } }
    }
}
