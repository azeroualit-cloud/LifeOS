import SwiftUI
import UserNotifications
import LocalAuthentication

// MARK: - TIMES-MONTH-CALENDAR-2026-11-24

/// The times of every day of a month, with the same neutral labels as the «Orari» sheet.
struct NativeTimesMonthScreen: View {
    @State private var month = CivilDate.month()

    var body: some View {
        let days = Self.days(of: month), today = CivilDate.day()
        let labels = NativeNextTime.schedule(day: days.first ?? today).map(\.label)
        List {
            Section {
                ForEach(days, id: \.self) { day in
                    let times = NativeNextTime.schedule(day: day)
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        HStack(spacing: NativeDesign.Space.small) {
                            Text(CivilDate.agendaTitle(day)).font(.subheadline.weight(day == today ? .bold : .semibold))
                                .foregroundStyle(day == today ? NativeDesign.calendarTitle : .primary)
                            ForEach(NativeIslamicDays.events(on: day), id: \.self) { NativeIslamicTag(title: $0) }
                        }
                        Grid(alignment: .leading, horizontalSpacing: NativeDesign.Space.small, verticalSpacing: NativeDesign.Space.xxs) {
                            GridRow {
                                ForEach(Array(times.prefix(3).enumerated()), id: \.offset) { _, time in cell(time) }
                            }
                            GridRow {
                                ForEach(Array(times.dropFirst(3).prefix(3).enumerated()), id: \.offset) { _, time in cell(time) }
                            }
                        }
                    }
                    .padding(.vertical, NativeDesign.Space.xxs)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("times-month-" + day)
                }
            } footer: {
                Text("Empoli · orari indicativi calcolati sul dispositivo. Colonne: " + labels.joined(separator: ", ") + ".")
            }
        }
        .modifier(NativeListAppearance())
        .navigationTitle(CivilDate.monthTitle(month))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { month = Self.shift(month, -1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Mese precedente")
                Button { month = Self.shift(month, 1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Mese successivo")
            }
        }
        .accessibilityIdentifier("times-month")
    }

    private func cell(_ time: (label: String, time: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(time.label).font(.caption2).foregroundStyle(NativeDesign.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Text(time.time).font(.footnote.weight(.medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func days(of month: String) -> [String] {
        let first = month + "-01"
        return (0..<31).map { CivilDate.adding($0, to: first) }.filter { $0.hasPrefix(month) }
    }
    static func shift(_ month: String, _ count: Int) -> String {
        String(CivilDate.adding(count, to: month + "-01", component: .month).prefix(7))
    }
}

// MARK: - CALENDAR-RAMADAN-EID-2026-11-24 (explicit names, user's choice)

enum NativeIslamicDays {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = TimeZone(identifier: "Europe/Rome") ?? .current
        return c
    }()
    private static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var g = Calendar(identifier: .gregorian); g.timeZone = calendar.timeZone
        return g.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// «Inizio Ramadan», «Fine Ramadan», «Eid al-Fitr», «Eid al-Adha» on the matching days.
    static func events(on day: String) -> [String] {
        guard let date = date(day), let next = date(CivilDate.adding(1, to: day)) else { return [] }
        let h = calendar.dateComponents([.month, .day], from: date), n = calendar.dateComponents([.month], from: next)
        var out: [String] = []
        if h.month == 9 && h.day == 1 { out.append("Inizio Ramadan") }
        if h.month == 9 && n.month == 10 { out.append("Fine Ramadan") }
        if h.month == 10 && h.day == 1 { out.append("Eid al-Fitr") }
        if h.month == 12 && h.day == 10 { out.append("Eid al-Adha") }
        return out
    }

    /// Reminder at 20:00 the evening before each date of the next 400 days.
    static func scheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("hijri95-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let today = CivilDate.day()
        for offset in 1...400 {
            let day = CivilDate.adding(offset, to: today)
            for title in events(on: day) {
                let eve = CivilDate.adding(-1, to: day).split(separator: "-").compactMap { Int($0) }
                guard eve.count == 3 else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Domani: " + title
                content.body = CivilDate.agendaTitle(day)
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(year: eve[0], month: eve[1], day: eve[2], hour: 20, minute: 0), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "hijri95-" + day + "-" + title, content: content, trigger: trigger))
            }
        }
    }
}

struct NativeIslamicTag: View {
    let title: String
    var body: some View {
        Text(title).font(.caption2.weight(.semibold))
            .padding(.horizontal, NativeDesign.Space.small).padding(.vertical, NativeDesign.Space.xxs)
            .foregroundStyle(NativeDesign.nutritionTitle)
            .background(NativeDesign.nutritionTitle.opacity(0.16), in: Capsule())
            .accessibilityIdentifier("calendar-hijri")
    }
}

// MARK: - CALENDAR-PRIVATE-ENTRY-2026-11-24

struct NativePrivateDay: Identifiable { let day: String; var id: String { day } }

/// Private notes of a day, saved only in the user's server setting «private-log».
/// The calendar shows nothing but a neutral «Privato» button; the summary opens with Face ID / code.
struct NativePrivateDaySheet: View {
    @EnvironmentObject private var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let day: String
    @State private var entries: [Record] = []
    @State private var modified: Double = 0
    @State private var person = ""
    @State private var note = ""
    @State private var unlocked = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section(CivilDate.agendaTitle(day)) {
                    let list = entries.filter { $0.text("day") == day }
                    if list.isEmpty { Text("Nessuna nota privata in questo giorno.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                    ForEach(Array(list.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(entry.text("person", fallback: "—")).font(.headline)
                            if !entry.text("note").isEmpty { Text(entry.text("note")).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                        }
                        .swipeActions { Button("Elimina", role: .destructive) { Task { await save(entries.filter { $0.text("id") != entry.text("id") }) } } }
                    }
                }
                Section("Aggiungi") {
                    TextField("Con chi", text: $person).textInputAutocapitalization(.words).accessibilityIdentifier("private-person")
                    if !people.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: NativeDesign.Space.small) {
                                ForEach(people, id: \.self) { name in
                                    Button { person = name } label: {
                                        Text(name).font(.footnote).padding(.horizontal, NativeDesign.Space.small)
                                            .frame(minHeight: NativeDesign.Layout.compactControl).modifier(NativeGlass())
                                    }.buttonStyle(NativePressStyle())
                                }
                            }
                        }
                    }
                    TextField("Nota (facoltativa)", text: $note).accessibilityIdentifier("private-note")
                    Button("Aggiungi") {
                        let entry: Record = ["id": .string(UUID().uuidString), "day": .string(day), "person": .string(person.trimmingCharacters(in: .whitespaces))]
                            .merging(note.isEmpty ? [:] : ["note": .string(note)]) { a, _ in a }
                        Task { await save(entries + [entry]); person = ""; note = "" }
                    }.disabled(person.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("private-add")
                }
                Section("Riepilogo") {
                    if unlocked {
                        ForEach(summary, id: \.name) { row in
                            LabeledContent(row.name, value: "\(row.year) quest'anno · \(row.total) in tutto")
                        }
                        if summary.isEmpty { Text("Ancora nessuna nota.").font(.footnote) }
                    } else {
                        Button("Mostra il riepilogo") { unlock() }.accessibilityIdentifier("private-unlock")
                    }
                }
                if let message { Section { NativeInlineMessage(text: message) } }
                Section { Text("Visibile solo a te. Nel calendario non compare nessun testo.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
            }
            .modifier(NativeListAppearance())
            .navigationTitle("Privato").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() } } }
            .task { await load() }
        }
        .accessibilityIdentifier("private-sheet")
    }

    private var people: [String] { Array(Set(entries.map { $0.text("person") }.filter { !$0.isEmpty })).sorted() }
    private var summary: [(name: String, year: Int, total: Int)] {
        let year = String(day.prefix(4))
        return Dictionary(grouping: entries, by: { $0.text("person", fallback: "—") })
            .map { (name: $0.key, year: $0.value.filter { $0.text("day").hasPrefix(year) }.count, total: $0.value.count) }
            .sorted { $0.total > $1.total }
    }

    private func load() async {
        guard !store.isDemo else { return }
        do {
            let r = try await store.read("getSettings", args: [.string("private-log")]).object
            entries = r.record("doc").records("entries"); modified = r.amount("modified")
        } catch { message = "Note private non disponibili: aggiorna il server." }
    }
    private func save(_ list: [Record]) async {
        if store.isDemo { entries = list; return }
        let when = max(Date().timeIntervalSince1970 * 1000, modified + 1)
        do {
            let r = try await store.read("saveSettings", args: [.string("private-log"), .object(["entries": .array(list.map(JSONValue.object))]), .number(when)]).object
            entries = r.record("doc").records("entries"); modified = r.amount("modified"); message = nil
        } catch { message = error.localizedDescription }
    }
    private func unlock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { unlocked = true; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Mostra il riepilogo privato") { ok, _ in
            Task { @MainActor in unlocked = ok }
        }
    }
}
