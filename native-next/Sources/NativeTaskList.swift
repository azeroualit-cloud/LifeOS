import Foundation

/// The API keeps `done` for compatibility; section membership is independent.
enum NativeTaskList {
    static func section(_ row: Record) -> String {
        if row.text("status") == "waiting" { return "waiting" }
        return row.text("status") == "done" && row.text("section_status") == "waiting" ? "waiting" : "todo"
    }
    static func rows(_ tasks: [Record], category: String, section: String, today: String = CivilDate.day()) -> [Record] {
        tasks.filter {
            guard $0.text("list_kind") == category else { return false }
            if section == "done" { return $0.text("status") == "done" }
            return $0.text("status") != "done" && self.section($0) == section && ($0.text("scheduled_date").isEmpty || $0.text("scheduled_date") <= today)
        }.sorted {
            let a = $0.text("status") == "done", b = $1.text("status") == "done"
            if a != b { return !a }
            if $0.amount("sort_order") != $1.amount("sort_order") { return $0.amount("sort_order") < $1.amount("sort_order") }
            return $0.integer("id") < $1.integer("id")
        }
    }
    static func completionStatus(_ row: Record) -> String {
        row.text("status") == "done" ? section(row) : "done"
    }
    static func reorderIDs(tasks: [Record], category: String, visibleIDs: [Int]) -> [Int] {
        let all = tasks.filter { $0.text("list_kind") == category && $0.text("status") == "todo" }.sorted {
            ($0.amount("sort_order"), $0.integer("id")) < ($1.amount("sort_order"), $1.integer("id"))
        }.map { $0.integer("id") }
        let visible = Set(visibleIDs), allowed = Set(all)
        return visibleIDs.filter { allowed.contains($0) } + all.filter { !visible.contains($0) }
    }
}
