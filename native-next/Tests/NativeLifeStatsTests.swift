import XCTest
@testable import LifeOSProbe

final class NativeLifeStatsTests: XCTestCase {
    private let days = (1...8).map { "2026-10-0" + String($0) }

    func testGroupsAverageByKindOfDay() {
        let shifts = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1, $0 < 4 ? "night" : "rest") })
        let groups = NativeLifeStats.groups(days: days, shifts: shifts, privateDays: ["2026-10-05": 1, "2026-10-06": 2],
                                            spend: ["2026-10-01": 40, "2026-10-05": 8], kcal: ["2026-10-01": 2400, "2026-10-02": 2600])
        XCTAssertEqual(groups.map(\.kind), ["night", "rest"])
        XCTAssertEqual(groups[0].spend, 10)          // 40 over four days, days without spending count as zero
        XCTAssertEqual(groups[0].kcal, 2500)          // only the days with a diary
        XCTAssertNil(groups[1].kcal)
        XCTAssertEqual(groups[1].privateCount, 3)
        XCTAssertEqual(groups[1].privateRate, 0.75)
    }

    func testDaysWithoutShiftAreGrouped() {
        let groups = NativeLifeStats.groups(days: days, shifts: ["2026-10-01": "morning"], privateDays: [:], spend: [:], kcal: [:])
        XCTAssertEqual(groups.map(\.kind), ["morning", "none"])
        XCTAssertEqual(groups[1].days, 7)
    }

    func testInsightsOnlyForClearDifferencesAndPrivateOnlyWhenUnlocked() {
        let shifts = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1, $0 < 4 ? "night" : "rest") })
        let spend = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1, $0 < 4 ? 30.0 : 10.0) })
        let privateDays = ["2026-10-05": 1, "2026-10-06": 1, "2026-10-07": 1]
        let groups = NativeLifeStats.groups(days: days, shifts: shifts, privateDays: privateDays, spend: spend, kcal: [:])
        let locked = NativeLifeStats.insights(groups, includePrivate: false, hideMoney: false)
        XCTAssertEqual(locked.count, 1)
        XCTAssertTrue(locked[0].contains("Notte"))
        let open = NativeLifeStats.insights(groups, includePrivate: true, hideMoney: true)
        XCTAssertEqual(open.count, 2)
        XCTAssertTrue(open[0].contains("••••"))
        XCTAssertTrue(open[1].contains("Riposo"))
        let flat = NativeLifeStats.groups(days: days, shifts: shifts, privateDays: [:], spend: Dictionary(uniqueKeysWithValues: days.map { ($0, 10.0) }), kcal: [:])
        XCTAssertTrue(NativeLifeStats.insights(flat, includePrivate: true, hideMoney: false).isEmpty)
    }

    func testCountUsesSingularAndPlural() {
        XCTAssertEqual(NativeLifeStats.count(1, "incontro", "incontri"), "1 incontro")
        XCTAssertEqual(NativeLifeStats.count(0, "incontro", "incontri"), "0 incontri")
        XCTAssertEqual(NativeLifeStats.count(3, "giorno", "giorni"), "3 giorni")
    }

    func testDaysStopAtToday() {
        XCTAssertEqual(NativeLifeStats.days(months: ["2026-11"], today: "2026-11-03"), ["2026-11-01", "2026-11-02", "2026-11-03"])
        XCTAssertEqual(NativeLifeStats.days(months: ["2026-02"], today: "2026-12-01").count, 28)
    }
}
