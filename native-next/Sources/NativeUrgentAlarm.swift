import SwiftUI
import AlarmKit

/// Alarms are explicitly opted into on this iPhone, never silently enabled by server data.
@MainActor enum NativeUrgentAlarm {
    struct Entry: Codable, Equatable {
        var id: UUID
        var identity: String
        var day: String
        var title: String
        var date: Date
    }
    private static let storageKey = "lifeos.urgent-alarms.v1"
    static var entries: [Entry] {
        get { (try? JSONDecoder().decode([Entry].self, from: UserDefaults.standard.data(forKey: storageKey) ?? Data())) ?? [] }
        set { if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: storageKey) } }
    }
    static func enabled(identity: String) -> Bool {
        guard #available(iOS 26.0, *), let entry = entries.first(where: { $0.identity == identity && $0.date > Date() }) else { return false }
        return (try? AlarmManager.shared.alarms.contains { $0.id == entry.id }) == true
    }
    static func date(day: String, time: String) -> Date? {
        guard NativeRoutineSchedule.validDay(day), time.count == 5 else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return CivilDate.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: CivilDate.date(day))
    }
    static func set(identity: String, enabled: Bool, day: String, time: String, title: String) async throws {
        guard #available(iOS 26.0, *) else {
            if enabled { throw Message(text: "La sveglia urgente richiede iOS 26 o successivo.") }
            return
        }
        if !enabled { try cancel(identity: identity); return }
        guard let date = date(day: day, time: time), date > Date() else { throw Message(text: "La sveglia richiede una data e un’ora future.") }
        guard try await AlarmManager.shared.requestAuthorization() == .authorized else { throw Message(text: "Sveglie non autorizzate. Abilitale nelle impostazioni di iPhone.") }
        let old = entries.first { $0.identity == identity }
        let id = old?.id ?? UUID()
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), stopButton: AlarmButton(text: "Ferma", textColor: .white, systemImageName: "stop.circle"))
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: NativeEventAlarmMetadata(), tintColor: NativeDesign.healthAccent)
        let configuration = AlarmManager.AlarmConfiguration(schedule: .fixed(date), attributes: attributes)
        // The public API schedules a new alarm; don't assume replacement semantics.
        // Cancel the old UUID first, then schedule it again so edits cannot duplicate it.
        let existing = try AlarmManager.shared.alarms
        if existing.contains(where: { $0.id == id }) { try AlarmManager.shared.cancel(id: id) }
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        entries = entries.filter { $0.identity != identity } + [Entry(id: id, identity: identity, day: day, title: title, date: date)]
    }
    static func cancel(identity: String) throws {
        guard #available(iOS 26.0, *) else { return }
        let matches = entries.filter { $0.identity == identity }
        guard !matches.isEmpty else { return }
        let alarms = try AlarmManager.shared.alarms
        for entry in matches where alarms.contains(where: { $0.id == entry.id }) { try AlarmManager.shared.cancel(id: entry.id) }
        entries = entries.filter { $0.identity != identity }
    }
    /// Only records actually present in a snapshot are authoritative; browsing another
    /// month must never cancel an alarm because that month's event isn't loaded.
    static func reconcile(life: Record) async throws {
        guard #available(iOS 26.0, *) else { return }
        let events = life.records("events") + life.records("activityEvents") + life.records("upcomingEvents")
        for entry in entries {
            let match: (Record) -> Bool = { $0.text("activity_uid", fallback: "event:" + String($0.integer("id"))) == entry.identity }
            if life.records("tasks").contains(where: match) { try cancel(identity: entry.identity); continue }
            guard let record = events.first(where: { match($0) && $0.text("day") == entry.day }) ?? events.first(where: match) else { continue }
            let status = life.record("occurrences").text("\(record.integer("id")):\(entry.day)", fallback: record.text("occurrence_status", fallback: "open"))
            if status != "open" { try cancel(identity: entry.identity); continue }
            // Urgent alarms are single-event only, as explained in the editor.
            guard record.text("frequency", fallback: "none") == "none" else { try cancel(identity: entry.identity); continue }
            guard let next = date(day: record.text("day"), time: record.text("start_time")), next > Date() else { try cancel(identity: entry.identity); continue }
            if next != entry.date || record.text("title") != entry.title {
                try await set(identity: entry.identity, enabled: true, day: record.text("day"), time: record.text("start_time"), title: record.text("title"))
            }
        }
    }
}
@available(iOS 26.0, *) private struct NativeEventAlarmMetadata: AlarmMetadata { }

/// An editor owns scheduling while open. Reconcile after dismissal so a local
/// save and its system alarm are not scheduled concurrently by the root view.
struct NativeUrgentAlarmSource: Equatable {
    let content: Record
    let editing: Bool
    init(life: Record, editing: Bool) {
        self.editing = editing
        content = life.filter { ["events", "activityEvents", "upcomingEvents", "tasks", "occurrences"].contains($0.key) }
    }
}
