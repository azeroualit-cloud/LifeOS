import Foundation

struct NativeHomeChecklistItem: Identifiable {
    enum Kind: String { case event, routine }
    let kind: Kind
    let record: Record
    let day: String
    let time: String
    var id: String { kind.rawValue + ":" + String(record.integer("id")) + (kind == .event ? ":" + day : "") }
}

enum NativeHomeChecklist {
    static func rows(events: [Record], routines: [Record], today: String) -> [NativeHomeChecklistItem] {
        // The home is an attention window, not a second task library.
        let last = CivilDate.adding(2, to: today)
        var result: [NativeHomeChecklistItem] = events.filter {
            $0.text("occurrence_status", fallback: "open") == "open" && $0.text("day") >= today && $0.text("day") <= last
        }.map { .init(kind: .event, record: $0, day: $0.text("day"), time: $0.text("start_time")) }
        result += routines.map { .init(kind: .routine, record: $0, day: today, time: "") }
        func rank(_ item: NativeHomeChecklistItem) -> Int { item.kind == .routine ? 1 : item.day == today ? 0 : 2 }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }.sorted { a, b in
            (rank(a), a.day, a.time.isEmpty ? "99:99" : a.time, a.id) < (rank(b), b.day, b.time.isEmpty ? "99:99" : b.time, b.id)
        }
    }
}
