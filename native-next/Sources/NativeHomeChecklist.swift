import Foundation

struct NativeHomeChecklistItem: Identifiable {
    enum Kind: String { case task, event, routine }
    let kind: Kind
    let record: Record
    let day: String
    let time: String
    var id: String { kind.rawValue + ":" + String(record.integer("id")) + (kind == .event ? ":" + day : "") }
}

enum NativeHomeChecklist {
    static func rows(tasks: [Record], events: [Record], routines: [Record], today: String) -> [NativeHomeChecklistItem] {
        var result = tasks.filter {
            $0.text("status") != "done" && NativeTaskList.section($0) == "todo" && ($0.text("scheduled_date").isEmpty || $0.text("scheduled_date") <= today)
        }.map { row -> NativeHomeChecklistItem in
            let scheduled = row.text("scheduled_date"), due = row.text("due_date")
            let dates = [scheduled, due].filter { !$0.isEmpty }
            return .init(kind: .task, record: row, day: dates.min() ?? today, time: row.text("scheduled_time"))
        }
        result += events.filter { $0.text("occurrence_status", fallback: "open") == "open" && $0.text("day") >= today && $0.text("day") <= CivilDate.adding(6, to: today) }
            .map { .init(kind: .event, record: $0, day: $0.text("day"), time: $0.text("start_time")) }
        result += routines.map { .init(kind: .routine, record: $0, day: today, time: "") }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }.sorted { a, b in
            func rank(_ item: NativeHomeChecklistItem) -> Int { item.day < today ? 0 : item.day == today ? (item.time.isEmpty ? 2 : 1) : 3 }
            return (rank(a), a.day, a.time.isEmpty ? "99:99" : a.time, a.id) < (rank(b), b.day, b.time.isEmpty ? "99:99" : b.time, b.id)
        }
    }
}
