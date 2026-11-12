import Foundation

enum NativeNutritionHistory {
    struct Day: Identifiable {
        let date: Date
        let entries: [NativeNutritionEntry]
        var id: Date { date }
    }

    static func days(_ entries: [NativeNutritionEntry], calendar: Calendar = .current) -> [Day] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .map { Day(date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    static func foods(on date: Date, entries: [NativeNutritionEntry], calendar: Calendar = .current) -> [NativeNutritionEntry] {
        entries.filter {
            ($0.confirmed || $0.deletionPending == true)
                && calendar.isDate($0.date, inSameDayAs: date)
                && !($0.foodName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }.sorted { $0.date > $1.date }
    }
}
