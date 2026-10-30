import Foundation

/// Presentation of the real shift, including the previous day's overnight shift.
struct NativeDashboardFocus {
    let shift: ShiftKind?
    let phase: String
    let title: String
    let detail: String
    let interval: DateInterval?
    let workInterval: DateInterval?
    let countdownLabel: String

    var remainingText: String {
        guard let interval else { return "" }
        let minutes = max(1, Int(ceil(interval.duration / 60)))
        return minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    init(now: Date, todayShift: ShiftKind?, previousShift: ShiftKind?) {
        let calendar = CivilDate.calendar
        let day = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)
        let current = previousShift == .night && hour < 6 ? ShiftKind.night : todayShift
        shift = current == .erase ? nil : current
        title = shift?.title ?? "Turni non disponibili"
        let hours: (Int, Int)?
        switch shift {
        case .morning: hours = (6, 14)
        case .afternoon: hours = (14, 22)
        case .night: hours = (22, 6)
        default: hours = nil
        }
        guard let hours else {
            phase = "Oggi"; interval = nil; workInterval = nil; countdownLabel = ""
            detail = shift == .rest ? "Giornata di riposo" : shift == .holiday ? "Giornata di ferie" : "Apri il calendario per impostare il turno"
            return
        }
        let overnight = previousShift == .night && hour < 6
        let startDay = overnight ? calendar.date(byAdding: .day, value: -1, to: day)! : day
        let endDay = shift == .night ? calendar.date(byAdding: .day, value: 1, to: startDay)! : startDay
        let start = calendar.date(bySettingHour: hours.0, minute: 0, second: 0, of: startDay)!
        let end = calendar.date(bySettingHour: hours.1, minute: 0, second: 0, of: endDay)!
        workInterval = DateInterval(start: start, end: end)
        if now < start {
            phase = "Più tardi"; interval = DateInterval(start: now, end: start); countdownLabel = "all’inizio del turno"; detail = ""
        } else if now < end {
            phase = "Adesso"; interval = DateInterval(start: now, end: end); countdownLabel = "alla fine del turno"; detail = ""
        } else {
            phase = "Oggi"; interval = nil; countdownLabel = ""; detail = "Turno terminato · " + (shift?.time ?? "")
        }
    }
}
