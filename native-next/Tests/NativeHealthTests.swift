import XCTest
@testable import LifeOSProbe

final class NativeHealthTests: XCTestCase {
    func testReleaseNeverSubstitutesHealthDataAndFinancialDemoIsNotAnInput() {
        XCTAssertFalse(NativeHealthLaunchPolicy.usesSimulatedData(debugBuild: false, arguments: []))
        XCTAssertFalse(NativeHealthLaunchPolicy.usesSimulatedData(debugBuild: false, arguments: ["--visual-test"]))
        XCTAssertFalse(NativeHealthLaunchPolicy.usesSimulatedData(debugBuild: true, arguments: []))
        XCTAssertTrue(NativeHealthLaunchPolicy.usesSimulatedData(debugBuild: true, arguments: ["--visual-test"]))
    }
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 17))! }
    private func history(slope: Double = 0) -> [HealthDay] {
        (-35...0).map { offset in
            HealthDay(date: calendar.date(byAdding: .day, value: offset, to: now)!, weight: 80 + slope * Double(offset), calories: 2200)
        }
    }
    func testDashboardJoinsTrendAndForecastWithoutChangingMeasurementsOrScenario() throws {
        let rows = history(slope: 0.03)
        let estimate = HealthEstimate(tdee: 2800, averageIntake: 3000, startWeight: 79.5, lastDate: now, days: 90)
        let chart = NativeHealthDashboardData(days: rows, estimate: estimate, now: now, calendar: calendar)
        let start = try XCTUnwrap(chart.transition.first), end = try XCTUnwrap(chart.transition.last)
        XCTAssertLessThan(start.date, end.date)
        XCTAssertEqual(start.value, chart.trend.first { $0.date == start.date }?.value)
        XCTAssertEqual(end.value, chart.forecast.first?.value)
        XCTAssertEqual(chart.forecast.first?.value, 79.5)
        XCTAssertEqual(chart.days.last?.weight, rows.last?.weight)
    }
    func testDashboardUsesCalendarMonthOnBothSidesOfToday() {
        var rome = calendar; rome.timeZone = TimeZone(identifier: "Europe/Rome")!
        let date = rome.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 12))!
        let chart = NativeHealthDashboardData(days: [], estimate: nil, now: date, calendar: rome)
        XCTAssertEqual(chart.start, rome.date(from: DateComponents(year: 2026, month: 9, day: 17)))
        XCTAssertEqual(chart.end, rome.date(from: DateComponents(year: 2026, month: 11, day: 17)))
        XCTAssertEqual(rome.component(.hour, from: chart.end), 0, "Calendar bounds must survive daylight-saving changes")
    }
    func testForecastUsesCivilDaysAcrossDaylightSavingAndKeepsBaseline() throws {
        var rome = calendar; rome.timeZone = TimeZone(identifier: "Europe/Rome")!
        let baseline = try XCTUnwrap(rome.date(from: DateComponents(year: 2026, month: 3, day: 20)))
        let estimate = HealthEstimate(tdee: 2400, averageIntake: 2600, startWeight: 80, lastDate: baseline, days: 30)
        let points = NativeHealthMath.forecast(estimate, intake: estimate.averageIntake, weeks: 6, calendar: rome)
        XCTAssertEqual(points.first?.value, 80)
        XCTAssertEqual(points[10].date, rome.date(byAdding: .day, value: 10, to: baseline))
        XCTAssertEqual(rome.component(.hour, from: points[10].date), 0)
        XCTAssertGreaterThan(points[10].value, 80)
    }
    func testDashboardKeepsOnlyRecentHistoryAndPreservesMissingCalories() {
        var rows = history()
        rows[20].calories = nil
        rows.append(HealthDay(date: calendar.date(byAdding: .day, value: 1, to: now)!, weight: 90, calories: 9000))
        let chart = NativeHealthDashboardData(days: rows, estimate: nil, now: now, calendar: calendar)
        XCTAssertEqual(chart.days.first?.date, calendar.date(byAdding: .month, value: -1, to: now))
        XCTAssertTrue(chart.days.allSatisfy { $0.date <= now })
        XCTAssertNil(chart.days.first { $0.date == rows[20].date }?.calories)
        XCTAssertTrue(chart.forecast.isEmpty)
    }
    func testDashboardForecastCoversNextMonthEvenWithSevenDayOldBaseline() throws {
        let baseline = calendar.date(byAdding: .day, value: -7, to: now)!
        let estimate = HealthEstimate(tdee: 2800, averageIntake: 3000, startWeight: 83, lastDate: baseline, days: 90)
        let chart = NativeHealthDashboardData(days: history(), estimate: estimate, now: now, calendar: calendar)
        let first = try XCTUnwrap(chart.forecast.first), last = try XCTUnwrap(chart.forecast.last)
        XCTAssertEqual(first.date, now)
        XCTAssertEqual(last.date, chart.end)
        XCTAssertGreaterThan(first.value, 83, "Keep elapsed scenario days; do not reset the old baseline to today")
        XCTAssertGreaterThan(last.value, first.value)
        XCTAssertTrue(chart.forecast.allSatisfy { chart.weightDomain.contains($0.value) })
    }
    func testDashboardDoesNotForecastWithoutCalibrationOrWithStaleBaseline() {
        let stale = HealthEstimate(tdee: 2800, averageIntake: 3000, startWeight: 83,
            lastDate: calendar.date(byAdding: .day, value: -8, to: now)!, days: 90)
        XCTAssertTrue(NativeHealthDashboardData(days: history(), estimate: nil, now: now, calendar: calendar).forecast.isEmpty)
        XCTAssertTrue(NativeHealthDashboardData(days: history(), estimate: stale, now: now, calendar: calendar).forecast.isEmpty)
    }
    func testDashboardIndependentCalorieScalePreservesZeroAndTop() {
        let chart = NativeHealthDashboardData(days: [HealthDay(date: now, weight: 83, calories: 4100)], estimate: nil, now: now, calendar: calendar)
        XCTAssertEqual(chart.calorieCeiling, 5000)
        XCTAssertEqual(chart.plottedCalories(0), chart.weightDomain.lowerBound)
        XCTAssertEqual(chart.plottedCalories(5000), chart.weightDomain.upperBound)
        XCTAssertEqual(chart.plottedCalories(2500), (chart.weightDomain.lowerBound + chart.weightDomain.upperBound) / 2)
        XCTAssertTrue(chart.weightDomain.contains(83))
    }
    func testSelectedWeekStartsMondayAndFutureWeekCannotBeSelected() throws {
        let dates = NativeHealthWeek.days(containing: now)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(NativeHealthWeek.calendar.component(.weekday, from: try XCTUnwrap(dates.first)), 2)
        XCTAssertNil(NativeHealthWeek.moving(now, weeks: 1, now: now))
        XCTAssertNotNil(NativeHealthWeek.moving(now, weeks: -1, now: now))
    }
    func testMaintenanceRecoversRecordedIntake() throws {
        let result = try XCTUnwrap(NativeHealthMath.estimate(history(), now: now, calendar: calendar))
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
        XCTAssertEqual(result.averageIntake, 2200)
    }
    func testLossIncreasesEstimatedExpenditure() throws {
        let result = try XCTUnwrap(NativeHealthMath.estimate(history(slope: -0.04), now: now, calendar: calendar))
        XCTAssertGreaterThan(result.tdee, 2450)
        XCTAssertLessThan(result.tdee, 2550)
    }
    func testSmallCalorieGapIsDisclosedAndNeverBecomesZero() throws {
        var rows = history(); rows[28].calories = nil
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.imputedDays, 1)
        XCTAssertEqual(result.loggedDays, result.days - 1)
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
        XCTAssertGreaterThan(result.missingDaySensitivity, 0)
    }
    func testPoorCalorieCoverageDoesNotProduceTDEE() {
        var rows = history()
        for i in 26...30 { rows[i].calories = nil }
        XCTAssertNil(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
    }
    func testCalibrationUsesFourteenDaysThroughLastWeighInAndScenarioUsesSeven() throws {
        var rows: [HealthDay] = []
        var weight = 76.0
        for offset in -120...0 {
            let calories = offset < -14 ? 2400.0 : offset < -7 ? 2900.0 : 3300.0
            rows.append(HealthDay(date: calendar.date(byAdding: .day, value: offset, to: now)!, weight: weight, calories: calories))
            weight += (calories - 2800) / 7700
        }
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.days, 14)
        XCTAssertEqual(result.weighIns, 15)
        XCTAssertEqual(result.tdee, 2800, accuracy: 0.01)
        XCTAssertEqual(result.averageIntake, 3300, accuracy: 0.01)
        XCTAssertFalse(result.scenarioUsesCalibrationIntake)
        XCTAssertLessThan(result.calibrationIntake, result.averageIntake)
    }
    func testLongIntervalFitResistsSingleWeightSpikeWithoutLabellingItWater() throws {
        var rows = history(); rows[28].weight = 86
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
    }
    func testNoWeightChangeUsesRecordedCaloriesWithoutDemographicFormula() throws {
        var rows = history()
        for i in rows.indices { rows[i].calories = 2700; rows[i].weight = 96 }
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.tdee, 2700, accuracy: 0.01)
    }
    func testFutureRecordsDoNotDistortEstimate() throws {
        var rows = history()
        rows.append(HealthDay(date: calendar.date(byAdding: .day, value: 1, to: now)!, weight: 90, calories: 100))
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
        XCTAssertEqual(result.lastDate, now)
    }
    func testTwoWeighInsOneDayApartCanProduceEstimate() throws {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let rows = [HealthDay(date: yesterday, weight: 80, calories: 2200), HealthDay(date: now, weight: 80, calories: nil)]
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
        XCTAssertEqual(result.weighIns, 2)
        XCTAssertEqual(result.days, 1)
    }
    func testWindowAnchorsToOldLastWeighInWithoutRequiringRecentIntake() throws {
        let last = calendar.date(byAdding: .day, value: -20, to: now)!
        let rows = (-15...0).map { offset in
            HealthDay(date: calendar.date(byAdding: .day, value: offset, to: last)!,
                      weight: offset == -15 ? 120 : (offset == -14 || offset == 0 ? 80 : nil), calories: offset == 0 ? nil : 2200)
        }
        let result = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(result.firstDate, calendar.date(byAdding: .day, value: -14, to: last))
        XCTAssertEqual(result.lastDate, last)
        XCTAssertEqual(result.days, 14)
        XCTAssertEqual(result.weighIns, 2)
        XCTAssertEqual(result.tdee, 2200, accuracy: 0.01)
        XCTAssertEqual(result.averageIntake, 2200)
        XCTAssertTrue(result.scenarioUsesCalibrationIntake)
    }
    func testSingleWeighInOrSameDayDuplicatesCannotMeasureChange() {
        XCTAssertNil(NativeHealthMath.estimate([HealthDay(date: now, weight: 80, calories: 2200)], now: now, calendar: calendar))
        XCTAssertNil(NativeHealthMath.estimate([HealthDay(date: now, weight: 80, calories: 2200), HealthDay(date: now, weight: 81, calories: 2200)], now: now, calendar: calendar))
    }
    func testPartialShortHistoryIsAllowed() throws {
        XCTAssertNotNil(NativeHealthMath.estimate(Array(history().suffix(4)), now: now, calendar: calendar))
    }
    func testMedianSuppressesSingleWaterSpike() {
        var rows = history(); rows[20].weight = 85
        let trend = NativeHealthMath.trend(rows, calendar: calendar)
        XCTAssertEqual(trend[20].value, 80)
    }
    func testScenarioAtMaintenanceIsFlatAndDeficitIsMonotonic() {
        let e = HealthEstimate(tdee: 2500, averageIntake: 2300, startWeight: 80, lastDate: now, days: 28)
        XCTAssertTrue(NativeHealthMath.forecast(e, intake: 2500).allSatisfy { $0.value == 80 })
        let deficit = NativeHealthMath.forecast(e, intake: 2100)
        XCTAssertEqual(deficit.count, 57)
        XCTAssertEqual(deficit.first?.value, 80)
        XCTAssertTrue(zip(deficit, deficit.dropFirst()).allSatisfy { $0.value > $1.value })
        XCTAssertGreaterThan(deficit[56].value, 80 - 400.0 * 56 / 7700)
        XCTAssertGreaterThan(NativeHealthMath.forecast(e, intake: 2800)[56].value, 80)
        XCTAssertTrue(NativeHealthMath.forecast(e, intake: .nan).isEmpty)
        XCTAssertTrue(NativeHealthMath.forecast(e, intake: -100).isEmpty)
    }
}
