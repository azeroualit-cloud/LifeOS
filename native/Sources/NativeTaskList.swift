import Foundation

/// The API keeps `done` for compatibility; section membership is independent.
enum NativeTaskList {
    static func section(_ row: Record) -> String {
        if row.text("status") == "waiting" { return "waiting" }
        return row.text("status") == "done" && row.text("section_status") == "waiting" ? "waiting" : "todo"
    }
    static func rows(_ tasks: [Record], category: String, section: String) -> [Record] {
        tasks.filter { $0.text("list_kind") == category && self.section($0) == section }.sorted {
            let a = $0.text("status") == "done", b = $1.text("status") == "done"
            if a != b { return !a }
            if $0.amount("sort_order") != $1.amount("sort_order") { return $0.amount("sort_order") < $1.amount("sort_order") }
            return $0.integer("id") < $1.integer("id")
        }
    }
    static func completionStatus(_ row: Record) -> String {
        row.text("status") == "done" ? section(row) : "done"
    }
}
