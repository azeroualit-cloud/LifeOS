import Foundation

/// Notification links address the original item, never a copied activity.
struct NativeReminderTarget: Equatable {
    enum Kind: String { case task, event, day }
    let kind: Kind
    let id: Int
    let day: String
    var route: String {
        switch kind {
        case .task: return "activities?task=\(id)"
        case .event: return "calendar?event=\(id)&day=\(day)"
        case .day: return "calendar?day=\(day)"
        }
    }
    init(kind: Kind, id: Int = 0, day: String = "") { self.kind = kind; self.id = id; self.day = day }
    init?(_ url: URL) {
        guard url.scheme == "lifeos", url.user == nil, url.password == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = parts.queryItems, Set(query.map(\.name)).count == query.count else { return nil }
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        if url.host == "activities", values.count == 1, let text = values["task"], let id = Int(text), id > 0 {
            self.init(kind: .task, id: id); return
        }
        guard url.host == "calendar", let day = values["day"], NativeRoutineSchedule.validDay(day) else { return nil }
        if values.count == 1 { self.init(kind: .day, day: day); return }
        guard values.count == 2, let text = values["event"], let id = Int(text), id > 0 else { return nil }
        self.init(kind: .event, id: id, day: day)
    }
}
