import SwiftUI

private extension Notification.Name { static let nativeTaskEditorSaved = Notification.Name("lifeos.native.task-editor-saved") }

struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @State private var category = "action"
    @State private var editMode: EditMode = .inactive
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var expandedID: String?
    @State private var completedExpanded = false
    @State private var drafts: [Int: NativeTaskDraft] = [:]
    @FocusState private var focusedTaskField: NativeTaskField?
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
                Section { ForEach(Array(waiting.enumerated()), id: \.element.id) { index, item in activityRow(item, first: index == 0, last: index == waiting.count - 1) } }
                header: { checklistHeading("In attesa") }
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
        .toolbar { editingKeyboardToolbar }
        .onChange(of: expandedID) { _, _ in focusedTaskField = nil }
        .onChange(of: router.tab) { _, tab in if tab != .tasks { focusedTaskField = nil } }
        .onChange(of: router.sheet?.id) { _, sheet in if sheet != nil { focusedTaskField = nil } }
        .animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: store.tasks)
        .onChange(of: category) { _, _ in expandedID = nil; completedExpanded = false }
        .onChange(of: store.tasks.map { $0.integer("id") }) { _, ids in drafts = drafts.filter { ids.contains($0.key) } }
        .onReceive(NotificationCenter.default.publisher(for: .nativeTaskEditorSaved)) { note in
            if let id = note.object as? Int { drafts.removeValue(forKey: id) }
        }
        
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
    @ToolbarContentBuilder private var editingKeyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if focusedTaskField != nil && router.sheet?.id == nil {
                Spacer()
                NativeIconButton(symbol: "keyboard.chevron.compact.down", label: "Nascondi tastiera") { focusedTaskField = nil }
                    .accessibilityIdentifier("hide-task-keyboard")
            }
        }
    }
    private func checklistHeading(_ title: String) -> some View {
        NativeSectionHeader(title, titleIdentifier: "task-heading-" + title) { EmptyView() }
            .foregroundStyle(title == "In attesa" ? NativeDesign.secondary : Color.primary)
            .textCase(nil).padding(.vertical, NativeDesign.Space.small)
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    private func toggleExpanded(_ id: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { expandedID = expandedID == id ? nil : id }
    }
    @ViewBuilder private func activityRow(_ item: NativeActivity, first: Bool, last: Bool) -> some View {
        if item.isEvent {
            let r = item.record
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                NativeChecklistRow(title: r.text("title"), subtitle: CivilDate.label(r.text("day")) + (r.text("start_time").isEmpty ? "" : " · " + r.text("start_time")), checked: item.completed, showsDisclosure: false, completionLabel: "Cambia completamento evento " + r.text("title"), onComplete: {
                    expandedID = nil
                    Task { await store.run("setEventOccurrence", ["id": .int(r.integer("id")), "day": .string(r.text("day")), "status": .string("done")]) }
                }, onOpen: { toggleExpanded(item.id) })
                if expandedID == item.id {
                    NativeEventControls(record: r).padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small).transition(.opacity)
                }
            }
            .modifier(NativeChecklistListRow(first: first, last: last))
            .disabled(store.busy)
        } else { taskRow(item.record, first: first, last: last) }
    }
    private func draftBinding(_ record: Record) -> Binding<NativeTaskDraft> {
        let id = record.integer("id")
        return Binding(get: { drafts[id] ?? NativeTaskDraft(record) }, set: { value in
            if value == NativeTaskDraft(record) { drafts.removeValue(forKey: id) }
            else { drafts[id] = value }
        })
    }
    private func taskRow(_ r: Record, first: Bool, last: Bool) -> some View {
        let expanded = expandedID == "task:\(r.integer("id"))"
        return HStack(alignment: .top, spacing: NativeDesign.Space.small) {
            NativeCompletionButton(checked: r.text("status") == "done", label: "Cambia completamento " + r.text("title")) {
                expandedID = nil
                Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.completionStatus(r))]) }
            }
            NativeTaskControls(record: r, draft: draftBinding(r), focus: $focusedTaskField, expanded: expanded, onOpen: { toggleExpanded("task:\(r.integer("id"))") }) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { expandedID = nil }
            }
        }
        
        .modifier(NativeChecklistListRow(first: first, last: last))
        .disabled(store.busy)
    }
}

private enum NativeTaskField: Hashable { case title(Int), notes(Int) }

private struct NativeTaskDraft: Equatable {
    var title: String
    var notes: String
    init(_ record: Record) { title = record.text("title"); notes = record.text("notes") }
}

/// Contextual editing stays under its task; full date/category editing reuses TaskEditor.
private struct NativeTaskControls: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    let record: Record
    @Binding var draft: NativeTaskDraft
    let focus: FocusState<NativeTaskField?>.Binding
    let expanded: Bool
    var onOpen: () -> Void
    var onClose: () -> Void
    private enum Confirmation { case close, delete }
    @State private var confirmation: Confirmation?
    private var title: String { draft.title }
    private var notes: String { draft.notes }
    private var dirty: Bool { title != record.text("title") || notes != record.text("notes") }
    private func requestClose() { if dirty { confirmation = .close } else { onClose() } }
    private func save(close: Bool) {
        Task {
            do {
                var payload = record; payload["title"] = .string(title); payload["notes"] = .string(notes)
                try await store.perform("saveTask", payload); error = nil
                if let saved = store.tasks.first(where: { $0.integer("id") == record.integer("id") }) { draft = NativeTaskDraft(saved) }
                if close { onClose() }
            } catch { self.error = error.localizedDescription }
        }
    }
    @State private var error: String?
    private func edit(_ section: String) {
        var value = record; value["title"] = .string(title); value["notes"] = .string(notes)
        value["_editorSection"] = .string(section); router.sheet = .task(value)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Group {
                if expanded {
                    TextField("Titolo", text: $draft.title, axis: .vertical).textFieldStyle(.plain)
                        .focused(focus, equals: .title(record.integer("id")))
                        .font(NativeDesign.body).foregroundStyle(record.text("status") == "done" ? NativeDesign.secondary : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                        .accessibilityIdentifier("inline-task-title").transition(.identity)
                } else {
                    Button(action: onOpen) {
                        Text(title).font(NativeDesign.body).foregroundStyle(record.text("status") == "done" ? NativeDesign.secondary : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                            .multilineTextAlignment(.leading).contentShape(Rectangle())
                    }.buttonStyle(.borderless).accessibilityLabel(title)
                        .accessibilityIdentifier("task-open-" + String(record.integer("id"))).transition(.identity)
                }
            }.transaction { $0.animation = nil; $0.disablesAnimations = true }
            if expanded {
                TextField("Aggiungi nota", text: $draft.notes, axis: .vertical).textFieldStyle(.plain).focused(focus, equals: .notes(record.integer("id"))).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
            } else if !notes.isEmpty {
                Text(notes).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if dirty && !expanded { Text("Modifiche non salvate").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary) }
            if !record.text("due_date").isEmpty { NativeDueBadge(day: record.text("due_date")) }
            if expanded {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: NativeDesign.Layout.touchTarget), spacing: NativeDesign.Space.xs)], alignment: .leading, spacing: NativeDesign.Space.xs) {
                NativeInlineAction(symbol: "calendar", label: "Data e dettagli attività") { edit("dates") }.accessibilityIdentifier("inline-task-details")
                NativeInlineAction(symbol: "clock", label: "Orario promemoria attività") { edit("reminder") }.accessibilityIdentifier("inline-task-reminder")
                NativeInlineAction(symbol: NativeTaskList.section(record) == "waiting" ? "play" : "pause", label: NativeTaskList.section(record) == "waiting" ? "Riattiva" : "In attesa") {
                    Task { await store.run("setTaskStatus", ["id": .int(record.integer("id")), "status": .string(NativeTaskList.section(record) == "waiting" ? "todo" : "waiting")]) }
                }
                NativeInlineAction(symbol: "trash", label: "Elimina attività", destructive: true) { confirmation = .delete }.accessibilityIdentifier("inline-task-delete")
                NativeInlineAction(symbol: "chevron.up", label: "Chiudi comandi attività") { requestClose() }.accessibilityIdentifier("inline-task-close")
            }
            if dirty {
                Button("Salva modifiche") { save(close: false) }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { NativeInlineMessage(text: error) }
            }
        }
        .onChange(of: record) { old, new in
            if draft == NativeTaskDraft(old) || draft == NativeTaskDraft(new) { draft = NativeTaskDraft(new) }
        }
        .confirmationDialog(confirmation == .delete ? "Eliminare questa attività?" : "Salvare le modifiche all’attività?", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
            if confirmation == .delete {
                Button("Elimina attività", role: .destructive) { Task { await store.run("deleteTask", args: [.int(record.integer("id"))]) } }
            } else {
                Button("Salva e chiudi") { save(close: true) }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Scarta modifiche", role: .destructive) { draft = NativeTaskDraft(record); onClose() }
                Button("Continua a modificare", role: .cancel) { }
            }
        }
    }
}

/// Same contextual action chips for calendar activities; deletion retains occurrence/series choices.
private struct NativeEventControls: View {
    @EnvironmentObject var router: NativeRouter
    let record: Record
    private func edit(_ section: String) {
        var value = record; value["_editorSection"] = .string(section); router.sheet = .event(value)
    }
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: NativeDesign.Layout.touchTarget), spacing: NativeDesign.Space.xs)], alignment: .leading, spacing: NativeDesign.Space.xs) {
                NativeInlineAction(symbol: "calendar", label: "Data e dettagli evento") { edit("dates") }.accessibilityIdentifier("inline-event-details")
                NativeInlineAction(symbol: "clock", label: "Orario evento") { edit("time") }.accessibilityIdentifier("inline-event-time")
                NativeInlineAction(symbol: "repeat", label: "Ripetizione evento") { edit("repeat") }.accessibilityIdentifier("inline-event-repeat")
                NativeInlineAction(symbol: "trash", label: "Elimina evento", destructive: true) { edit("actions") }.accessibilityIdentifier("inline-event-delete")
        }
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
