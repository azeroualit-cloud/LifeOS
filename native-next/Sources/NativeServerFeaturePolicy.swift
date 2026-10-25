import Foundation

/// Do not report a save as successful when a legacy server would discard fields.
enum NativeServerFeaturePolicy {
    static func validate(_ method: String, payload: Record, life: Record, today: String = CivilDate.day()) throws {
        let capabilities = life.record("capabilities")
        if method == "saveTask", !payload.text("scheduled_time").isEmpty,
           !capabilities.flag("taskNotificationTimes"), !life.records("tasks").contains(where: { $0["scheduled_time"] != nil }) {
            throw Message(text: "Il server deve essere aggiornato per conservare l’orario del promemoria. Nessuna modifica è stata inviata; i dati inseriti restano nell’editor.")
        }
        if method == "saveRoutine", let value = payload["schedule"] {
            let schedule = try NativeRoutineSchedule(value)
            let needsSchedule = schedule.mode != "daily" || (!schedule.startDate.isEmpty && schedule.startDate > today)
            if needsSchedule && !capabilities.flag("routineSchedules") && !life.records("routines").contains(where: { $0["schedule"] != nil }) {
                throw Message(text: "Il server deve essere aggiornato per conservare questa programmazione. Nessuna modifica è stata inviata; i dati inseriti restano nell’editor.")
            }
        }
    }
}
