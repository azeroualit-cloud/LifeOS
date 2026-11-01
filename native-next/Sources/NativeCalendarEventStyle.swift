import SwiftUI

/// Stable across launches, completion, date edits and recurring occurrences.
/// Categories share a colour; uncategorised activities retain their own identity.
enum NativeCalendarEventStyle {
    static func paletteIndex(for entry: NativeCalendarAgendaEntry) -> Int {
        let category = entry.record.text("list_kind").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key: String
        if !category.isEmpty && category != "action" {
            key = "category:" + category
        } else {
            let uid = entry.record.text("uid")
            key = uid.isEmpty ? entry.source + ":" + String(entry.record.integer("id")) : uid
        }
        // Swift Hasher is randomised per process and would change colours on launch.
        return Int(key.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) } % 6)
    }
    static func color(for entry: NativeCalendarAgendaEntry) -> Color {
        let palette: [Color] = [.init(uiColor: .systemTeal), .init(uiColor: .systemIndigo), .init(uiColor: .systemOrange), .init(uiColor: .systemPink), .init(uiColor: .systemGreen), .init(uiColor: .systemPurple)]
        return palette[paletteIndex(for: entry)]
    }
}
