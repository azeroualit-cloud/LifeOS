import XCTest
@testable import LifeOSProbe

/// FOOD-QUICK-ADD-2026-11-23: quick quantity and «Ripeti da ieri».
@MainActor final class NativeFoodQuickAddTests: XCTestCase {
    func testRepeatedEntryIsANewEntryOnTheTargetDayAtTheSameTime() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 8, minute: 30))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 19, minute: 5))!
        let entry = NativeNutritionEntry(id: UUID(), revision: 3, date: yesterday, protein: 20, carbohydrate: 30, fat: 5, confirmed: true, foodName: "Avena")
        let past = entry.repeated(on: calendar.date(from: DateComponents(year: 2026, month: 11, day: 21))!, now: now, calendar: calendar)
        XCTAssertNotEqual(past.id, entry.id); XCTAssertEqual(past.revision, 0); XCTAssertFalse(past.confirmed)
        XCTAssertEqual(calendar.dateComponents([.day, .hour, .minute], from: past.date), DateComponents(day: 21, hour: 8, minute: 30))
        XCTAssertEqual(entry.repeated(on: now, now: now, calendar: calendar).date, now, "today: the time of the copy")
        XCTAssertEqual(past.protein, 20); XCTAssertEqual(past.foodName, "Avena")
    }
}
