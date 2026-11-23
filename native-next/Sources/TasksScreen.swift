import SwiftUI

/// Attività (build 93 preview): category drop-down with "Tutte", Da fare / Abitudini,
/// sections Oggi, Prossimi giorni, In attesa, Completate in grouped cards.
struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    /// A category key, or "all" for every category (preview "Tutte").
    @State private var category = "action"
    @State private var view = "Da fare"
    @State private var editMode: EditMode = .inactive
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var completedExpanded = false
    private static let all = "all"
    private var categoryKeys: [String] { store.categories.map { $0.text("key") } }
    private var selectedKeys: [String] { category == Self.all ? categoryKeys : [category] }
    private func label(_ key: String) -> String { store.categories.first { $0.text("key") == key }?.text("label") ?? key }
    private func rows(_ status: String) -> [Record] { selectedKeys.flatMap { NativeTaskList.rows(store.tasks, category: $0, section: status) } }
    private func activities(_ status: String) -> [NativeActivity] {
        selectedKeys.flatMap { NativeActivityCatalog.rows(tasks: store.tasks, events: store.activityEvents, category: $0, section: status) }
    }

    private var checklist: some View {
        let today = CivilDate.day()
        let open = activities("todo") + activities("waiting")
        // Same data as build 92, grouped by when: today (tasks and today's events),
        // the next days (events), waiting tasks, completed.
        let todayItems = open.filter { $0.isEvent ? $0.record.text("day") <= today : NativeTaskList.section($0.record) != "waiting" }
        let nextItems = open.filter { $0.isEvent && $0.record.text("day") > today }
            .sorted { ($0.record.text("day"), $0.record.text("start_time")) < ($1.record.text("day"), $1.record.text("start_time")) }
        let waiting = open.filter { !$0.isEvent && NativeTaskList.section($0.record) == "waiting" }
        let completed = rows("done").map { DisplayRecord($0) }
        return List {
            Section { header }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            if view == "Abitudini" {
                habits
            } else {
                if !todayItems.isEmpty { Section {
                    ForEach(Array(todayItems.enumerated()), id: \.element.id) { index, item in
                        activityRow(item, first: index == 0, last: index == todayItems.count - 1).moveDisabled(item.isEvent || item.completed || category == Self.all)
                    }
                    .onMove { indexes, destination in
                        guard category != Self.all else { return }
                        var visible = todayItems; visible.move(fromOffsets: indexes, toOffset: destination)
                        let ordered = visible.filter { !$0.isEvent }.map(\.record)
                        let ids = NativeTaskList.reorderIDs(tasks: store.tasks, category: category, visibleIDs: ordered.map { $0.integer("id") })
                        Task { await store.run("reorderTasks", ["category": .string(category), "ids": .array(ids.map(JSONValue.int))]) }
                    }
                } header: { checklistHeading("Oggi") } }
                if !nextItems.isEmpty {
                    Section { ForEach(Array(nextItems.enumerated()), id: \.element.id) { index, item in activityRow(item, first: index == 0, last: index == nextItems.count - 1) } } header: { checklistHeading("Prossimi giorni") }
                }
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
                            HStack(spacing: NativeDesign.Space.small) {
                                LOSectionLabel(title: "Completate").padding(.horizontal, -NativeDesign.Space.large)
                                    .accessibilityIdentifier("task-heading-Completate")
                                Spacer()
                                Text(completedExpanded ? "Nascondi" : "Mostra \(completed.count)").font(.subheadline)
                            }
                            .foregroundStyle(NativeDesign.secondary).textCase(nil)
                            .padding(.horizontal, NativeDesign.Space.large)
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).listRowInsets(EdgeInsets()).accessibilityIdentifier("toggle-completed-tasks")
                            .accessibilityValue(completedExpanded ? "Aperta" : "Chiusa")
                    }
                }
                if todayItems.isEmpty && nextItems.isEmpty && waiting.isEmpty && completed.isEmpty {
                    Text("Nessuna attività da mostrare").foregroundStyle(NativeDesign.secondary).listRowBackground(Color.clear)
                }
            }
        }
    }

    /// Da fare / Abitudini, then the categories as one row of chips (one tap, user request
    /// 22/11/2026; ACTIVITY-CATEGORY-GLASS-01), reorder for one category.
    private var header: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSegmented(options: [("Da fare", "todo"), ("Abitudini", "habits")], selection: $view, identifierPrefix: "activity-view-")
            if view == "Da fare" {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) {
                        categoryChip("Tutte", key: Self.all, identifier: "task-category-all")
                        ForEach(store.categories.map { DisplayRecord($0, key: "key") }) { item in
                            let key = item.value.text("key")
                            categoryChip(item.value.text("label"), key: key, identifier: "task-category-" + key)
                        }
                        Button { router.sheet = .categories } label: {
                            Image(systemName: "folder").font(.subheadline.weight(.semibold))
                                .frame(width: NativeDesign.Layout.compactControl, height: NativeDesign.Layout.compactControl)
                                .modifier(NativeGlass())
                                .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(NativePressStyle())
                        .accessibilityLabel("Gestisci categorie")
                        .accessibilityIdentifier("task-category-manage")
                    }
                    .padding(.vertical, NativeDesign.Space.xxs)
                }
                .scrollClipDisabled()
                .accessibilityIdentifier("task-category-filter")
            }
            if view == "Da fare" && category != Self.all {
                Button(editMode == .active ? "Fine" : "Riordina") { editMode = editMode == .active ? .inactive : .active }
                    .font(.subheadline).foregroundStyle(NativeDesign.secondary).disabled(store.busy)
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reorder-tasks")
            }
        }
        .padding(.vertical, NativeDesign.Space.xs)
    }
    /// One category: neutral glass, the selected one filled (no accent colour, UI-LOOK-92).
    private func categoryChip(_ title: String, key: String, identifier: String) -> some View {
        let selected = category == key
        return Button { category = key } label: {
            Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .padding(.horizontal, NativeDesign.Space.medium)
                .frame(minHeight: NativeDesign.Layout.compactControl)
                // Selected: solid fill without glass on top (the glass washed it out to grey, 1.6:1).
                .modifier(NativeChipBackground(selected: selected))
                .frame(minHeight: NativeDesign.Layout.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// Abitudini: every habit with its schedule and next date; today's can be checked.
    @ViewBuilder private var habits: some View {
        let routines = store.routines
        Section {
            if routines.isEmpty {
                Text("Nessuna abitudine").foregroundStyle(NativeDesign.secondary)
            }
            ForEach(Array(routines.enumerated()), id: \.offset) { index, routine in
                let due = NativeRoutineSchedule.due(routine)
                let summary = (try? NativeRoutineSchedule(routine["schedule"]).summary) ?? ""
                NativeChecklistRow(title: routine.text("title"),
                    subtitle: [summary, NativeRoutineSchedule.nextLabel(routine)].filter { !$0.isEmpty }.joined(separator: " · "),
                    checked: due && routine.flag("checked"), showsDisclosure: true,
                    completionIdentifier: "habit-check-\(routine.integer("id"))",
                    openIdentifier: "habit-open-\(routine.integer("id"))",
                    completionLabel: "Completa abitudine " + routine.text("title"),
                    onComplete: { if due { checkRoutine(routine) } },
                    onOpen: { router.sheet = .routines })
                    .modifier(NativeChecklistListRow(first: index == 0, last: index == routines.count - 1))
                    .disabled(store.busy || !due)
            }
            Button { router.sheet = .routines } label: { Label("Nuova abitudine", systemImage: "plus") }
                .frame(minHeight: NativeDesign.Layout.touchTarget)
                .accessibilityIdentifier("habit-add")
        } header: { checklistHeading("Abitudini") }
    }

    private func checkRoutine(_ record: Record) {
        Task {
            await store.run("setRoutineCheck", ["id": .int(record.integer("id")), "day": .string(CivilDate.day()), "checked": .bool(!record.flag("checked"))])
        }
    }

    var body: some View {
        checklist
        .modifier(NativeChecklistListAppearance())
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        .animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: store.tasks)
        .onChange(of: category) { _, _ in completedExpanded = false; editMode = .inactive }
        .onAppear {
            let keys = categoryKeys
            category = keys.contains(router.taskCategory) ? router.taskCategory : keys.first ?? "action"
        }
        // The add action needs a real category: "Tutte" keeps the last chosen one.
        .onChange(of: category) { _, value in if value != Self.all { router.taskCategory = value } }
        .onChange(of: router.taskCategory) { _, value in
            if category != Self.all, store.categories.contains(where: { $0.text("key") == value }) { category = value }
        }
        .onChange(of: categoryKeys) { _, keys in if category != Self.all && !keys.contains(category) { category = keys.first ?? "action" } }
    }
    private func checklistHeading(_ title: String) -> some View {
        LOSectionLabel(title: title)
            .padding(.horizontal, -NativeDesign.Space.large)
            .accessibilityLabel(title)
            .textCase(nil).padding(.top, NativeDesign.Space.small)
            .listRowInsets(EdgeInsets(top: 0, leading: NativeDesign.Layout.screenInset, bottom: NativeDesign.Space.xs, trailing: 0))
            .accessibilityIdentifier("task-heading-" + title)
    }
    private func subtitle(_ r: Record, isEvent: Bool) -> String {
        var parts: [String] = []
        if category == Self.all { parts.append(label(r.text("list_kind", fallback: "action"))) }
        if isEvent {
            parts.append(CivilDate.label(r.text("day")) + (r.text("start_time").isEmpty ? "" : " · " + r.text("start_time")))
        } else if !r.text("notes").isEmpty { parts.append(r.text("notes")) }
        return parts.joined(separator: " · ")
    }
    @ViewBuilder private func activityRow(_ item: NativeActivity, first: Bool, last: Bool) -> some View {
        if item.isEvent {
            let r = item.record
            NativeChecklistRow(title: r.text("title"), subtitle: subtitle(r, isEvent: true), checked: item.completed, completionLabel: "Cambia completamento evento " + r.text("title"), onComplete: {
                Task { await store.run("setEventOccurrence", ["id": .int(r.integer("id")), "day": .string(r.text("day")), "status": .string(item.completed ? "open" : "done")]) }
            }, onOpen: { router.sheet = .event(r) })
            .modifier(NativeChecklistListRow(first: first, last: last)).disabled(store.busy)
        } else { taskRow(item.record, first: first, last: last) }
    }
    private func taskRow(_ r: Record, first: Bool, last: Bool) -> some View {
        NativeChecklistRow(title: r.text("title"), subtitle: subtitle(r, isEvent: false), checked: r.text("status") == "done", dueDay: r.text("due_date"), openIdentifier: "task-open-" + String(r.integer("id")), completionLabel: "Cambia completamento " + r.text("title"), onComplete: {
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
                            Text((try? NativeRoutineSchedule(item.value["schedule"]).summary) ?? "Programmazione non valida").font(.footnote).foregroundStyle(NativeDesign.secondary)
                            Text(NativeRoutineSchedule.nextLabel(item.value)).font(.footnote).foregroundStyle(NativeDesign.secondary)
                                .accessibilityIdentifier("routine-next-\(item.value.integer("id"))")
                        }
                    }.accessibilityIdentifier("routine-edit-\(item.value.integer("id"))")
                        .swipeActions { Button("Elimina", role: .destructive) { Task { await store.run("deleteRoutine", args: [.int(item.value.integer("id"))]) } } }
                }
            }
            Section(editingID == 0 ? "Aggiungi abitudine" : "Modifica abitudine") {
                TextField("Nome", text: $name).accessibilityIdentifier("routine-name")
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    Text("Ripetizione").font(.footnote).foregroundStyle(NativeDesign.secondary)
                    LOSegmented(options: [("Ogni giorno", "daily"), ("Ogni N giorni", "interval"), ("Giorni", "weekdays")], selection: Binding(
                        get: { mode == "daily" ? "Ogni giorno" : mode == "interval" ? "Ogni N giorni" : "Giorni" },
                        set: { mode = $0 == "Ogni giorno" ? "daily" : $0 == "Ogni N giorni" ? "interval" : "weekdays" }),
                        identifierPrefix: "routine-repeat-")
                }
                if mode == "interval" { Stepper("Ogni \(interval) \(interval == 1 ? "giorno" : "giorni")", value: $interval, in: 1...365).accessibilityIdentifier("routine-interval") }
                if mode == "weekdays" {
                    HStack(spacing: NativeDesign.Space.xs) {
                        ForEach(1...7, id: \.self) { day in
                            let on = weekdays.contains(day)
                            Button { if on { weekdays.remove(day) } else { weekdays.insert(day) } } label: {
                                Text(["L", "M", "M", "G", "V", "S", "D"][day - 1]).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(on ? NativeDesign.onAccent : Color.primary)
                                    .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                                    .background { Circle().fill(on ? NativeDesign.accent : NativeDesign.barTrack) }
                                    .contentShape(Circle())
                            }
                            .buttonStyle(NativePressStyle())
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(NativeRoutineSchedule.weekdays[day - 1])
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .accessibilityIdentifier("routine-weekday-\(day)")
                        }
                    }
                }
                if mode != "daily" { DatePicker("Data di inizio", selection: $startDate, displayedComponents: .date).accessibilityIdentifier("routine-start") }
                if !supported { Text("Aggiorna il Worker collegato per programmare le abitudini.").foregroundStyle(NativeDesign.warning) }
                Button("Salva") { save() }.disabled(!supported || schedule == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60).accessibilityIdentifier("routine-save")
                if editingID != 0 { Button("Annulla modifica") { reset() } }
            }
            Text("La dashboard mostra le abitudini previste oggi. Gli intervalli si contano dalla data di inizio, anche se salti un completamento. Ogni data ha i propri completamenti.").font(.footnote).foregroundStyle(NativeDesign.secondary)
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

private struct NativeChipBackground: ViewModifier {
    let selected: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if selected { content.background(Capsule().fill(Color.primary)) } else { content.modifier(NativeGlass()) }
    }
}
