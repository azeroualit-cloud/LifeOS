import SwiftUI
import Charts

/// "Andamento" period of Salute (HEALTH-TREND-93-2026-11-21).
enum NativeHealthTrendPeriod: Int, CaseIterable, Identifiable {
    case one = 1, three = 3, six = 6
    var id: Int { rawValue }
    var title: String { self == .one ? "1 mese" : "\(rawValue) mesi" }
    var shortTitle: String { self == .one ? "1 mese" : "\(rawValue) mesi" }
    func start(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -rawValue, to: calendar.startOfDay(for: now)) ?? now
    }
}

/// Values of the Andamento section for one period. Pure: tested without HealthKit.
struct NativeHealthTrendSummary: Equatable {
    let averageCalories: Double?
    let averageProtein: Double?
    /// Change of the 7-day trend weight from the start of the period to the last weigh-in.
    let weightChange: Double?
    let latestWeight: Double?
    let latestWeightDate: Date?

    init(days: [HealthDay], protein: [Date: Double], period: NativeHealthTrendPeriod, now: Date = .now, calendar: Calendar = .current) {
        let start = period.start(now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        // Today is still being logged: averages use completed days only.
        let completed = days.filter { $0.date >= start && $0.date < today }
        averageCalories = NativeHealthMath.mean(completed.compactMap(\.calories).filter { $0 > 0 })
        averageProtein = NativeHealthMath.mean(protein.filter { $0.key >= start && $0.key < today && $0.value > 0 }.map(\.value))
        let weighed = days.filter { $0.date <= now && ($0.weight ?? 0) > 0 }.sorted { $0.date < $1.date }
        latestWeight = weighed.last?.weight
        latestWeightDate = weighed.last?.date
        let trend = NativeHealthMath.trend(days.filter { $0.date <= now }, calendar: calendar).filter { $0.date >= start }
        if let first = trend.first, let last = trend.last, last.date > first.date { weightChange = last.value - first.value }
        else { weightChange = nil }
    }
}

/// Weigh-ins, 7-day trend and the dashed forecast, without axes (Andamento card).
struct NativeWeightTrendChart: View {
    let days: [HealthDay]
    let forecast: [HealthPoint]
    let start: Date
    var height: CGFloat = NativeDesign.Layout.healthChartHeight * 0.6

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let weighed = days.filter { $0.date >= start && ($0.weight ?? 0) > 0 }
        let trend = NativeHealthMath.trend(days.filter { $0.date <= .now }).filter { $0.date >= start }
        let values = weighed.compactMap(\.weight) + trend.map(\.value) + forecast.map(\.value)
        let domain = ((values.min() ?? 70) - 0.5)...((values.max() ?? 80) + 0.5)
        let end = max(forecast.last?.date ?? today, today)
        Chart {
            ForEach(weighed) { day in
                PointMark(x: .value("Data", day.date), y: .value("Peso", day.weight!))
                    .foregroundStyle(NativeDesign.healthWeight.opacity(0.45)).symbolSize(14)
            }
            ForEach(trend) { point in
                LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Tendenza"))
                    .foregroundStyle(NativeDesign.healthWeight)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(forecast) { point in
                LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Previsione"))
                    .foregroundStyle(NativeDesign.estimate)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
            }
            RuleMark(x: .value("Oggi", today)).foregroundStyle(NativeDesign.secondary.opacity(0.5))
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
        .chartYAxis(.hidden).chartLegend(.hidden)
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Seven bars of the selected week with the calorie goal as a dashed rule.
struct NativeWeekCaloriesChart: View {
    let week: [Date]
    let calories: (Date) -> Double?
    let goal: Double?
    let selected: Date

    var body: some View {
        let values = week.map { calories($0) ?? 0 }
        let top = max(goal ?? 0, values.max() ?? 0, 1) * 1.1
        Chart {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let value = values[index]
                let over = goal.map { value > $0 } ?? false
                BarMark(x: .value("Giorno", day, unit: .day), y: .value("Calorie", value))
                    .foregroundStyle(over ? NativeDesign.overGoal : NativeDesign.macroProtein)
                    .opacity(Calendar.current.isDate(day, inSameDayAs: selected) ? 1 : 0.62)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: NativeDesign.Space.xs, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: NativeDesign.Space.xs))
            }
            if let goal {
                RuleMark(y: .value("Obiettivo", goal))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .chartYScale(domain: 0...top)
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        .chartYAxis(.hidden).chartLegend(.hidden)
        .frame(height: NativeDesign.Layout.healthOverviewChart)
        .accessibilityHidden(true)
    }
}

/// Weight simulation of the build 93 preview: from the real trend of the last weeks
/// (least squares on the 7-day trend) or from a calorie intake (energy model).
enum NativeWeightSimulation {
    enum Mode: String, CaseIterable { case trend, calories }

    /// kg per day of the trend line over the last `weeks` weeks; nil with fewer than two points.
    static func trendSlope(_ days: [HealthDay], weeks: Int, now: Date = .now, calendar: Calendar = .current) -> Double? {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -weeks * 7, to: today) else { return nil }
        let points = NativeHealthMath.trend(days.filter { $0.date <= now }, calendar: calendar).filter { $0.date >= start }
        guard let first = points.first else { return nil }
        let x = points.map { Double(calendar.dateComponents([.day], from: first.date, to: $0.date).day ?? 0) }
        return NativeHealthMath.leastSquaresSlope(x: x, y: points.map(\.value))
    }

    /// Straight line from the last trend weight, one point per day for `horizon` weeks.
    static func trendForecast(_ days: [HealthDay], weeks: Int, horizon: Int, now: Date = .now, calendar: Calendar = .current) -> [HealthPoint] {
        guard let slope = trendSlope(days, weeks: weeks, now: now, calendar: calendar),
              let last = NativeHealthMath.trend(days.filter { $0.date <= now }, calendar: calendar).last,
              (1...26).contains(horizon) else { return [] }
        let start = calendar.startOfDay(for: max(last.date, calendar.startOfDay(for: now)))
        let offset = Double(calendar.dateComponents([.day], from: last.date, to: start).day ?? 0)
        return (0...(horizon * 7)).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day, to: start) else { return nil }
            let value = last.value + slope * (offset + Double(day))
            return value > 0 ? HealthPoint(date: date, value: value) : nil
        }
    }

    /// Daily intake that reaches `target` kg in `weeks` weeks (energy balance, kcal/kg of the criteria).
    static func intakeNeeded(tdee: Double, from start: Double, to target: Double, weeks: Int, energyPerKG: Double = NativeHealthMath.energyPerKG) -> Double? {
        guard weeks > 0, tdee.isFinite, start.isFinite, target.isFinite else { return nil }
        return tdee + (target - start) * energyPerKG / Double(weeks * 7)
    }
}

/// Macros of one day (HealthKit totals), the input of the history bars.
struct NativeMacroDay: Equatable {
    var protein: Double
    var carbohydrate: Double
    var fat: Double
    var calories: Double { protein * 4 + carbohydrate * 4 + fat * 9 }
}

/// Grouping of "Cronologia" (build 93 preview): Giorni, Settimane, Mesi, Trimestri.
enum NativeNutritionGrouping: Int, CaseIterable, Identifiable {
    case days, weeks, months, quarters
    var id: Int { rawValue }
    var title: String { ["Giorni", "Settimane", "Mesi", "Trimestri"][rawValue] }
}

/// One stacked bar: mean per logged day of the bucket. `days` = days with data.
struct NativeNutritionBar: Identifiable, Equatable {
    let start: Date
    let label: String
    let name: String
    let protein: Double
    let carbohydrate: Double
    let fat: Double
    let days: Int
    var id: Date { start }
    var calories: Double { protein * 4 + carbohydrate * 4 + fat * 9 }
}

enum NativeNutritionBars {
    private static let italian = Locale(identifier: "it_IT")

    /// Days: the week of `selected`. Weeks: last 6. Months: last 6. Quarters: the 4 of the year.
    static func bars(_ macros: [Date: NativeMacroDay], grouping: NativeNutritionGrouping, selected: Date = .now, now: Date = .now, calendar: Calendar = NativeHealthWeek.calendar) -> [NativeNutritionBar] {
        let today = calendar.startOfDay(for: now)
        var buckets: [(start: Date, end: Date, label: String, name: String)] = []
        switch grouping {
        case .days:
            let monday = calendar.dateInterval(of: .weekOfYear, for: selected)!.start
            for day in (0..<7).compactMap({ calendar.date(byAdding: .day, value: $0, to: monday) }) {
                let end = calendar.date(byAdding: .day, value: 1, to: day)!
                buckets.append((day, end, day.formatted(.dateTime.weekday(.narrow).locale(italian)).uppercased(),
                                day.formatted(.dateTime.weekday(.abbreviated).day().locale(italian)).capitalized(with: italian)))
            }
        case .weeks:
            let monday = calendar.dateInterval(of: .weekOfYear, for: today)!.start
            for back in (0..<6).reversed() {
                let start = calendar.date(byAdding: .weekOfYear, value: -back, to: monday)!
                let week = calendar.component(.weekOfYear, from: start)
                buckets.append((start, calendar.date(byAdding: .day, value: 7, to: start)!, String(week), "Settimana \(week)"))
            }
        case .months:
            let first = calendar.dateInterval(of: .month, for: today)!.start
            for back in (0..<6).reversed() {
                let start = calendar.date(byAdding: .month, value: -back, to: first)!
                buckets.append((start, calendar.date(byAdding: .month, value: 1, to: start)!,
                                start.formatted(.dateTime.month(.abbreviated).locale(italian)).lowercased(),
                                start.formatted(.dateTime.month(.wide).locale(italian)).capitalized(with: italian)))
            }
        case .quarters:
            let year = calendar.dateInterval(of: .year, for: today)!.start
            let names = ["Gen - mar", "Apr - giu", "Lug - set", "Ott - dic"]
            for quarter in 0..<4 {
                let start = calendar.date(byAdding: .month, value: quarter * 3, to: year)!
                buckets.append((start, calendar.date(byAdding: .month, value: 3, to: start)!, "T\(quarter + 1)", names[quarter]))
            }
        }
        return buckets.map { bucket in
            let logged = macros.filter { $0.key >= bucket.start && $0.key < bucket.end && $0.key <= today && $0.value.calories > 0 }.map(\.value)
            let count = Double(max(logged.count, 1))
            return NativeNutritionBar(start: bucket.start, label: bucket.label, name: bucket.name,
                protein: logged.map(\.protein).reduce(0, +) / count,
                carbohydrate: logged.map(\.carbohydrate).reduce(0, +) / count,
                fat: logged.map(\.fat).reduce(0, +) / count, days: logged.count)
        }
    }
}
