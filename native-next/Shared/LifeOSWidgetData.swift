import Foundation

/// Minimal read-only projection: never includes finance, HealthKit, notes or credentials.
struct LifeOSWidgetDay: Codable, Equatable, Identifiable {
    var day: String
    var shift: String?
    var routines: Int
    var checked: Int
    var tasks: Int
    var events: Int
    var nextTitle: String?
    var id: String { day }
}
struct LifeOSWidgetSnapshot: Codable, Equatable {
    var version = 1
    var generatedAt: Date
    var demo: Bool
    var days: [LifeOSWidgetDay]
    var ready = true
    func week(at date: Date) -> [LifeOSWidgetDay] {
        let today = LifeOSWidgetCalendar.day(date)
        return Array(days.filter { $0.day >= today }.prefix(7))
    }
    func isStale(at date: Date) -> Bool {
        date.timeIntervalSince(generatedAt) > 6 * 3600 || LifeOSWidgetCalendar.day(date) != LifeOSWidgetCalendar.day(generatedAt)
    }
}
enum LifeOSWidgetCalendar {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Rome")!; value.firstWeekday = 2
        return value
    }
    static func day(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func date(_ day: String) -> Date? {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        return f.date(from: day).flatMap { self.day($0) == day ? $0 : nil }
    }
    static func label(_ date: Date, format: String) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "it_IT")
        f.timeZone = calendar.timeZone; f.dateFormat = format
        return f.string(from: date)
    }
}
enum LifeOSWidgetStorage {
    static let group = "group.com.nas.lifeos"
    static let kind = "LifeOSQuickActions"
    static let filename = "lifeos-widget-v1.json"
    static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }
    static func write(_ snapshot: LifeOSWidgetSnapshot, directory: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: directory.appendingPathComponent(filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    static func read(directory: URL?, now: Date = Date()) -> LifeOSWidgetSnapshot? {
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent(filename)), data.count <= 256_000,
              let snapshot = try? JSONDecoder().decode(LifeOSWidgetSnapshot.self, from: data),
              snapshot.version == 1, snapshot.days.count == 14,
              Set(snapshot.days.map(\.day)).count == snapshot.days.count,
              snapshot.days.map(\.day) == snapshot.days.map(\.day).sorted(),
              snapshot.generatedAt <= now.addingTimeInterval(300),
              snapshot.days.allSatisfy({ LifeOSWidgetCalendar.date($0.day) != nil && $0.routines >= 0 && $0.checked >= 0 && $0.checked <= $0.routines && $0.tasks >= 0 && $0.events >= 0 }) else { return nil }
        return snapshot
    }
    static func timelineDates(now: Date, snapshot: LifeOSWidgetSnapshot?) -> [Date] {
        var result = [now]
        let calendar = LifeOSWidgetCalendar.calendar
        let today = calendar.startOfDay(for: now)
        for offset in 1...7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) { result.append(date) }
        }
        if let snapshot {
            let expiry = snapshot.generatedAt.addingTimeInterval(6 * 3600 + 1)
            if expiry > now { result.append(expiry) }
        }
        return Array(Set(result)).sorted()
    }
}
