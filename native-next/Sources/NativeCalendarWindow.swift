import Foundation

/// Stable civil month identifiers keep scroll anchors intact when extending the range.
enum NativeCalendarWindow {
    /// A boundary week belongs to its Monday's month. The first visible month
    /// also owns its leading week, so every date appears once without empty rows.
    static func weekIndexes(_ month: String, includeLeading: Bool) -> [Int] {
        let days = CivilDate.gridDates(month)
        return (0..<(days.count / 7)).filter { includeLeading || CivilDate.day(days[$0 * 7]).hasPrefix(month) }
    }
    static func monthLabel(_ month: String) -> String { CivilDate.monthAbbreviation(month) }
    /// Keep neighbouring identities stable while bounding grids and server snapshots.
    static let capacity = 13
    static func extended(_ current: [String], around month: String) -> [String] {
        guard current.contains(month) else { return months(around: month) }
        let limit = capacity
        let combined = Array(Set(current + months(around: month))).sorted()
        guard combined.count > limit, let index = combined.firstIndex(of: month) else { return combined }
        let first = max(0, min(index - limit / 2, combined.count - limit))
        return Array(combined[first..<(first + limit)])
    }
    static func coveredMonths(around month: String, within window: [String]) -> [String] {
        let retained = Set(window)
        return months(around: month, radius: 1).filter { retained.contains($0) }
    }
    static func offset(_ month: String, by delta: Int) -> String {
        String(CivilDate.adding(delta, to: month + "-01", component: .month).prefix(7))
    }
    static func months(around month: String, radius: Int = 3) -> [String] {
        (-radius...radius).map { offset(month, by: $0) }
    }
}
