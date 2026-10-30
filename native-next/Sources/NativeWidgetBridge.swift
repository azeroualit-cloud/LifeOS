import Foundation
import WidgetKit

@MainActor enum NativeWidgetBridge {
    private(set) static var lastError: String?
    static func snapshot(life: Record, demo: Bool, updatedAt: Date? = nil, now: Date = Date()) -> LifeOSWidgetSnapshot {
        let today = CivilDate.day(now)
        let routines = life.records("routines"), tasks = life.records("tasks")
        let shifts = life.records("shifts")
        let base = life.records("events")
        let expanded = demo ? base.flatMap { event -> [Record] in
            CivilDate.occurrenceDays(start: event.text("day"), frequency: event.text("frequency"), until: event.text("until_day"), low: today, high: CivilDate.adding(14, to: today)).map { day in
                var item = event; item["day"] = .string(day); return item
            }
        } : base
        let sources = expanded + life.records("upcomingEvents") + life.records("activityEvents")
        let occurrences = life.record("occurrences")
        let clock = String(format: "%02d:%02d", CivilDate.calendar.component(.hour, from: now), CivilDate.calendar.component(.minute, from: now))
        let days: [LifeOSWidgetDay] = (0..<14).map { offset in
            let day = CivilDate.adding(offset, to: today)
            let due = routines.filter { NativeRoutineSchedule.due($0, day: day) }
            var seen = Set<String>()
            let events = sources.filter {
                let status = occurrences.text("\($0.integer("id")):\(day)", fallback: $0.text("occurrence_status", fallback: "open"))
                let time = $0.text("start_time")
                return $0.text("day") == day && status == "open" && (day > today || time.isEmpty || time >= clock)
                    && seen.insert("\($0.integer("id")):\(day)").inserted
            }.sorted { ($0.text("start_time"), $0.integer("id")) < ($1.text("start_time"), $1.integer("id")) }
            let todo = tasks.filter { row in
                guard row.text("status", fallback: "todo") == "todo", row.text("list_kind", fallback: "action") == "action" else { return false }
                let planned = row.text("scheduled_date"), deadline = row.text("due_date")
                if offset == 0 { return (planned.isEmpty && deadline.isEmpty) || (!planned.isEmpty && planned <= day) || (!deadline.isEmpty && deadline <= day) }
                return planned == day || deadline == day
            }
            return LifeOSWidgetDay(day: day, shift: shifts.first { $0.text("day") == day }?.text("kind"), routines: due.count,
                checked: offset == 0 && life.text("today") == today ? due.filter { $0.flag("checked") }.count : 0,
                tasks: todo.count, events: events.count, nextTitle: events.first.map { String($0.text("title").prefix(80)) })
        }
        return LifeOSWidgetSnapshot(generatedAt: now, demo: demo, days: days, ready: demo || life["upcomingEvents"] != nil, updatedAt: demo ? now : updatedAt)
    }
    static func publish(life: Record, demo: Bool, updatedAt: Date? = nil, now: Date = Date()) {
        guard let directory = LifeOSWidgetStorage.container() else {
            lastError = "La firma attuale non consente la condivisione dei dati con il widget. Verifica App Groups nel servizio di firma."
            return
        }
        do {
            try LifeOSWidgetStorage.write(snapshot(life: life, demo: demo, updatedAt: updatedAt, now: now), directory: directory)
            lastError = nil; WidgetCenter.shared.reloadTimelines(ofKind: LifeOSWidgetStorage.kind)
        } catch { lastError = "Aggiornamento del widget non riuscito. Riapri l’app per riprovare." }
    }
    static var status: String {
        lastError ?? (LifeOSWidgetStorage.container() == nil
            ? "La condivisione del widget richiede App Groups nella firma di app ed estensione."
            : "Aggiungi Life OS alla Home: un solo widget 2×2 con turni della settimana, abitudini, impegni e aggiunta attività.")
    }
}
