import Foundation

/// Stable civil month identifiers keep scroll anchors intact when extending the range.
enum NativeCalendarWindow {
    static func offset(_ month: String, by delta: Int) -> String {
        String(CivilDate.adding(delta, to: month + "-01", component: .month).prefix(7))
    }
    static func months(around month: String, radius: Int = 3) -> [String] {
        (-radius...radius).map { offset(month, by: $0) }
    }
}
