import Foundation

/// Minute-based layout shared by day rendering and overlap regression tests.
struct NativeCalendarTimeSlot: Identifiable {
    let id: String
    let record: Record
    let source: String
    let start: Int
    let end: Int
    var lane = 0
    var lanes = 1
}
enum NativeCalendarTimeline {
    static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard clock.count == 5, parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
    static func slots(events: [Record], tasks: [Record], minimumMinutes: Int) -> [NativeCalendarTimeSlot] {
        var items: [NativeCalendarTimeSlot] = []
        for (source, rows) in [("event", events), ("task", tasks)] {
            for record in rows {
                guard let start = minute(record.text(source == "event" ? "start_time" : "scheduled_time")) else { continue }
                let requestedEnd = minute(record.text("end_time")) ?? (start + 60)
                let end = min(1440, max(start + minimumMinutes, requestedEnd))
                items.append(NativeCalendarTimeSlot(id: source + ":" + String(record.integer("id")) + ":" + record.text("day"), record: record, source: source, start: start, end: end))
            }
        }
        items.sort { ($0.start, $0.end, $0.id) < ($1.start, $1.end, $1.id) }
        var result: [NativeCalendarTimeSlot] = [], group: [NativeCalendarTimeSlot] = [], ends: [Int] = []
        func flush() {
            for var item in group { item.lanes = ends.count; result.append(item) }
            group.removeAll(keepingCapacity: true); ends.removeAll(keepingCapacity: true)
        }
        for var item in items {
            if !ends.isEmpty, item.start >= (ends.max() ?? 0) { flush() }
            let lane = ends.firstIndex { $0 <= item.start } ?? ends.count
            if lane == ends.count { ends.append(item.end) } else { ends[lane] = item.end }
            item.lane = lane; group.append(item)
        }
        flush()
        return result
    }
}
