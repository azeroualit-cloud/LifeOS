import XCTest
@testable import LifeOSProbe

@MainActor final class NativeHub95Tests: XCTestCase {
    private func context(remaining: Double? = 40, tomorrowEvents: [String] = []) -> NativeHubContext {
        let tomorrow = CivilDate.adding(1, to: "2026-11-23")
        return NativeHubContext(remaining: remaining, daily: 8, daysLeft: 5, categorySpend: ["Spesa": 320], weekSpend: 95,
                                eventsByDay: [tomorrow: tomorrowEvents], shiftByDay: [tomorrow: "Mattina"],
                                intake: ["protein": 40], goals: ["protein": 150])
    }
    private func now() -> Date { NativeHubPlan.moment("2026-11-23", "07:00")! }

    func testRulesFireOnlyWhenTheirCriteriaHold() {
        let doc: Record = ["rules": .array([
            .object(["id": .string("b"), "type": .string("budgetBelow"), "name": .string("Budget"), "time": .string("09:00"), "params": .object(["amount": .number(50)])]),
            .object(["id": .string("c"), "type": .string("categoryOver"), "time": .string("10:00"), "params": .object(["category": .string("Spesa"), "amount": .number(400)])]),
            .object(["id": .string("e"), "type": .string("eventTomorrow"), "time": .string("20:00")]),
            .object(["id": .string("s"), "type": .string("shiftTomorrow"), "time": .string("21:00")]),
            .object(["id": .string("off"), "type": .string("weeklySummary"), "time": .string("11:00"), "enabled": .bool(false)]),
        ])]
        let items = NativeHubPlan.make(doc: doc, now: now(), context: context(), days: 1)
        XCTAssertEqual(items.map(\.rule), ["b", "s"], "category under threshold, no events and disabled rule stay silent")
        XCTAssertTrue(items[0].body.contains("5 giorni"))
        XCTAssertEqual(items[1].body, "Domani: Mattina.")
    }

    func testQuietHoursMaxPerDayAndWeekdays() {
        XCTAssertTrue(NativeHubPlan.inQuiet("23:30", from: "22:00", to: "07:00"))
        XCTAssertTrue(NativeHubPlan.inQuiet("06:59", from: "22:00", to: "07:00"))
        XCTAssertFalse(NativeHubPlan.inQuiet("07:00", from: "22:00", to: "07:00"))
        let rule = { (id: String, time: String) -> JSONValue in .object(["id": .string(id), "type": .string("custom"), "time": .string(time), "params": .object(["body": .string("x")])]) }
        let doc: Record = ["maxPerDay": .number(2), "quiet": .object(["from": .string("22:00"), "to": .string("07:00")]),
                           "rules": .array([rule("a", "08:00"), rule("b", "09:00"), rule("c", "10:00"), rule("q", "23:00")])]
        XCTAssertEqual(NativeHubPlan.make(doc: doc, now: now(), context: context(), days: 1).map(\.rule), ["a", "b"])
        // 2026-11-23 is a Monday (1); a rule limited to Sunday (7) does not fire.
        XCTAssertTrue(NativeHubPlan.weekdayAllowed(["days": .array([.number(1)])], day: "2026-11-23"))
        XCTAssertFalse(NativeHubPlan.weekdayAllowed(["days": .array([.number(7)])], day: "2026-11-23"))
    }

    func testDeliveryChosenOnTheSiteTravelsWithEachAlert() {
        let doc: Record = ["rules": .array([
            .object(["id": .string("a"), "type": .string("custom"), "time": .string("08:00"), "delivery": .string("quiet"), "params": .object(["body": .string("x")])]),
            .object(["id": .string("b"), "type": .string("custom"), "time": .string("09:00"), "params": .object(["body": .string("y")])]),
        ])]
        XCTAssertEqual(NativeHubPlan.make(doc: doc, now: now(), context: context(), days: 1).map(\.delivery), ["quiet", "sound"], "no choice keeps the sound")
    }

    func testPrayerNotificationsOnlyForChosenPrayersAndInAdvance() {
        let doc: Record = ["prayer": .object(["enabled": .bool(true), "before": .number(10),
                                              "prayers": .object(["dhuhr": .bool(true), "maghrib": .bool(true), "fajr": .bool(false)])])]
        let items = NativeHubPlan.make(doc: doc, now: now(), context: context(), days: 1)
        XCTAssertEqual(items.map(\.title), ["Dhuhr", "Maghrib"])
        let dhuhr = SolarTimes.calculate("2026-11-23")[2].1
        XCTAssertEqual(items[0].date, NativeHubPlan.moment("2026-11-23", dhuhr)!.addingTimeInterval(-600))
        XCTAssertTrue(items[0].body.contains("tra 10 minuti"))
    }

    func testGoalsFromTheSiteKeepUnknownFieldsAndFallBack() {
        var base = NativeNutritionGoals(); base.protein = 2.0
        XCTAssertNil(NativeHub95.goals(from: [:], base: base))
        let goals = NativeHub95.goals(from: ["calorieMode": .string("fixed"), "fixedCalories": .number(2200), "fibre": .number(30)], base: base)
        XCTAssertEqual(goals?.calorieMode, .fixed)
        XCTAssertEqual(goals?.fixedCalories, 2200)
        XCTAssertEqual(goals?.protein, 2.0)
        XCTAssertEqual(NativeHub95.record(goals!)["fixedCalories"], .number(2200))
    }
}
