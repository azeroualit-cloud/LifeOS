import Foundation

/// Data of the build 93 Dashboard (DASHBOARD-93-2026-11-21). Pure: unit tested.
enum NativeDashboard93 {
    /// "Prossimi appuntamenti": open events after the checklist window (today and
    /// the next two dates, which "Cose da fare" already shows), earliest first.
    static func upcoming(events: [Record], today: String, limit: Int = 3) -> [Record] {
        let windowEnd = CivilDate.adding(2, to: today)
        var seen = Set<String>()
        return events
            .filter { $0.text("occurrence_status", fallback: "open") == "open" && $0.text("day") > windowEnd }
            .sorted { ($0.text("day"), $0.text("start_time")) < ($1.text("day"), $1.text("start_time")) }
            .filter { seen.insert(String($0.integer("id")) + "-" + $0.text("day")).inserted }
            .prefix(limit).map { $0 }
    }

    struct NextShift: Equatable {
        let day: String
        let kind: ShiftKind
        let start: String
    }

    /// First working shift (morning, afternoon, night) that has not started yet,
    /// looking up to 30 days ahead. Rest and holidays are skipped.
    static func nextShift(now: Date, shift: (String) -> ShiftKind?) -> NextShift? {
        let today = CivilDate.day(now)
        let hour = CivilDate.calendar.component(.hour, from: now), minute = CivilDate.calendar.component(.minute, from: now)
        let clock = String(format: "%02d:%02d", hour, minute)
        for offset in 0...30 {
            let day = CivilDate.adding(offset, to: today)
            guard let kind = shift(day), [.morning, .afternoon, .night].contains(kind) else { continue }
            let start = String(kind.time.prefix(5))
            if offset == 0 && start <= clock { continue }
            return NextShift(day: day, kind: kind, start: start)
        }
        return nil
    }

    /// "oggi 14:00", "domani 6:00", "lunedì 6:00", "24 nov 6:00".
    static func label(_ next: NextShift, today: String) -> String {
        let time = next.start.hasPrefix("0") ? String(next.start.dropFirst()) : next.start
        if next.day == today { return "oggi " + time }
        if next.day == CivilDate.adding(1, to: today) { return "domani " + time }
        let date = CivilDate.date(next.day)
        let italian = Locale(identifier: "it_IT")
        if next.day <= CivilDate.adding(6, to: today) { return date.formatted(.dateTime.weekday(.wide).locale(italian)) + " " + time }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(italian)) + " " + time
    }

    /// Spent share of the month budget for the bar: spent / (spent + remaining).
    static func spentFraction(spent: Double, remaining: Double?) -> Double? {
        guard let remaining, spent.isFinite, remaining.isFinite, spent >= 0 else { return nil }
        let total = spent + max(remaining, 0)
        guard total > 0 else { return nil }
        return min(max(spent / total, 0), 1)
    }
}
