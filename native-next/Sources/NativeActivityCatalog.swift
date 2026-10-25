import Foundation

/// Calendar occurrences are activities viewed through their original event identity.
struct NativeActivity: Identifiable {
    let record: Record
    let isEvent: Bool
    var id: String { (isEvent ? "event:" : "task:") + String(record.integer("id")) + (isEvent ? ":" + record.text("day") : "") }
    var completed: Bool { record.text(isEvent ? "occurrence_status" : "status") == "done" }
}
enum NativeActivityCatalog {
    static func rows(tasks: [Record], events: [Record], category: String, section: String) -> [NativeActivity] {
        var rows = NativeTaskList.rows(tasks, category: category, section: section).map { NativeActivity(record: $0, isEvent: false) }
        if category == "action" && section == "todo" {
            var seen = Set<String>()
            rows += events.map { NativeActivity(record: $0, isEvent: true) }.filter { seen.insert($0.id).inserted }
        }
        return rows.enumerated().sorted { a, b in
            a.element.completed == b.element.completed ? a.offset < b.offset : !a.element.completed
        }.map(\.element)
    }
}
