import Foundation

/// Only absolute setters with stable server keys may be replayed. Creation/deletion
/// APIs remain server-confirmed until the backend supplies an idempotency contract.
enum LocalLifeMutation {
    private static func validDay(_ day: String) -> Bool { day.count == 10 && CivilDate.day(CivilDate.date(day)) == day }
    static func supports(_ method: String) -> Bool {
        ["setTaskStatus", "setRoutineCheck", "paintShift", "saveHealthEntry", "setEventOccurrence"].contains(method)
    }
    static func key(_ write: PendingWrite) -> String {
        switch write.method {
        case "paintShift", "saveHealthEntry": return write.method + ":" + write.payload.text("day")
        case "setRoutineCheck", "setEventOccurrence": return write.method + ":" + String(write.payload.integer("id")) + ":" + write.payload.text("day")
        case "setTaskStatus": return write.method + ":" + String(write.payload.integer("id"))
        default: return write.id
        }
    }
    static func apply(_ method: String, _ p: Record, to life: inout Record) throws {
        switch method {
        case "setTaskStatus":
            guard p.integer("id") > 0, ["todo", "done", "waiting"].contains(p.text("status")) else { throw Message(text: "Stato attività non valido.") }
            var rows = life.records("tasks")
            if let i = rows.firstIndex(where: { $0.integer("id") == p.integer("id") }) { if p.text("status") == "done" { rows[i]["section_status"] = .string(NativeTaskList.section(rows[i])) }
                else { rows[i]["section_status"] = p["status"] }
                rows[i]["status"] = p["status"] }
            life["tasks"] = .array(rows.map(JSONValue.object))
        case "setRoutineCheck":
            guard p.integer("id") > 0, validDay(p.text("day")) else { throw Message(text: "Abitudine o data non valida.") }
            // An old pending check still syncs to its own day, never to today's UI.
            if p.text("day") == CivilDate.day() {
                var rows = life.records("routines")
                if let i = rows.firstIndex(where: { $0.integer("id") == p.integer("id") }) { rows[i]["checked"] = .int(p.flag("checked") ? 1 : 0) }
                life["routines"] = .array(rows.map(JSONValue.object))
            }
        case "paintShift":
            guard validDay(p.text("day")), ShiftKind(rawValue: p.text("kind")) != nil else { throw Message(text: "Turno o data non valido.") }
            var rows = life.records("shifts").filter { $0.text("day") != p.text("day") }
            if p.text("kind") != "erase" { rows.append(p) }
            life["shifts"] = .array(rows.map(JSONValue.object))
        case "setEventOccurrence":
            guard p.integer("id") > 0, validDay(p.text("day")), ["open", "done"].contains(p.text("status")) else { throw Message(text: "Occorrenza non valida.") }
            for key in ["events", "upcomingEvents", "activityEvents"] {
                life[key] = .array(life.records(key).map { event in
                    var row = event
                    if row.integer("id") == p.integer("id") && row.text("day") == p.text("day") { row["occurrence_status"] = p["status"] }
                    return .object(row)
                })
            }
            var occurrences = life.record("occurrences")
            let key = "\(p.integer("id")):\(p.text("day"))"
            if p.text("status") == "open" { occurrences.removeValue(forKey: key) } else { occurrences[key] = p["status"] }
            life["occurrences"] = .object(occurrences)
        case "saveHealthEntry":
            let valid = try HealthMeasurement.payload(day: p.text("day"), weight: p["weightKg"] == nil ? "" : String(p.amount("weightKg")), calories: p["calories"] == nil ? "" : String(p.amount("calories")))
            var rows = life.records("health")
            var row = rows.first { $0.text("day") == p.text("day") } ?? ["day": p["day"]!]
            if let kg = valid["weightKg"] { row["weight_kg"] = kg }
            if let kcal = valid["calories"] { row["calories"] = kcal }
            rows.removeAll { $0.text("day") == p.text("day") }; rows.append(row)
            life["health"] = .array(rows.sorted { $0.text("day") < $1.text("day") }.map(JSONValue.object))
        default: throw Message(text: "Questa operazione richiede la conferma del server.")
        }
    }
}
