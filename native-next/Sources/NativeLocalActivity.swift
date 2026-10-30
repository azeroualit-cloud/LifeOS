import Foundation

enum NativeLocalActivity {
    static func apply(_ p: Record, life: inout Record) throws {
        guard !p.text("uid").isEmpty, !p.text("title").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, p.integer("localID") < 0 else { throw Message(text: "Attività locale non valida.") }
        let source = p.text("source"), oldID = p.integer("sourceId"), uid = p.text("uid")
        let old = life.records(source == "event" ? "events" : "tasks").first { $0.integer("id") == oldID }
        func matches(_ row: Record, kind: String) -> Bool {
            row.text("activity_uid") == uid || (kind == source && oldID > 0 && row.integer("id") == oldID)
        }
        for key in ["tasks", "events", "upcomingEvents", "activityEvents"] {
            life[key] = .array(life.records(key).filter { !matches($0, kind: key == "tasks" ? "task" : "event") }.map(JSONValue.object))
        }
        var row = p
        row["id"] = (oldID > 0 && (p.text("day").isEmpty ? "task" : "event") == source) ? .int(oldID) : p["localID"]; row["activity_uid"] = .string(uid); row["pending"] = .bool(true)
        if p.text("day").isEmpty {
            row["activity_source"] = .string("task"); row["scheduled_date"] = .null
            row["status"] = p.flag("statusIntent") ? .string(p.text("taskStatus", fallback: "todo")) : old?["status"] ?? .string(p.flag("completed") ? "done" : "todo")
            row["sort_order"] = old?["sort_order"] ?? .int(life.records("tasks").count + 1)
            life["tasks"] = .array((life.records("tasks") + [row]).map(JSONValue.object))
        } else {
            row["activity_source"] = .string("event"); row["series_day"] = p["day"]
            row["occurrence_status"] = .string(p.flag("completed") ? "done" : "open")
            for key in ["events", "upcomingEvents", "activityEvents"] {
                life[key] = .array((life.records(key) + [row]).map(JSONValue.object))
            }
        }
    }
}
