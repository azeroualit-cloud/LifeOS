import Foundation

extension NativeRoutineSchedule {
    /// Next day the habit is due, today included unless already ticked today
    /// (habits list shows "Prossima" instead of the start date, Nas 18 nov).
    static func nextDue(_ routine: Record, today: String = CivilDate.day()) -> String? {
        let start = routine.flag("checked") && due(routine, day: today) ? 1 : 0
        for offset in start...400 {
            let day = CivilDate.adding(offset, to: today)
            if due(routine, day: day) { return day }
        }
        return nil
    }

    static func nextLabel(_ routine: Record, today: String = CivilDate.day()) -> String {
        guard let day = nextDue(routine, today: today) else { return "Nessuna prossima data" }
        if day == today { return "Prossima: oggi" }
        if day == CivilDate.adding(1, to: today) { return "Prossima: domani" }
        let days = (0...400).first { CivilDate.adding($0, to: today) == day } ?? 0
        return "Prossima: " + CivilDate.label(day) + " · tra \(days) giorni"
    }
}
