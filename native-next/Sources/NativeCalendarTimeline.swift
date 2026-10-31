import Foundation

/// Content-sized agenda: duration affects labels and containment, never row height.
struct NativeCalendarAgendaEntry: Identifiable {
    let id: String
    let record: Record
    let source: String
    let start: Int
    let end: Int?
    var intervalEnd: Int { end ?? start + 1 }
    var completed: Bool { source == "event" ? record.text("occurrence_status") == "done" : record.text("status") == "done" }
}
struct NativeCalendarAgendaNode: Identifiable {
    let entry: NativeCalendarAgendaEntry
    let children: [NativeCalendarAgendaNode]
    var id: String { entry.id }
}
enum NativeCalendarTimeline {
    static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard clock.count == 5, parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
    static func clock(_ minute: Int) -> String {
        let local = minute % 1440
        return String(format: "%02d:%02d", local / 60, local % 60) + (minute >= 1440 ? " +1" : "")
    }
    static func agenda(events: [Record], tasks: [Record], shift: ShiftKind?, previousShift: ShiftKind? = nil, previousEvents: [Record] = []) -> [NativeCalendarAgendaNode] {
        var entries: [NativeCalendarAgendaEntry] = []
        for (source, rows) in [("event", events), ("task", tasks)] {
            for record in rows {
                guard let start = minute(record.text(source == "event" ? "start_time" : "scheduled_time")) else { continue }
                let rawEnd = minute(record.text("end_time"))
                let end = rawEnd.map { $0 <= start ? $0 + 1440 : $0 }
                entries.append(.init(id: source + ":" + String(record.integer("id")) + ":" + record.text("day"), record: record, source: source, start: start, end: end))
            }
        }
        for record in previousEvents {
            guard let start = minute(record.text("start_time")), let end = minute(record.text("end_time")), end <= start, end > 0 else { continue }
            entries.append(.init(id: "carry-event:" + String(record.integer("id")) + ":" + record.text("day"), record: record, source: "event", start: 0, end: end))
        }
        if let shift, let start = minute(String(shift.time.prefix(5))), let end = minute(String(shift.time.suffix(5))) {
            entries.append(.init(id: "shift:current", record: ["title": .string(shift.title), "kind": .string(shift.rawValue)], source: "shift", start: start, end: end <= start ? end + 1440 : end))
        }
        if previousShift == .night {
            entries.append(.init(id: "shift:previous", record: ["title": .string("Notte · da ieri"), "kind": .string("night")], source: "shift", start: 0, end: 360))
        }
        return nested(entries)
    }
    /// Choose the smallest containing interval. Equal intervals remain siblings;
    /// crossing overlaps remain visible in chronological order without false nesting.
    static func nested(_ entries: [NativeCalendarAgendaEntry]) -> [NativeCalendarAgendaNode] {
        let sorted = entries.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.intervalEnd != $1.intervalEnd { return $0.intervalEnd > $1.intervalEnd }
            return $0.id < $1.id
        }
        var parents: [Int: Int] = [:]
        for index in sorted.indices {
            let item = sorted[index]
            let containers = (0..<index).filter { candidate in
                let parent = sorted[candidate]
                return parent.start <= item.start && parent.intervalEnd >= item.intervalEnd
                    && (parent.start < item.start || parent.intervalEnd > item.intervalEnd)
            }
            parents[index] = containers.min { a, b in
                let left = sorted[a].intervalEnd - sorted[a].start, right = sorted[b].intervalEnd - sorted[b].start
                return left == right ? a < b : left < right
            }
        }
        let children = Dictionary(grouping: sorted.indices.filter { parents[$0] != nil }, by: { parents[$0]! })
        func node(_ index: Int) -> NativeCalendarAgendaNode {
            .init(entry: sorted[index], children: (children[index] ?? []).map(node))
        }
        return sorted.indices.filter { parents[$0] == nil }.map(node)
    }
}
