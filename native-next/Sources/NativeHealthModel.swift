import Foundation

struct HealthDay: Identifiable, Equatable {
    let date: Date
    var weight: Double?
    var calories: Double?
    var id: Date { date }
}
struct HealthPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}
struct HealthEstimate {
    let tdee: Double
    /// Recent recorded intake for the default future scenario, not the calibration mean.
    let averageIntake: Double
    let startWeight: Double
    let lastDate: Date
    let days: Int
    var firstDate: Date? = nil
    var weighIns: Int = 0
    var loggedDays: Int = 0
    var imputedDays: Int = 0
    var calibrationIntake: Double = 0
    /// Sensitivity to filling missing days 500 kcal higher/lower; not a confidence interval.
    var missingDaySensitivity: Double = 0
}

/// Energy-balance calibration from matched cumulative intake and raw weigh-ins.
/// Robust median of long-interval slopes (Theil–Sen style), not the NIH model.
/// Energy balance: intake - change in stored energy; 7,700 kcal/kg is an
/// approximation. Forecast expenditure changes by 22 kcal/day per kg changed,
/// following the population-level relationship described by Hall et al. (2011).
/// Historical average, not measured current metabolism. Neither parameter identifies
/// individual body composition or water changes; extending history cannot prove their separation.
enum NativeHealthMath {
    static let energyPerKG = 7700.0
    static let expenditurePerKG = 22.0
    static func trend(_ days: [HealthDay], calendar: Calendar = .current) -> [HealthPoint] {
        let weights = days.filter { ($0.weight ?? 0) > 0 && ($0.weight?.isFinite ?? false) }.sorted { $0.date < $1.date }
        return weights.map { day in
            let start = calendar.date(byAdding: .day, value: -6, to: day.date)!
            let window = weights.filter { $0.date >= start && $0.date <= day.date }.compactMap(\.weight).sorted()
            let middle = window.count / 2
            let median = window.count % 2 == 0 ? (window[middle - 1] + window[middle]) / 2 : window[middle]
            return HealthPoint(date: day.date, value: median)
        }
    }
    static func estimate(_ days: [HealthDay], now: Date = Date(), calendar: Calendar = .current) -> HealthEstimate? {
        let today = calendar.startOfDay(for: now)
        guard let lastWeightDate = days.filter({ $0.date < today && ($0.weight ?? 0) > 0 && ($0.weight?.isFinite ?? false) }).map(\.date).max() else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -30, to: lastWeightDate)!
        let history = days.filter { $0.date >= cutoff && $0.date <= lastWeightDate }.sorted { $0.date < $1.date }
        // Work with aligned daily records, not a lagged moving median.
        guard Set(history.map(\.date)).count == history.count else { return nil }
        let weights = history.filter { ($0.weight ?? 0) > 0 && ($0.weight?.isFinite ?? false) }
        guard weights.count >= 10, let first = weights.first, let last = weights.last,
              let age = calendar.dateComponents([.day], from: last.date, to: today).day, age <= 7 else { return nil }
        let span = calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        guard span >= 28 else { return nil }
        let food = history.filter { $0.date >= first.date && $0.date < last.date }
        let logged = food.compactMap(\.calories).filter { $0.isFinite && $0 > 0 }
        let missing = span - logged.count
        // Small gaps can be estimated only with >=90% coverage and are always disclosed.
        guard missing >= 0, Double(logged.count) / Double(span) >= 0.9 else { return nil }
        let calibrationIntake = logged.reduce(0, +) / Double(logged.count)
        var intakeByDay: [Int: Double] = [:]
        for day in food {
            if let value = day.calories, value.isFinite, value > 0 {
                let offset = calendar.dateComponents([.day], from: first.date, to: day.date).day!
                intakeByDay[offset] = value
            }
        }
        var cumulative = [0.0], missingPrefix = [0]
        for offset in 0..<span {
            cumulative.append(cumulative.last! + (intakeByDay[offset] ?? calibrationIntake))
            missingPrefix.append(missingPrefix.last! + (intakeByDay[offset] == nil ? 1 : 0))
        }
        let offsets = weights.map { calendar.dateComponents([.day], from: first.date, to: $0.date).day! }
        // C(t) - rho * [W(t)-W(0)] = cumulative expenditure. Its long-interval
        // slope estimates average expenditure even when calorie intake changes.
        let adjusted = weights.enumerated().map { index, day in
            cumulative[offsets[index]] - energyPerKG * (day.weight! - first.weight!)
        }
        let minimumPairDays = span >= 84 ? 56 : 21
        var slopes: [Double] = [], lowerSlopes: [Double] = [], upperSlopes: [Double] = []
        for j in 1..<weights.count {
            for i in 0..<j {
                let interval = offsets[j] - offsets[i]
                guard interval >= minimumPairDays else { continue }
                let value = (adjusted[j] - adjusted[i]) / Double(interval)
                let gapImpact = 500.0 * Double(missingPrefix[offsets[j]] - missingPrefix[offsets[i]]) / Double(interval)
                slopes.append(value); lowerSlopes.append(value - gapImpact); upperSlopes.append(value + gapImpact)
            }
        }
        guard slopes.count >= 10 else { return nil }
        let tdee = median(slopes)
        guard tdee.isFinite, (800...6000).contains(tdee) else { return nil }
        let recentStart = cutoff
        let recentIntake = history.filter { $0.date >= recentStart && $0.date < last.date }.compactMap(\.calories).filter { $0.isFinite && $0 > 0 }
        let scenarioIntake = recentIntake.isEmpty ? calibrationIntake : recentIntake.reduce(0, +) / Double(recentIntake.count)
        var result = HealthEstimate(tdee: tdee, averageIntake: scenarioIntake,
            startWeight: trend(weights, calendar: calendar).last!.value, lastDate: last.date, days: span)
        result.firstDate = first.date; result.weighIns = weights.count
        result.loggedDays = logged.count; result.imputedDays = missing; result.calibrationIntake = calibrationIntake
        result.missingDaySensitivity = max(tdee - median(lowerSlopes), median(upperSlopes) - tdee)
        return result
    }
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(), middle = values.count / 2
        return values.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    static func forecast(_ estimate: HealthEstimate, intake: Double, weeks: Int = 8) -> [HealthPoint] {
        guard intake.isFinite, (800...6000).contains(intake), (1...12).contains(weeks) else { return [] }
        // Analytic solution of dW/dt = (intake - TDEE0 - k * (W-W0)) / rho.
        return (0...(weeks * 7)).compactMap { day in
            let change = (intake - estimate.tdee) / expenditurePerKG * (1 - exp(-expenditurePerKG * Double(day) / energyPerKG))
            let value = estimate.startWeight + change
            guard value > 0 else { return nil }
            return HealthPoint(date: estimate.lastDate.addingTimeInterval(Double(day) * 86400), value: value)
        }
    }
    static func demo(now: Date = Date(), calendar: Calendar = .current) -> [HealthDay] {
        let today = calendar.startOfDay(for: now)
        return (-42...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return HealthDay(date: date, weight: 80 - Double(offset) * 0.035 + sin(Double(offset)) * 0.25,
                             calories: offset == 0 ? nil : 2250 + sin(Double(offset)) * 180)
        }
    }
}

/// Health access is independent of the financial demo. Only explicit DEBUG UI
/// tests may substitute samples; launch arguments cannot enable this in release.
enum NativeHealthLaunchPolicy {
    static func usesSimulatedData(debugBuild: Bool, arguments: [String]) -> Bool {
        debugBuild && arguments.contains("--visual-test")
    }
    static var simulated: Bool {
        #if DEBUG
        return usesSimulatedData(debugBuild: true, arguments: ProcessInfo.processInfo.arguments)
        #else
        return false
        #endif
    }
}

/// Presentation window only: calendar month before today and calendar month ahead.
/// The historical TDEE calibration and its assumptions remain unchanged.
struct NativeHealthDashboardData {
    let today: Date
    let start: Date
    let end: Date
    let days: [HealthDay]
    let trend: [HealthPoint]
    let forecast: [HealthPoint]
    /// Visual join only: original measured values and forecast remain unchanged.
    let transition: [HealthPoint]
    let weightDomain: ClosedRange<Double>
    let calorieCeiling: Double

    init(days: [HealthDay], estimate: HealthEstimate?, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .month, value: -1, to: today)!
        let end = calendar.date(byAdding: .month, value: 1, to: today)!
        self.today = today; self.start = start; self.end = end
        self.days = days.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        trend = NativeHealthMath.trend(days.filter { $0.date <= now }, calendar: calendar).filter { $0.date >= start }
        // Six weeks cover a calendar month ahead even if the last complete weigh-in
        // is seven days old. Keep the actual calibration baseline; do not reset it to today.
        if let estimate, estimate.lastDate <= now,
           estimate.lastDate >= calendar.date(byAdding: .day, value: -7, to: today)! {
            forecast = NativeHealthMath.forecast(estimate, intake: estimate.averageIntake, weeks: 6)
                .filter { $0.date >= today && $0.date <= end }
        } else { forecast = [] }
        if let last = trend.last, let first = forecast.first {
            // A short solid bridge explains the change from smoothed history to
            // the calibrated scenario; avoid a vertical jump at the same date.
            let joinStart = calendar.date(byAdding: .day, value: -3, to: first.date)!
            let anchor = trend.last { $0.date <= joinStart } ?? last
            transition = [anchor, first]
        } else { transition = [] }
        let weights = self.days.compactMap(\.weight).filter { $0.isFinite && $0 > 0 } + trend.map(\.value) + forecast.map(\.value)
        weightDomain = ((weights.min() ?? 70) - 1)...((weights.max() ?? 80) + 1)
        let highestCalories = self.days.compactMap(\.calories).filter { $0.isFinite && $0 > 0 }.max() ?? 0
        calorieCeiling = max(3000, ceil(highestCalories / 1000) * 1000)
    }
    /// Swift Charts has one numerical Y domain: map kcal linearly onto it while
    /// displaying the original kcal on the independent left axis and accessibility labels.
    func plottedCalories(_ calories: Double) -> Double {
        weightDomain.lowerBound + calories / calorieCeiling * (weightDomain.upperBound - weightDomain.lowerBound)
    }
}
