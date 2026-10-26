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
