import XCTest
@testable import LifeOSProbe

/// Build 93: nutrition goals (NUTRITION-GOALS-93-2026-11-21) and TDEE criteria.
final class NativeNutritionGoalsTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 21))! }
    private func history(slope: Double = 0, calories: Double = 2200) -> [HealthDay] {
        (-35...0).map { offset in
            HealthDay(date: calendar.date(byAdding: .day, value: offset, to: now)!, weight: 80 + slope * Double(offset), calories: calories)
        }
    }

    func testTDEEGoalAppliesDeficitAndCarbohydratesTakeTheRest() throws {
        let goals = NativeNutritionGoals.standard
        let targets = try XCTUnwrap(goals.targets(tdee: 2610, weight: 74.6))
        XCTAssertEqual(targets.calories, 2310)
        XCTAssertEqual(targets.protein, (2.0 * 74.6).rounded())
        XCTAssertEqual(targets.fat, (0.9 * 74.6).rounded())
        let protein: Double = 2.0 * 74.6, fat: Double = 0.9 * 74.6
        let rest: Double = 2310 - protein * 4 - fat * 9
        let expectedCarbs: Double = (rest / 4).rounded()
        XCTAssertEqual(targets.carbohydrate, expectedCarbs)
    }

    func testFixedGoalNeedsNoTDEEAndGramsNeedNoWeight() throws {
        var goals = NativeNutritionGoals.standard
        goals.calorieMode = .fixed; goals.fixedCalories = 2450
        goals.proteinUnit = .grams; goals.protein = 160
        goals.fatUnit = .grams; goals.fat = 75
        let targets = try XCTUnwrap(goals.targets(tdee: nil, weight: nil))
        XCTAssertEqual(targets.calories, 2450)
        XCTAssertEqual(targets.carbohydrate, 284.0, accuracy: 0.001)
    }

    func testNoTargetsWithoutTDEEOrWithoutWeightForPerKG() {
        XCTAssertNil(NativeNutritionGoals.standard.targets(tdee: nil, weight: 80))
        XCTAssertNil(NativeNutritionGoals.standard.targets(tdee: 2500, weight: nil))
    }

    func testCarbohydratesNeverNegative() throws {
        var goals = NativeNutritionGoals.standard
        goals.calorieMode = .fixed; goals.fixedCalories = 1000
        goals.proteinUnit = .grams; goals.protein = 200
        let targets = try XCTUnwrap(goals.targets(tdee: nil, weight: 80))
        XCTAssertEqual(targets.carbohydrate, 0)
    }

    func testAverageWeightUsesLastSevenDays() throws {
        var rows = history()
        for index in rows.indices { rows[index].weight = index < rows.count - 7 ? 90 : 80 }
        XCTAssertEqual(try XCTUnwrap(NativeNutritionGoals.averageWeight(rows, now: now, calendar: calendar)), 80, accuracy: 0.001)
        let old = [HealthDay(date: calendar.date(byAdding: .day, value: -30, to: now)!, weight: 77, calories: nil)]
        XCTAssertEqual(NativeNutritionGoals.averageWeight(old, now: now, calendar: calendar), 77)
    }

    func testStandardCriteriaGiveTheBuild92Estimate() throws {
        let rows = history(slope: -0.04)
        let standard = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        let explicit = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar, criteria: .standard))
        XCTAssertEqual(standard.tdee, explicit.tdee)
        XCTAssertEqual(standard.days, 14)
        XCTAssertEqual(standard.energyPerKG, 7700)
    }

    func testWindowAndEnergyCriteriaChangeTheEstimate() throws {
        let rows = history(slope: -0.04)
        var criteria = NativeTDEECriteria.standard
        criteria.days = 28
        let longer = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar, criteria: criteria))
        XCTAssertEqual(longer.days, 28)
        criteria.days = 14; criteria.energyPerKG = 8500
        let higher = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar, criteria: criteria))
        let base = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertGreaterThan(higher.tdee, base.tdee, "Losing weight with more kcal per kg means a higher expenditure")
    }

    func testRegressionMatchesMedianOnALinearHistory() throws {
        let rows = history(slope: -0.04)
        var criteria = NativeTDEECriteria.standard
        criteria.slope = .regression
        let regression = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar, criteria: criteria))
        let median = try XCTUnwrap(NativeHealthMath.estimate(rows, now: now, calendar: calendar))
        XCTAssertEqual(regression.tdee, median.tdee, accuracy: 0.5)
    }

    func testMissingDaysLimitIsAdjustable() throws {
        var rows = history()
        for index in 28...29 { rows[index].calories = nil }
        XCTAssertNil(NativeHealthMath.estimate(rows, now: now, calendar: calendar), "2 of 14 days missing exceeds 10%")
        var criteria = NativeTDEECriteria.standard
        criteria.maxMissingPercent = 15
        XCTAssertNotNil(NativeHealthMath.estimate(rows, now: now, calendar: calendar, criteria: criteria))
    }

    func testCriteriaAreClampedToTheirRanges() {
        var criteria = NativeTDEECriteria(days: 99, energyPerKG: 100, maxMissingPercent: -4, slope: .median)
        criteria = criteria.clamped
        XCTAssertEqual(criteria.days, 28)
        XCTAssertEqual(criteria.energyPerKG, 7000)
        XCTAssertEqual(criteria.maxMissingPercent, 0)
    }

    @MainActor func testPreferencesPersistAcrossInstances() throws {
        let suite = "goals-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = NativeHealthPreferences(defaults: defaults)
        first.goals.adjustment = -500
        first.criteria.days = 21
        let second = NativeHealthPreferences(defaults: defaults)
        XCTAssertEqual(second.goals.adjustment, -500)
        XCTAssertEqual(second.criteria.days, 21)
    }

    func testTrendSummaryAveragesCompletedDaysOfThePeriod() throws {
        var rows = history(calories: 2000)
        rows[rows.count - 1].calories = 500 // today, still being logged
        var protein: [Date: Double] = [:]
        for row in rows { protein[row.date] = 150 }
        let summary = NativeHealthTrendSummary(days: rows, protein: protein, period: .one, now: now, calendar: calendar)
        XCTAssertEqual(try XCTUnwrap(summary.averageCalories), 2000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.averageProtein), 150, accuracy: 0.001)
        XCTAssertEqual(summary.latestWeight, 80)
    }

    func testTrendSummaryReportsWeightChangeOverThePeriod() throws {
        let summary = NativeHealthTrendSummary(days: history(slope: -0.05), protein: [:], period: .one, now: now, calendar: calendar)
        XCTAssertLessThan(try XCTUnwrap(summary.weightChange), 0)
    }

    func testTrendSimulationFollowsTheMeasuredSlope() throws {
        let rows = history(slope: -0.05)
        let slope = try XCTUnwrap(NativeWeightSimulation.trendSlope(rows, weeks: 4, now: now, calendar: calendar))
        XCTAssertEqual(slope, -0.05, accuracy: 0.005)
        let points = NativeWeightSimulation.trendForecast(rows, weeks: 4, horizon: 2, now: now, calendar: calendar)
        XCTAssertEqual(points.count, 15)
        XCTAssertLessThan(try XCTUnwrap(points.last).value, try XCTUnwrap(points.first).value)
        XCTAssertTrue(NativeWeightSimulation.trendForecast(rows, weeks: 4, horizon: 27, now: now, calendar: calendar).isEmpty)
    }

    func testIntakeNeededForTarget() throws {
        let need = try XCTUnwrap(NativeWeightSimulation.intakeNeeded(tdee: 2610, from: 74.6, to: 73.0, weeks: 4))
        let expected: Double = 2610.0 + (73.0 - 74.6) * 7700.0 / 28.0
        XCTAssertEqual(need, expected, accuracy: 0.001)
        XCTAssertNil(NativeWeightSimulation.intakeNeeded(tdee: 2610, from: 74.6, to: 73, weeks: 0))
    }

    func testForecastNowReachesTwentySixWeeks() throws {
        let estimate = HealthEstimate(tdee: 2500, averageIntake: 2200, startWeight: 80, lastDate: now, days: 14)
        XCTAssertEqual(NativeHealthMath.forecast(estimate, intake: 2200, weeks: 26, calendar: calendar).count, 183)
        XCTAssertTrue(NativeHealthMath.forecast(estimate, intake: 2200, weeks: 27, calendar: calendar).isEmpty)
    }

    func testHistoryBarsAverageLoggedDaysAndSkipEmptyOnes() throws {
        var week = calendar; week.firstWeekday = 2
        let monday = week.dateInterval(of: .weekOfYear, for: now)!.start
        let macros: [Date: NativeMacroDay] = [
            monday: NativeMacroDay(protein: 100, carbohydrate: 200, fat: 50),
            week.date(byAdding: .day, value: 1, to: monday)!: NativeMacroDay(protein: 0, carbohydrate: 0, fat: 0)
        ]
        let days = NativeNutritionBars.bars(macros, grouping: .days, selected: now, now: now, calendar: week)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days[0].calories, 1650.0, accuracy: 0.001)
        XCTAssertEqual(days[1].days, 0, "A day with zero macros is not a logged day")
        let weeks = NativeNutritionBars.bars(macros, grouping: .weeks, now: now, calendar: week)
        XCTAssertEqual(weeks.count, 6)
        XCTAssertEqual(try XCTUnwrap(weeks.last).protein, 100, accuracy: 0.001)
        XCTAssertEqual(NativeNutritionBars.bars(macros, grouping: .months, now: now, calendar: week).count, 6)
        XCTAssertEqual(NativeNutritionBars.bars(macros, grouping: .quarters, now: now, calendar: week).map(\.label), ["T1", "T2", "T3", "T4"])
    }
}
