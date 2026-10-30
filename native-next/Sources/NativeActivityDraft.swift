import Foundation

enum NativeActivityDraft {
    static func validate(_ p: Record) throws {
        let title = p.text("title").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.text("uid").isEmpty, !title.isEmpty, title.count <= 140, p.text("notes").count <= 1000, p.text("location").count <= 160 else { throw Message(text: "Controlla titolo (massimo 140 caratteri), descrizione (1000) e luogo (160).") }
        for key in ["day", "due_date", "until_day"] {
            let value = p.text(key)
            guard value.isEmpty || NativeRoutineSchedule.validDay(value) else { throw Message(text: "Data non valida.") }
        }
        for key in ["start_time", "end_time", "scheduled_time"] {
            let value = p.text(key), parts = value.split(separator: ":")
            guard value.isEmpty || (value.count == 5 && parts.count == 2 && Int(parts[0]).map { (0...23).contains($0) } == true && Int(parts[1]).map { (0...59).contains($0) } == true) else { throw Message(text: "Orario non valido.") }
        }
        let day = p.text("day"), due = p.text("due_date"), until = p.text("until_day")
        guard day.isEmpty || due.isEmpty || due >= day, day.isEmpty || until.isEmpty || until >= day,
              p.text("end_time").isEmpty || (!p.text("start_time").isEmpty && p.text("end_time") >= p.text("start_time")) else { throw Message(text: "Controlla inizio e fine.") }
        guard ["none", "weekly", "monthly", "yearly"].contains(p.text("frequency", fallback: "none")) else { throw Message(text: "Ripetizione non valida.") }
    }
}
