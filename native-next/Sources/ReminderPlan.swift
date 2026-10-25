import Foundation

struct LifeReminder: Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
    let route: String
}
enum ReminderPlan {
    static func make(life: Record, now: Date = Date()) -> [LifeReminder] {
        func date(_ day: String, _ clock: String) -> Date? {
            guard day.count == 10, CivilDate.day(CivilDate.date(day)) == day else { return nil }
            let parts = clock.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
            return CivilDate.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: CivilDate.date(day))
        }
        var result: [LifeReminder] = []
        for task in life.records("tasks") where task.text("status") == "todo" {
            if let due = date(task.text("scheduled_date", fallback: task.text("due_date")), task.text("scheduled_time", fallback: "09:00")), due > now {
                result.append(LifeReminder(id: "task-\(task.integer("id"))", title: "Attività in scadenza", body: task.text("title"), date: due, route: NativeReminderTarget(kind: .task, id: task.integer("id")).route))
            }
        }
        for shift in life.records("shifts") {
            let start = ["morning": "06:00", "afternoon": "14:00", "night": "22:00"][shift.text("kind")]
            if let start, let time = date(shift.text("day"), start)?.addingTimeInterval(-3600), time > now {
                result.append(LifeReminder(id: "shift-" + shift.text("day"), title: "Turno tra un’ora", body: "Il tuo turno inizia alle " + start, date: time, route: NativeReminderTarget(kind: .day, day: shift.text("day")).route))
            }
        }
        // The API supplies expanded upcoming occurrences; in demo use the base events.
        let events = life.records("events") + life.records("upcomingEvents")
        for event in events where event.text("occurrence_status", fallback: "open") == "open" {
            if let time = date(event.text("day"), event.text("start_time", fallback: "09:00"))?.addingTimeInterval(-900), time > now {
                result.append(LifeReminder(id: "event-\(event.integer("id"))-" + event.text("day"), title: "Evento tra 15 minuti", body: event.text("title"), date: time, route: NativeReminderTarget(kind: .event, id: event.integer("id"), day: event.text("day")).route))
            }
        }
        // Leave room in the system scheduler. Opening the app replenishes the plan.
        var unique = Set<String>()
        return Array(result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }.filter { unique.insert($0.id).inserted }.prefix(48))
    }
}
