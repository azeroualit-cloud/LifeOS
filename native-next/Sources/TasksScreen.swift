import SwiftUI

extension Notification.Name { static let nativeTaskEditorSaved = Notification.Name("lifeos.native.task-editor-saved") }

struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @State private var category = "action"
    @State private var editMode: EditMode = .inactive
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var completedExpanded = false
    private func rows(_ status: String) -> [Record] { NativeTaskList.rows(store.tasks, category: category, section: status) }
    private func activities(_ status: String) -> [NativeActivity] { NativeActivityCatalog.rows(tasks: store.tasks, events: store.activityEvents, category: category, section: status) }
    private var checklist: some View {
        let active = activities("todo"), waiting = activities("waiting")
        let completed = rows("done").map { DisplayRecord($0) }
        return List {
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
            if !active.isEmpty { Section {
                ForEach(Array(active.enumerated()), id: \.element.id) { index, item in activityRow(item, first: index == 0, last: index == active.count - 1).moveDisabled(item.isEvent || item.completed) }
                    .onMove { indexes, destination in
                        var visible = active; visible.move(fromOffsets: indexes, toOffset: destination)
                        let ordered = visible.filter { !$0.isEvent }.map(\.record)
                        let ids = NativeTaskList.reorderIDs(tasks: store.tasks, category: category, visibleIDs: ordered.map { $0.integer("id") })
                        Task { await store.run("reorderTasks", ["category": .string(category), "ids": .array(ids.map(JSONValue.int))]) }
                    }
            } header: { checklistHeading("Attivo") } }
            if !waiting.isEmpty {
                Section { ForEach(Array(waiting.enumerated()), id: \.element.id) { index, item in activityRow(item, first: index == 0, last: index == waiting.count - 1) } } header: { checklistHeading("In attesa") }
            }
            if !completed.isEmpty {
                Section {
                    if completedExpanded {
                        ForEach(Array(completed.enumerated()), id: \.element.id) { index, item in taskRow(item.value, first: index == 0, last: index == completed.count - 1) }
                    }
                } header: {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { completedExpanded.toggle() }
                    } label: {
                        NativeSectionHeader("Completate", titleIdentifier: "task-heading-Completate") {
                            HStack(spacing: NativeDesign.Space.small) {
                                Text(String(completed.count))
                                Image(systemName: completedExpanded ? "chevron.up" : "chevron.down")
                            }
                        }.foregroundStyle(NativeDesign.secondary).textCase(nil)
                            .padding(.horizontal, NativeDesign.Layout.screenInset)
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }.buttonStyle(.plain).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).accessibilityIdentifier("toggle-completed-tasks")
                        .accessibilityValue(completedExpanded ? "Aperta" : "Chiusa")
                }
            }
            if active.isEmpty && waiting.isEmpty && completed.isEmpty {
                Text("Nessuna attività da mostrare").foregroundStyle(NativeDesign.secondary).listRowBackground(Color.clear)
            }
        }
    }
    var body: some View {
        checklist
        .modifier(NativeChecklistListAppearance())
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        .animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: store.tasks)
        .onChange(of: category) { _, _ in completedExpanded = false }
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
    @ViewBuilder private func activityRow(_ item: NativeActivity, first: Bool, last: Bool) -> some View {
        if item.isEvent {
            let r = item.record
            NativeChecklistRow(title: r.text("title"), subtitle: CivilDate.label(r.text("day")) + (r.text("start_time").isEmpty ? "" : " · " + r.text("start_time")), checked: item.completed, completionLabel: "Cambia completamento evento " + r.text("title"), onComplete: {
                Task { await store.run("setEventOccurrence", ["id": .int(r.integer("id")), "day": .string(r.text("day")), "status": .string(item.completed ? "open" : "done")]) }
            }, onOpen: { router.sheet = .event(r) })
            .modifier(NativeChecklistListRow(first: first, last: last)).disabled(store.busy)
        } else { taskRow(item.record, first: first, last: last) }
    }
    private func taskRow(_ r: Record, first: Bool, last: Bool) -> some View {
        NativeChecklistRow(title: r.text("title"), subtitle: r.text("notes"), checked: r.text("status") == "done", dueDay: r.text("due_date"), openIdentifier: "task-open-" + String(r.integer("id")), completionLabel: "Cambia completamento " + r.text("title"), onComplete: {
            Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.completionStatus(r))]) }
        }, onOpen: { router.sheet = .task(r) })
        .modifier(NativeChecklistListRow(first: first, last: last)).disabled(store.busy)
    }
}

struct TaskEditor: View {
    let record: Record
    var body: some View { NativeActivityEditor(record: record, source: "task") }
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
