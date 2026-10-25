import SwiftUI

struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @State private var category = "action"
    @State private var editMode: EditMode = .inactive
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var expandedID: Int?
    private func rows(_ status: String) -> [Record] {
        NativeTaskList.rows(store.tasks, category: category, section: status)
    }
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
                if rows("todo").isEmpty { Text("Nessuna attività attiva").foregroundStyle(NativeDesign.secondary).modifier(NativeChecklistListRow(first: true, last: true)) }
                ForEach(rows("todo").map { DisplayRecord($0) }) { item in taskRow(item.value).moveDisabled(item.value.text("status") == "done") }
                    .onMove { indexes, destination in
                        var ordered = rows("todo"); ordered.move(fromOffsets: indexes, toOffset: destination)
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
    private func taskRow(_ r: Record) -> some View {
        let siblings = rows(NativeTaskList.section(r))
        let expanded = expandedID == r.integer("id")
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            NativeChecklistRow(title: r.text("title"), subtitle: expanded ? "" : r.text("notes"), checked: r.text("status") == "done", dueDay: r.text("due_date"), showsDisclosure: false, completionLabel: "Cambia completamento " + r.text("title"), onComplete: {
                Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.completionStatus(r))]) }
            }, onOpen: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) {
                    expandedID = expanded ? nil : r.integer("id")
                }
            })
            if expanded {
                NativeTaskControls(record: r)
                    .padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small)
                    .transition(.opacity)
            }
        }
        .modifier(NativeChecklistListRow(first: siblings.first?.integer("id") == r.integer("id"), last: siblings.last?.integer("id") == r.integer("id")))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { Task { await store.run("deleteTask", args: [.int(r.integer("id"))]) } } label: { Label("Elimina", systemImage: "trash") }
                .tint(NativeDesign.danger)
            Button(NativeTaskList.section(r) == "waiting" ? "Riattiva" : "In attesa") {
                Task { await store.run("setTaskStatus", ["id": .int(r.integer("id")), "status": .string(NativeTaskList.section(r) == "waiting" ? "todo" : "waiting")]) }
            }.tint(NativeDesign.surface)
        }.disabled(store.busy)
    }
}

/// Contextual editing stays under its task; full date/category editing reuses TaskEditor.
private struct NativeTaskControls: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    let record: Record
    @State private var title = ""
    @State private var notes = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            TextField("Titolo", text: $title, axis: .vertical).accessibilityIdentifier("inline-task-title")
            TextField("Aggiungi nota", text: $notes, axis: .vertical).font(.subheadline).foregroundStyle(NativeDesign.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NativeDesign.Space.small) {
                    Button { router.sheet = .task(record) } label: { Label(record.text("due_date").isEmpty ? "Data e dettagli" : record.text("due_date"), systemImage: "calendar") }
                        .accessibilityIdentifier("inline-task-details")
                    Button(NativeTaskList.section(record) == "waiting" ? "Riattiva" : "In attesa") {
                        Task { await store.run("setTaskStatus", ["id": .int(record.integer("id")), "status": .string(NativeTaskList.section(record) == "waiting" ? "todo" : "waiting")]) }
                    }
                    Button(role: .destructive) { Task { await store.run("deleteTask", args: [.int(record.integer("id"))]) } } label: { Image(systemName: "trash").foregroundStyle(NativeDesign.danger) }.accessibilityLabel("Elimina attività")
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
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        do {
            try await store.perform("saveTask", ["id": .int(record.integer("id")), "title": .string(title), "notes": .string(notes), "list_kind": .string(category), "due_date": hasDue ? .string(CivilDate.day(due)) : .null, "scheduled_date": hasScheduled ? .string(CivilDate.day(scheduled)) : .null])
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
    var body: some View {
        Form {
            Section("Routine giornaliere") {
                ForEach(store.routines.map { DisplayRecord($0) }) { item in
                    Button(item.value.text("title")) { editingID = item.value.integer("id"); name = item.value.text("title") }
                        .swipeActions { Button("Elimina", role: .destructive) { Task { await store.run("deleteRoutine", args: [.int(item.value.integer("id"))]) } } }
                }
            }
            Section(editingID == 0 ? "Aggiungi routine" : "Modifica routine") {
                TextField("Nome", text: $name)
                Button("Salva") { Task { await store.run("saveRoutine", ["id": .int(editingID), "title": .string(name)]); editingID = 0; name = "" } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
                if editingID != 0 { Button("Annulla modifica") { editingID = 0; name = "" } }
            }
            Text("Massimo otto routine. Ogni giorno ha i propri completamenti.").font(.caption).foregroundStyle(NativeDesign.secondary)
        }.modifier(NativeListAppearance()).navigationTitle("Routine").toolbar { DoneButton() }
    }
}
