import SwiftUI

/// HISTORY-REDESIGN-97: Cronologia by interval (7 g, 30 g, 3 mesi, Date), a coloured calendar
/// (Fitia green in range, yellow below, orange far above, grey without data), the selected day's
/// totals and meals, the interval's averages and one column per week.
enum NativeHistoryRange: Int, CaseIterable {
    case week, month, quarter, custom
    var title: String { ["7 g", "30 g", "3 mesi", "Date"][rawValue] }
}

enum NativeHistoryDays {
    static let italian = Locale(identifier: "it_IT")

    /// First and last day (both included) of the interval, never after today.
    static func span(_ range: NativeHistoryRange, from: Date, to: Date, now: Date = .now, calendar: Calendar = NativeHealthWeek.calendar) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .week: return (calendar.date(byAdding: .day, value: -6, to: today)!, today)
        case .month: return (calendar.date(byAdding: .day, value: -29, to: today)!, today)
        case .quarter: return (calendar.date(byAdding: .month, value: -3, to: today).map { calendar.date(byAdding: .day, value: 1, to: $0)! }!, today)
        case .custom:
            let a = calendar.startOfDay(for: min(from, to)), b = min(calendar.startOfDay(for: max(from, to)), today)
            return (min(a, b), b)
        }
    }

    static func days(_ start: Date, _ end: Date, calendar: Calendar = NativeHealthWeek.calendar) -> [Date] {
        var out: [Date] = [], day = start
        while day <= end { out.append(day); day = calendar.date(byAdding: .day, value: 1, to: day)! }
        return out
    }

    /// Mean of the logged days inside [start, end].
    static func average(_ macros: [Date: NativeMacroDay], start: Date, end: Date, name: String, label: String = "") -> NativeNutritionBar {
        let logged = macros.filter { $0.key >= start && $0.key <= end && $0.value.calories > 0 }.map(\.value)
        let count = Double(max(logged.count, 1))
        return NativeNutritionBar(start: start, label: label, name: name,
            protein: logged.map(\.protein).reduce(0, +) / count,
            carbohydrate: logged.map(\.carbohydrate).reduce(0, +) / count,
            fat: logged.map(\.fat).reduce(0, +) / count, days: logged.count)
    }

    /// One bar per week (Monday start) that touches the interval, clipped to it.
    static func weeks(_ macros: [Date: NativeMacroDay], start: Date, end: Date, calendar: Calendar = NativeHealthWeek.calendar) -> [NativeNutritionBar] {
        var out: [NativeNutritionBar] = []
        var monday = calendar.dateInterval(of: .weekOfYear, for: start)!.start
        while monday <= end {
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
            let week = calendar.component(.weekOfYear, from: monday)
            out.append(average(macros, start: max(monday, start), end: min(sunday, end), name: "Settimana \(week)", label: "s\(week)"))
            monday = calendar.date(byAdding: .day, value: 7, to: monday)!
        }
        return out
    }

    static func dayName(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(italian)).capitalized(with: italian)
    }
}

/// Coloured month grids for the interval; a tap selects the day.
struct NativeNutritionCalendar: View {
    let start: Date
    let end: Date
    let macros: [Date: NativeMacroDay]
    let goal: Double?
    @Binding var selected: Date
    private let calendar = NativeHealthWeek.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.xs), count: 7)

    private var months: [Date] {
        var out: [Date] = [], month = calendar.dateInterval(of: .month, for: start)!.start
        while month <= end { out.append(month); month = calendar.date(byAdding: .month, value: 1, to: month)! }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
            ForEach(months, id: \.self) { month in monthGrid(month) }
            legend
        }
    }

    private func monthGrid(_ month: Date) -> some View {
        let next = calendar.date(byAdding: .month, value: 1, to: month)!
        let last = calendar.date(byAdding: .day, value: -1, to: next)!
        let mean = NativeHistoryDays.average(macros, start: max(month, start), end: min(last, end), name: "")
        let lead = (calendar.component(.weekday, from: month) + 5) % 7
        let days = NativeHistoryDays.days(month, last, calendar: calendar)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(month.formatted(.dateTime.month(.wide).year().locale(NativeHistoryDays.italian)).capitalized(with: NativeHistoryDays.italian)).font(.headline)
                Spacer()
                if mean.days > 0 {
                    Text("media " + mean.calories.formatted(.number.precision(.fractionLength(0))) + " kcal")
                        .font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit()
                }
            }
            LazyVGrid(columns: columns, spacing: NativeDesign.Space.xs) {
                ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.caption2.weight(.semibold)).foregroundStyle(NativeDesign.secondary).accessibilityHidden(true)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: NativeDesign.Layout.touchTarget * 0.8) }
                ForEach(days, id: \.self) { day in cell(day) }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let inside = day >= start && day <= end
        let kcal = macros[day]?.calories
        let band = NativeCalorieBand.of(kcal, goal: goal)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let side = NativeDesign.Layout.touchTarget * 0.8
        return Button { selected = day } label: {
            Text(String(calendar.component(.day, from: day)))
                .font(.footnote.weight(isSelected ? .bold : .regular)).monospacedDigit()
                .foregroundStyle(inside ? (band == .none ? Color.primary : NativeDesign.financeTileText) : NativeDesign.secondary.opacity(0.5))
                .frame(width: side, height: side)
                .background { Circle().fill(inside ? band.color : Color.clear) }
                .overlay { if isSelected { Circle().stroke(Color.primary, lineWidth: 2) } }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!inside)
        .accessibilityIdentifier("nutrition-calendar-" + CivilDate.day(day))
        .accessibilityLabel(NativeHistoryDays.dayName(day) + ", " + (kcal.map { $0.formatted(.number.precision(.fractionLength(0))) + " kcal" } ?? "nessun dato"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var legend: some View {
        HStack(spacing: NativeDesign.Space.medium) {
            dot("Nel range", NativeCalorieBand.within.color)
            dot("Sotto", NativeCalorieBand.under.color)
            dot("Sopra", NativeCalorieBand.over.color)
            dot("Nessun dato", NativeCalorieBand.none.color)
        }.font(.caption2).foregroundStyle(NativeDesign.secondary)
    }

    private func dot(_ title: String, _ color: Color) -> some View {
        HStack(spacing: NativeDesign.Space.xs) {
            Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            Text(title).lineLimit(1)
        }
    }
}
