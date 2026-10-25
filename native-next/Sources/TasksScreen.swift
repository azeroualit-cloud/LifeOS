import SwiftUI

struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @State private var category = "action"
    @State private var editMode: EditMode = .inactive
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var expandedID: Int?
    private func rows(_ status: String) -> [Record] { NativeTaskList.rows(store.tasks, category: category, section: status) }
    private func activities(_ status: String) -> [NativeActivity] { NativeActivityCatalog.rows(tasks: store.tasks, events: store.events, category: category, section: status) }
    var body: some View {
        List {
            Section {
                HStack(spacing: NativeDesign.Space.small) {
                    Text("Categorie").font(NativeDesign.heading)
                    Spacer()
                    Button(editMode == .active ? "Fine" : "Riordina") { editMode = editMode == .active ? .inactive : .active }.font(.subheadline).disabled(store.busy).accessibilityIdentifier("reorder-tasks")
                    NativeIconButton(symbol: "folder", label: "Gestisci categorie") { router.sheet = .categories }
                }.buttonStyle(.plain).listRowSeparator(.hidden)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(store.categories.map { DisplayRecord($0, key: "key") }) { item in
                            NativeCategoryChip(title: item.value.text("label"), selected: category == item.value.text("key")) { category = item.value.text("key") }.accessibilityIdentifier("task-category-" + item.value.text("key"))
                        }
                    }
                }.listRowSeparator(.hidden)
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            Section {
                if activities("todo").isEmpty { Text("Nessuna attività attiva").foregroundStyle(NativeDesign.secondary).modifier(NativeChecklistListRow(first: true, last: true)) }
                ForEach(activities("todo")) { item in activityRow(item).moveDisabled(item.isEvent || item.completed) }
                    .onMove { indexes, destination in
                        var visible = activities("todo"); visible.move(fromOffsets: indexes, toOffset: destination)
                        let ordered = visible.filter { !$0.isEvent }.map(\.record)
                        Task { await store.run("reorderTasks", ["category": .string(category), "ids": .array(ordered.filter { $0.text("status") == "todo" }.map { .int($0.integer("id")) })]) }
                    }
            } header: { checklistHeading("Attivo") }
            if !rows("waiting").isEmpty {
                Section { ForEach(rows("waiting").map { DisplayRecord($0) }) { item in taskRow(item.value) } }
                header: { checklistHeading("In attesa") }
            }
        }
        .modifier(NativeChecklistListAppearance())
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        .animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: store.tasks)
        .onChange(of: category) { _, _ in expandedID = nil }
        
        .onAppear {
            let keys = store.categories.map { $0.text("key") }
            category = keys.contains(router.taskCategory) ? router.taskCategory : keys.first ?? "action"
            router.taskCategory = category
        }
        .onChange(of: category) { _, value in router.taskCategory = value }
        .onChange(of: router.taskCategory) { _, value in
            if store.categories.contains(where: { $0.text("key") == value }) { category = value }
        }
        .onChange(of: store.categories.map { $0.text("key") }) { _, keys in if !keys.contains(category) { category = keys.first ?? "action" } }
    }
    private func checklistHeading(_ title: String) -> some View {
        NativeSectionHeader(title, titleIdentifier: "task-heading-" + title) { EmptyView() }
            .foregroundStyle(title == "In attesa" ? NativeDesign.secondary : Color.primary)
            .textCase(nil).padding(.vertical, NativeDesign.Space.small)
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    @ViewBuilder private func activityRow(_ item: NativeActivity) -> some View {
        if item.isEvent {
            NativeChecklistRow(title: item.record.text("title"), subtitle: CivilDate.label(item.record.text("day")), checked: item.completed, showsDisclosure: false, completionLabel: "Cambia completamento evento " + item.record.text("title"), onComplete: {
                Task { await store.run("setEventOccurrence", ["id": .int(item.record.integer("id")), "day": .string(item.record.text("day")), "status": .string(item.completed ? "open" : "done")]) }
            }, onOpen: { router.sheet = .event(item.record) }).listRowBackground(Color.clear)
        } else { taskRow(item.record) }
    }
    private func taskRow(_ r: Record) -> some View {
        let siblings = rows(NativeTaskList.section(r))
        let expanded = expandedID == r.integer("id")
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            if !expanded { NativeChecklistRow(title: r.text("title"), subtitle: expanded ? "" : r.text("notes"), checked: r.text("status") == "done", dueDay: r.text("due_date"), showsDisclosure: false, completionLabel: "Cambia completamento " + r.text("title"), onComplete: {
                Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.completionStatus(r))]) }
            }, onOpen: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) {
                    expandedID = expanded ? nil : r.integer("id")
                }
            })
            }
            if expanded {
                HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                    NativeCompletionButton(checked: r.text("status") == "done", label: "Cambia completamento " + r.text("title")) {
                        Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.completionStatus(r))]) }
                    }
                    NativeTaskControls(record: r) { withAnimation(reduceMotion ? nil : .snappy) { expandedID = nil } }
                }.padding(NativeDesign.Space.small).background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius)).transition(.opacity)
            }
        }
        .modifier(NativeChecklistListRow(first: siblings.first?.integer("id") == r.integer("id"), last: siblings.last?.integer("id") == r.integer("id")))
        .disabled(store.busy)
    }
}

/// Contextual editing stays under its task; full date/category editing reuses TaskEditor.
private struct NativeTaskControls: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    let record: Record
    var onClose: () -> Void
    @State private var title = ""
    @State private var notes = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack {
                TextField("Titolo", text: $title, axis: .vertical).accessibilityIdentifier("inline-task-title")
                Button(action: onClose) { Image(systemName: "chevron.up").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Chiudi comandi attività")
            }
            TextField("Aggiungi nota", text: $notes, axis: .vertical).font(.subheadline).foregroundStyle(NativeDesign.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NativeDesign.Space.small) {
                    Button { router.sheet = .task(record) } label: { Label(record.text("due_date").isEmpty ? "Data e dettagli" : record.text("due_date"), systemImage: "calendar").labelStyle(.iconOnly).frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }
                        .accessibilityIdentifier("inline-task-details")
                    Button {
                        Task { await store.run("setTaskStatus", ["id": .int(record.integer("id")), "status": .string(NativeTaskList.section(record) == "waiting" ? "todo" : "waiting")]) }
                    } label: { Image(systemName: NativeTaskList.section(record) == "waiting" ? "play" : "pause").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel(NativeTaskList.section(record) == "waiting" ? "Riattiva" : "In attesa")
                    Button { router.sheet = .settings } label: { Image(systemName: "bell").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Impostazioni notifiche")
                    Button(role: .destructive) { Task { await store.run("deleteTask", args: [.int(record.integer("id"))]) } } label: { Image(systemName: "trash").foregroundStyle(NativeDesign.danger).frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Elimina attività")
                }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(NativeDesign.accent)
            }
            if title != record.text("title") || notes != record.text("notes") {
                Button("Salva modifiche") {
                    Task {
                        do {
                            var payload = record; payload["title"] = .string(title); payload["notes"] = .string(notes)
                            try await store.perform("saveTask", payload); error = nil
                        } catch { self.error = error.localizedDescription }
                    }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { NativeInlineMessage(text: error) }
        }.font(.subheadline).padding(.bottom, NativeDesign.Space.small)
            .onAppear { title = record.text("title"); notes = record.text("notes") }
    }
}

struct TaskEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let record: Record
    @State private var title = ""
    @State private var notes = ""
    @State private var category = "action"
    @State private var due = Date()
    @State private var scheduled = Date()
    @State private var hasDue = false
    @State private var hasScheduled = false
    @State private var hasTime = false
    @State private var notificationTime = CivilDate.date(CivilDate.day()).addingTimeInterval(9 * 3600)
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        Form {
            Section { TextField("Titolo", text: $title); Picker("Categoria", selection: $category) { ForEach(store.categories.map { DisplayRecord($0, key: "key") }) { item in Text(item.value.text("label")).tag(item.value.text("key")) } } }
            Section("Date") {
                Toggle("Scadenza", isOn: $hasDue)
                if hasDue { DatePicker("Scade il", selection: $due, displayedComponents: .date) }
                Toggle("Mostra nel calendario", isOn: $hasScheduled)
                if hasScheduled { DatePicker("Giorno", selection: $scheduled, displayedComponents: .date) }
                if hasDue || hasScheduled {
                    Toggle("Orario promemoria", isOn: $hasTime)
                    if hasTime { DatePicker("Ora", selection: $notificationTime, displayedComponents: .hourAndMinute) }
                    Text("Il promemoria segue il giorno programmato, oppure la scadenza. Senza orario usa le 9:00, se le notifiche sono abilitate.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
            }
            Section("Note") { TextEditor(text: $notes).frame(minHeight: 120) }
            if let error { NativeInlineMessage(text: error) }
        }.modifier(NativeListAppearance()).navigationTitle(record.integer("id") > 0 ? "Modifica attività" : "Nuova attività").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) { Button("Salva") { Task { await save() } }.disabled(saving || store.busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.onAppear {
            title = record.text("title"); notes = record.text("notes"); category = record.text("list_kind", fallback: store.categories.first?.text("key") ?? "action")
            hasDue = !record.text("due_date").isEmpty; hasScheduled = !record.text("scheduled_date").isEmpty
            if hasDue { due = CivilDate.date(record.text("due_date")) }; if hasScheduled { scheduled = CivilDate.date(record.text("scheduled_date")) }
            hasTime = !record.text("scheduled_time").isEmpty
            if hasTime {
                let parts = record.text("scheduled_time").split(separator: ":").compactMap { Int($0) }
                if parts.count == 2, let time = CivilDate.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) { notificationTime = time }
            }
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        do {
            try await store.perform("saveTask", ["id": .int(record.integer("id")), "title": .string(title), "notes": .string(notes), "list_kind": .string(category), "due_date": hasDue ? .string(CivilDate.day(due)) : .null, "scheduled_date": hasScheduled ? .string(CivilDate.day(scheduled)) : .null, "scheduled_time": hasTime && (hasScheduled || hasDue) ? .string(String(format: "%02d:%02d", CivilDate.calendar.component(.hour, from: notificationTime), CivilDate.calendar.component(.minute, from: notificationTime))) : .null])
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct CategoriesEditor: View {
    @EnvironmentObject var store: NativeStore
    @State private var name = ""
    @State private var rename: Record?
    @State private var deleting: Record?
    @State private var destination = "action"
    @State private var showRename = false
    @State private var showDelete = false
    var body: some View {
        List {
            Section {
                ForEach(store.categories.map { DisplayRecord($0, key: "key") }) { item in
                    HStack { Text(item.value.text("label")); Spacer(); Button { rename = item.value; name = item.value.text("label"); showRename = true } label: { Image(systemName: "pencil") }.buttonStyle(.borderless) }
                        .swipeActions { Button("Elimina", role: .destructive) { deleting = item.value; destination = store.categories.first(where: { $0.text("key") != item.value.text("key") })?.text("key") ?? ""; showDelete = true } }
                }.onMove { offsets, to in
                    var rows = store.categories; rows.move(fromOffsets: offsets, toOffset: to)
                    Task { await store.run("reorderCategories", ["keys": .array(rows.map { .string($0.text("key")) })]) }
                }
            }
            Section("Nuova categoria") {
                TextField("Nome", text: $name)
                Button("Aggiungi") { Task { await store.run("addCategory", ["label": .string(name)]); name = "" } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            }
            if showDelete, let deleting {
                Section("Conserva le attività") {
                    Picker("Sposta in", selection: $destination) { ForEach(store.categories.filter { $0.text("key") != deleting.text("key") }.map { DisplayRecord($0, key: "key") }) { item in Text(item.value.text("label")).tag(item.value.text("key")) } }
                    Button("Elimina categoria e sposta le attività", role: .destructive) { Task { await store.run("deleteCategory", ["key": .string(deleting.text("key")), "destination": .string(destination)]); showDelete = false } }.disabled(destination.isEmpty || store.busy)
                    Button("Annulla") { showDelete = false }
                }
            }
        }.modifier(NativeListAppearance()).navigationTitle("Categorie").toolbar { DoneButton(); ToolbarItem(placement: .topBarLeading) { EditButton() } }
        .alert("Rinomina categoria", isPresented: $showRename) {
            TextField("Nome", text: $name)
            Button("Salva") { if let rename { Task { await store.run("renameCategory", ["key": .string(rename.text("key")), "label": .string(name)]); name = "" } } }
            Button("Annulla", role: .cancel) { name = "" }
        }
    }
}
struct RoutinesEditor: View {
    @EnvironmentObject var store: NativeStore
    @State private var name = ""
    @State private var editingID = 0
    @State private var mode = "daily"
    @State private var interval = 2
    @State private var weekdays: Set<Int> = []
    @State private var startDate = Date()
    @State private var saving = false
    private var supported: Bool { store.isDemo || store.life.integer("routineScheduleVersion") == 1 }
    private var schedule: NativeRoutineSchedule? { try? NativeRoutineSchedule(.object(["mode": .string(mode), "intervalDays": .int(interval), "weekdays": .array(weekdays.sorted().map(JSONValue.int)), "startDate": .string(mode == "daily" ? "" : CivilDate.day(startDate))])) }
    var body: some View {
        Form {
            Section("Tutte le abitudini") {
                ForEach(store.routines.map { DisplayRecord($0) }) { item in
                    Button { edit(item.value) } label: {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text(item.value.text("title")).foregroundStyle(Color.primary)
                            Text((try? NativeRoutineSchedule(item.value["schedule"]).summary) ?? "Programmazione non valida").font(.caption).foregroundStyle(NativeDesign.secondary)
                            if let value = try? NativeRoutineSchedule(item.value["schedule"]), !value.startDate.isEmpty { Text("Dal " + CivilDate.label(value.startDate)).font(.caption).foregroundStyle(NativeDesign.secondary) }
                        }
                    }.accessibilityIdentifier("routine-edit-\(item.value.integer("id"))")
                        .swipeActions { Button("Elimina", role: .destructive) { Task { await store.run("deleteRoutine", args: [.int(item.value.integer("id"))]) } } }
                }
            }
            Section(editingID == 0 ? "Aggiungi abitudine" : "Modifica abitudine") {
                TextField("Nome", text: $name).accessibilityIdentifier("routine-name")
                Picker("Ripetizione", selection: $mode) {
                    Text("Ogni giorno").tag("daily")
                    Text("Ogni N giorni").tag("interval")
                    Text("Giorni della settimana").tag("weekdays")
                }.accessibilityIdentifier("routine-repeat")
                if mode == "interval" { Stepper("Ogni \(interval) \(interval == 1 ? "giorno" : "giorni")", value: $interval, in: 1...365).accessibilityIdentifier("routine-interval") }
                if mode == "weekdays" {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(NativeRoutineSchedule.weekdays[day - 1], isOn: Binding(get: { weekdays.contains(day) }, set: { selected in if selected { weekdays.insert(day) } else { weekdays.remove(day) } })).accessibilityIdentifier("routine-weekday-\(day)")
                    }
                }
                if mode != "daily" { DatePicker("Data di inizio", selection: $startDate, displayedComponents: .date).accessibilityIdentifier("routine-start") }
                if !supported { Text("Aggiorna il Worker collegato per programmare le abitudini.").foregroundStyle(NativeDesign.warning) }
                Button("Salva") { save() }.disabled(!supported || schedule == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60).accessibilityIdentifier("routine-save")
                if editingID != 0 { Button("Annulla modifica") { reset() } }
            }
            Text("La dashboard mostra le abitudini previste oggi. Gli intervalli si contano dalla data di inizio, anche se salti un completamento. Ogni data ha i propri completamenti.").font(.caption).foregroundStyle(NativeDesign.secondary)
        }.disabled(saving || store.busy).modifier(NativeListAppearance()).navigationTitle("Abitudini").toolbar { DoneButton() }
    }
    private func edit(_ record: Record) {
        do {
            let value = try NativeRoutineSchedule(record["schedule"])
            editingID = record.integer("id"); name = record.text("title"); mode = value.mode; interval = value.mode == "interval" ? value.intervalDays : 2; weekdays = Set(value.days); startDate = value.startDate.isEmpty ? Date() : CivilDate.date(value.startDate)
        } catch { store.error = error.localizedDescription }
    }
    private func reset() { editingID = 0; name = ""; mode = "daily"; interval = 2; weekdays = []; startDate = Date() }
    private func save() {
        guard let schedule, !saving else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines), id = editingID, previousIDs = Set(store.routines.map { $0.integer("id") })
        saving = true
        Task {
            defer { saving = false }
            do {
                try await store.perform("saveRoutine", ["id": .int(id), "title": .string(title), "schedule": schedule.value])
                let saved = store.routines.first { id == 0 ? !previousIDs.contains($0.integer("id")) && $0.text("title") == title : $0.integer("id") == id }
                guard let saved, saved.text("title") == title, try NativeRoutineSchedule(saved["schedule"]) == schedule else { throw Message(text: "Operazione inviata. Sincronizza e verifica l’abitudine prima di ripetere il salvataggio.") }
                reset()
            } catch { store.error = error.localizedDescription }
        }
    }
}
