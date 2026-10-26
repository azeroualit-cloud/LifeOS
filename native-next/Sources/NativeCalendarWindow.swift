import Foundation

/// Stable civil month identifiers keep scroll anchors intact when extending the range.
enum NativeCalendarWindow {
    static func monthLabel(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = CivilDate.calendar.timeZone
        formatter.dateFormat = "LLL"
        return formatter.string(from: CivilDate.date(month + "-01")).replacingOccurrences(of: ".", with: "").capitalized
    }
    static func offset(_ month: String, by delta: Int) -> String {
        String(CivilDate.adding(delta, to: month + "-01", component: .month).prefix(7))
    }
    static func months(around month: String, radius: Int = 3) -> [String] {
        (-radius...radius).map { offset(month, by: $0) }
    }
}
