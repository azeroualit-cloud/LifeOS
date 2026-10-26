import Foundation

/// Calendar occurrences are activities viewed through their original event identity.
struct NativeActivity: Identifiable {
    let record: Record
    let isEvent: Bool
    var id: String { (isEvent ? "event:" : "task:") + String(record.integer("id")) + (isEvent ? ":" + record.text("day") : "") }
    var completed: Bool { record.text(isEvent ? "occurrence_status" : "status") == "done" }
}
enum NativeActivityCatalog {
    static func calendarRecord(_ record: Record, today: String = CivilDate.day()) -> Record {
        var result = record
        if !record.text("day").isEmpty && record.text("day") < today && record.text("occurrence_status") != "skipped" {
            result["occurrence_status"] = .string("done")
        }
        return result
    }
    static func rows(tasks: [Record], events: [Record], category: String, section: String, today: String = CivilDate.day()) -> [NativeActivity] {
        var rows = NativeTaskList.rows(tasks, category: category, section: section, today: today).map { NativeActivity(record: $0, isEvent: false) }
        if category == "action" && section == "todo" {
            var seen = Set<String>()
            let last = CivilDate.adding(7, to: today)
            rows += events.filter {
                $0.text("day") >= today && $0.text("day") <= last && $0.text("occurrence_status", fallback: "open") == "open"
            }.map { NativeActivity(record: $0, isEvent: true) }.filter { seen.insert($0.id).inserted }
        }
        let tomorrow = CivilDate.adding(1, to: today)
        func rank(_ item: NativeActivity) -> Int {
            guard item.isEvent else { return 2 }
            return item.record.text("day") == today ? 0 : item.record.text("day") == tomorrow ? 1 : 3
        }
        return rows.enumerated().sorted { a, b in
            let first = rank(a.element), second = rank(b.element)
            if first != second { return first < second }
            if a.element.isEvent && b.element.isEvent {
                let lhs = a.element.record, rhs = b.element.record
                return (lhs.text("day"), lhs.text("start_time"), lhs.integer("id")) < (rhs.text("day"), rhs.text("start_time"), rhs.integer("id"))
            }
            return a.offset < b.offset
        }.map(\.element)
    }
}
