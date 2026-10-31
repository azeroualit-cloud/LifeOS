import Foundation

/// Only changes that affect calendar content invalidate its monthly snapshots.
struct NativeCalendarSource: Equatable {
    private let content: Record
    private let demo: Bool
    private let origin: String?
    init(life: Record, demo: Bool, origin: String?) {
        self.demo = demo; self.origin = origin
        content = life.filter { ["month", "today", "events", "shifts", "tasks", "occurrences"].contains($0.key) }
    }
}

extension NativeCalendarSource {
    /// nil means the event/task indexes also need rebuilding. Pure shift edits
    /// return only changed dates, so a tap does not expand events for 13 months.
    func shiftChanges(from old: Self) -> [String: String]? {
        guard demo == old.demo, origin == old.origin,
              content.filter({ $0.key != "shifts" }) == old.content.filter({ $0.key != "shifts" }) else { return nil }
        var before: [String: String] = [:], after: [String: String] = [:]
        for row in old.content.records("shifts") { before[row.text("day")] = row.text("kind") }
        for row in content.records("shifts") { after[row.text("day")] = row.text("kind") }
        return Dictionary(uniqueKeysWithValues: Set(before.keys).union(after.keys).compactMap { day in
            before[day] == after[day] ? nil : (day, after[day] ?? "erase")
        })
    }
}
