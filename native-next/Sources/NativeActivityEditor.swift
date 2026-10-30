import SwiftUI

/// One editor and one identity. Date presence determines the presentation as task or event.
struct NativeActivityEditor: View {
    @EnvironmentObject private var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let record: Record
    let source: String
    @State private var title = ""
    @State private var notes = ""
    @State private var location = ""
    @State private var category = "action"
    @State private var hasDate = false
    @State private var date = Date()
    @State private var hasDue = false
    @State private var due = Date()
    @State private var hasTime = false
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var frequency = "none"
    @State private var hasUntil = false
    @State private var until = Date()
    @State private var fromHere = false
    @State private var saving = false
    @State private var failure: String?
    @State private var deleteSeries = false
    @State private var identity = UUID().uuidString
    var body: some View {
        ScrollViewReader { scroll in
            Form {
                Section {
                    TextField("Titolo", text: $title).accessibilityIdentifier("activity-title")
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                        Text("Descrizione").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                        TextEditor(text: $notes).frame(minHeight: NativeDesign.Layout.activityDescriptionHeight).accessibilityLabel("Descrizione")
                    }
                    HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                        dateField("Inizio", enabled: $hasDate, date: $date)
                        dateField("Scadenza", enabled: $hasDue, date: $due)
                    }.id("dates")
                }
                Section {
                    Picker("Categoria", selection: $category) {
                        ForEach(store.categories.map { DisplayRecord($0, key: "key") }) { item in Text(item.value.text("label")).tag(item.value.text("key")) }
                    }
                    TextField("Luogo", text: $location)
                }
                if hasDate || hasDue {
                    Section("Orario") {
                        Toggle(hasDate ? "Ora iniziale" : "Orario promemoria", isOn: $hasTime)
                        if hasTime {
                            DatePicker("Inizio", selection: $start, displayedComponents: .hourAndMinute)
                            if hasDate {
                                Toggle("Ora finale", isOn: $hasEnd)
                                if hasEnd { DatePicker("Fine", selection: $end, displayedComponents: .hourAndMinute) }
                            }
                        }
                    }.id("time")
                }
                if hasDate {
                    Section("Ripetizione") {
                        Picker("Frequenza", selection: $frequency) {
                            Text("Mai").tag("none"); Text("Ogni settimana").tag("weekly"); Text("Ogni mese").tag("monthly"); Text("Ogni anno").tag("yearly")
                        }
                        if frequency != "none" {
                            Toggle("Data finale", isOn: $hasUntil)
                            if hasUntil { DatePicker("Fino al", selection: $until, in: date..., displayedComponents: .date) }
                        }
                        if source == "event", record.integer("id") > 0, record.text("frequency", fallback: "none") != "none" {
                            Toggle("Modifica da questa occorrenza", isOn: $fromHere)
                            Text("Le occorrenze precedenti restano nello storico.").font(.caption).foregroundStyle(NativeDesign.secondary)
                        }
                    }.id("repeat")
                }
                if record.integer("id") > 0, source == "event" {
                    Section {
                        Button(record.text("occurrence_status") == "done" ? "Riapri questa occorrenza" : "Segna fatta questa occorrenza") {
                            Task { await store.run("setEventOccurrence", ["id": .int(record.integer("id")), "day": .string(record.text("day")), "status": .string(record.text("occurrence_status") == "done" ? "open" : "done")]); if store.error == nil { dismiss() } }
                        }
                        Button("Elimina solo questa occorrenza", role: .destructive) {
                            Task { await store.run("setEventOccurrence", ["id": .int(record.integer("id")), "day": .string(record.text("day")), "status": .string("skipped")]); if store.error == nil { dismiss() } }
                        }
                        Button("Elimina intera serie", role: .destructive) { deleteSeries = true }
                    }.id("actions")
                }
                if let failure { NativeInlineMessage(text: failure) }
            }.modifier(NativeListAppearance())
                .navigationTitle(record.integer("id") != 0 ? "Modifica attività" : "Nuova attività").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { Task { await save() } }.disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .onAppear(perform: load)
                .onChange(of: fromHere) { _, value in date = CivilDate.date(value ? record.text("day") : record.text("series_day", fallback: record.text("day"))) }
                .task {
                    if !record.text("_editorSection").isEmpty { await Task.yield(); scroll.scrollTo(record.text("_editorSection") == "reminder" ? "time" : record.text("_editorSection"), anchor: .center) }
                }
                .confirmationDialog("Eliminare la serie e tutti gli stati delle occorrenze?", isPresented: $deleteSeries, titleVisibility: .visible) {
                    Button("Elimina serie", role: .destructive) { Task { await store.run("deleteEvent", args: [.int(record.integer("id"))]); if store.error == nil { dismiss() } } }
                }
        }
    }
    private func dateField(_ title: String, enabled: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Button { enabled.wrappedValue.toggle() } label: {
                Label(title, systemImage: enabled.wrappedValue ? "checkmark.circle.fill" : "plus.circle").font(.subheadline)
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
            }.buttonStyle(.plain).accessibilityValue(enabled.wrappedValue ? "Attiva" : "Nessuna data")
            if enabled.wrappedValue { DatePicker(title, selection: date, displayedComponents: .date).datePickerStyle(.compact).labelsHidden() }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func load() {
        title = record.text("title"); notes = record.text("notes"); location = record.text("location")
        category = record.text("list_kind", fallback: "action")
        if !store.categories.contains(where: { $0.text("key") == category }) { category = store.categories.first?.text("key") ?? "action" }
        let day = source == "event" ? record.text("series_day", fallback: record.text("day")) : record.text("scheduled_date")
        hasDate = !day.isEmpty; date = CivilDate.date(day.isEmpty ? CivilDate.day() : day)
        hasDue = !record.text("due_date").isEmpty; due = CivilDate.date(record.text("due_date", fallback: CivilDate.day()))
        let time = record.text("start_time", fallback: record.text("scheduled_time"))
        hasTime = !time.isEmpty; start = clockDate(time.isEmpty ? "09:00" : time)
        hasEnd = !record.text("end_time").isEmpty; end = clockDate(record.text("end_time", fallback: "10:00"))
        frequency = record.text("frequency", fallback: "none")
        hasUntil = !record.text("until_day").isEmpty; until = CivilDate.date(record.text("until_day", fallback: CivilDate.adding(365, to: CivilDate.day())))
        if record.integer("id") != 0 { identity = record.text("activity_uid", fallback: source + ":" + String(record.integer("id"))) }
        if ["time", "reminder"].contains(record.text("_editorSection")) { hasTime = true; if !hasDate && !hasDue { hasDue = true } }
    }
    private func clockDate(_ value: String) -> Date {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return CivilDate.calendar.date(bySettingHour: parts.first ?? 9, minute: parts.last ?? 0, second: 0, of: Date()) ?? Date()
    }
    private func clock(_ value: Date) -> String { String(format: "%02d:%02d", CivilDate.calendar.component(.hour, from: value), CivilDate.calendar.component(.minute, from: value)) }
    private func save() async {
        saving = true; defer { saving = false }
        var p: Record = ["uid": .string(identity), "source": .string(source), "sourceId": .int(max(0, record.integer("id"))), "title": .string(title), "notes": .string(notes), "location": .string(location), "list_kind": .string(category), "day": hasDate ? .string(CivilDate.day(date)) : .null, "due_date": hasDue ? .string(CivilDate.day(due)) : .null, "start_time": hasDate && hasTime ? .string(clock(start)) : .null, "end_time": hasDate && hasTime && hasEnd ? .string(clock(end)) : .null, "scheduled_time": hasTime && (hasDate || hasDue) ? .string(clock(start)) : .null, "frequency": .string(frequency), "until_day": hasUntil ? .string(CivilDate.day(until)) : .null, "completed": .bool(record.text("status") == "done" || record.text("occurrence_status") == "done")]
        do {
            if hasDate && hasDue && CivilDate.day(due) < CivilDate.day(date) { throw Message(text: "La scadenza deve seguire la data iniziale.") }
            if fromHere {
                guard hasDate else { throw Message(text: "Mantieni la data per separare questa occorrenza dalla serie.") }
                p["id"] = record["id"]; p["split_from"] = record["day"]
                try await store.perform("splitEventSeries", p)
            } else { try await store.perform("saveActivity", p) }
            NotificationCenter.default.post(name: .nativeTaskEditorSaved, object: record.integer("id"))
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}
