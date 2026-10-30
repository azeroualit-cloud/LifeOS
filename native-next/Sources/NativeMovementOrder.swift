import Foundation

/// Creation time is not the accounting date. Legacy records retain append order.
enum NativeMovementOrder {
    static func sorted(_ rows: [Record]) -> [Record] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return rows.enumerated().map { index, row in
            (row: row, time: formatter.date(from: row.text("created_at")) ?? plain.date(from: row.text("created_at")), index: index)
        }.sorted { a, b in
            if a.time != b.time { return (a.time ?? .distantPast) > (b.time ?? .distantPast) }
            if a.row.integer("row") != b.row.integer("row") { return a.row.integer("row") > b.row.integer("row") }
            return a.index < b.index
        }.map(\.row)
    }
}
