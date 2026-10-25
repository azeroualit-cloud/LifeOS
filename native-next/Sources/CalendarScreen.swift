import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var appleExport = false
    @State private var selected = ""
    @State private var brush = "consult"
    @State private var lastShift: (String, String)?
    @State private var months: [String] = []
    @State private var visibleMonth: String?
    @State private var jumpMonth: String?
    @State private var monthDays: [String: [CalendarDayPresentation]] = [:]
    @State private var monthData: [String: Record] = [:]
    @State private var eventsByDay: [String: [Record]] = [:]
    @State private var tasksByDay: [String: [Record]] = [:]
    @State private var loading = false
    @State private var loadError: String?
    @State private var reload = 0
    @ScaledMetric(relativeTo: .caption) private var brushWidth = 132.0
    @ScaledMetric(relativeTo: .caption) private var brushHeight = 64.0
    private var focusMonth: String { visibleMonth ?? store.calendarMonth }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                    ForEach(months, id: \.self) { month in
                        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                            Text(CivilDate.monthTitle(month)).font(.title2.bold()).foregroundStyle(Color.primary)
                            monthGrid(month)
                            if monthData[month] == nil && !store.isDemo {
                                Text("Eventi e turni di questo mese non ancora caricati").font(.caption).foregroundStyle(NativeDesign.secondary)
                            }
                            if selected.hasPrefix(month) { dayCard }
                        }.id(month)
                    }
                    DisclosureGroup("Esporta turni su Apple (facoltativo)", isExpanded: $appleExport) { ShiftCalendarPanel() }
                }.scrollTargetLayout()
                    .padding(.horizontal, NativeDesign.Layout.screenInset)
                    .padding(.bottom, NativeDesign.Layout.scrollClearance)
            }
            .scrollPosition(id: $visibleMonth, anchor: .top)
            .accessibilityIdentifier("calendar-scroll")
            .safeAreaInset(edge: .top, spacing: NativeDesign.Space.none) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    monthHeader
                    brushPanel
                    if loading { ProgressView("Aggiornamento calendario").font(.caption) }
                    if let loadError {
                        HStack { NativeInlineMessage(text: loadError); Button("Riprova") { reload += 1 } }
                    }
                    HStack {
                        ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, name in
                            Text(name).font(.caption).foregroundStyle(NativeDesign.secondary).frame(maxWidth: .infinity)
                        }
                    }.padding(.vertical, NativeDesign.Space.small)
                }.padding(.horizontal, NativeDesign.Layout.screenInset).background(NativeDesign.canvas)
            }
            .onChange(of: jumpMonth) { _, month in
                guard let month else { return }
                ensureWindow(around: month)
                withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { proxy.scrollTo(month, anchor: .top) }
                visibleMonth = month
                jumpMonth = nil
            }
        }.background(NativeDesign.canvas)
        .onAppear {
            if months.isEmpty {
                let month = store.calendarMonth
                months = NativeCalendarWindow.months(around: month)
                selected = preferredDay(in: month); router.calendarDay = selected
                seedSnapshot(); rebuildMonth(); visibleMonth = month; jumpMonth = month
            }
        }
        .onChange(of: selected) { _, day in router.calendarDay = day }
        .onChange(of: router.calendarDay) { _, day in
            guard day != selected, !day.isEmpty else { return }
            selected = day; jumpMonth = String(day.prefix(7))
        }
        .onChange(of: visibleMonth) { _, month in if let month { ensureWindow(around: month) } }
        .onChange(of: store.life) { _, _ in
            monthData = [:]; seedSnapshot(); rebuildMonth(); reload += 1
        }
        .task(id: focusMonth + "-" + String(reload)) { await loadMonth(focusMonth) }
    }
    private func preferredDay(in month: String) -> String {
        if router.calendarDay.hasPrefix(month) { return router.calendarDay }
        return CivilDate.day().hasPrefix(month) ? CivilDate.day() : month + "-01"
    }
    private func ensureWindow(around month: String) {
        if !months.contains(month) || month == months.first || month == months.last {
            months = Array(Set(months + NativeCalendarWindow.months(around: month))).sorted()
            rebuildMonth()
        }
    }
    private func seedSnapshot() {
        let month = store.life.text("month", fallback: store.calendarMonth)
        for key in NativeCalendarWindow.months(around: month, radius: 1) { monthData[key] = store.life }
    }
    private func loadMonth(_ month: String) async {
        guard !months.isEmpty else { return }
        loading = false; loadError = nil
        guard !store.isDemo, monthData[month] == nil else { return }
        guard store.server != nil else { loadError = "Mese non disponibile offline. Collega Life OS per caricarlo."; return }
        do {
            try await Task.sleep(nanoseconds: NativeDesign.Motion.calendarDebounce)
            loading = true
            let result = try await store.read("getLifeData", args: [.string(month)])
            try Task.checkCancellation()
            let data = result.object
            guard case .array? = data["events"], case .array? = data["shifts"] else { throw Message(text: "Risposta calendario non valida.") }
            for key in NativeCalendarWindow.months(around: month, radius: 1) { monthData[key] = data }
            rebuildMonth(); loading = false
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            loading = false; loadError = error.localizedDescription
        }
    }
    private func rebuildMonth() {
        tasksByDay = Dictionary(grouping: store.tasks, by: { $0.text("scheduled_date") })
        var allEvents: [String: Record] = [:]
        var allShifts: [String: String] = [:]
        for month in months {
            let data = monthData[month] ?? [:]
            let source: [Record]
            if store.isDemo {
                source = store.expandedEvents(low: month + "-01", high: NativeCalendarWindow.offset(month, by: 1) + "-01", source: store.life.records("events"))
            } else { source = data.records("events").filter { $0.text("day").hasPrefix(month) } }
            for event in source { allEvents[String(event.integer("id")) + ":" + event.text("day")] = event }
            for shift in (store.isDemo ? store.life : data).records("shifts") where shift.text("day").hasPrefix(month) { allShifts[shift.text("day")] = shift.text("kind") }
        }
        // Mutations already invalidate and reseed monthData in onChange(store.life).
        // Keep a newer monthly read authoritative over the older global snapshot.
        eventsByDay = Dictionary(grouping: Array(allEvents.values).sorted { ($0.text("start_time"), $0.integer("id")) < ($1.text("start_time"), $1.integer("id")) }, by: { $0.text("day") })
        let today = CivilDate.day()
        monthDays = Dictionary(uniqueKeysWithValues: months.map { month in
            (month, CivilDate.grid(month).map { day in
                let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(day))
                return CalendarDayPresentation(day: day, label: CivilDate.label(day), shift: allShifts[day].flatMap(ShiftKind.init(rawValue:)), hasEvents: !(eventsByDay[day] ?? []).isEmpty || !(tasksByDay[day] ?? []).isEmpty, isToday: day == today, isWeekend: weekday == 1 || weekday == 7, isCurrentMonth: day.hasPrefix(month))
            })
        })
    }
    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
            Spacer(minLength: NativeDesign.Space.small)
            NativeIconButton(symbol: "chevron.left", label: "Mese precedente") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: -1) }
            NativeIconButton(symbol: "chevron.right", label: "Mese successivo") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: 1) }
        }.disabled(store.busy).accessibilityElement(children: .contain)
    }
    private func goToToday() {
        selected = CivilDate.day(); router.calendarDay = selected
        jumpMonth = String(selected.prefix(7))
    }
    private func monthGrid(_ month: String) -> some View {
        let days = monthDays[month] ?? []
        return Grid(horizontalSpacing: NativeDesign.Space.xs, verticalSpacing: NativeDesign.Space.none) {
            ForEach(0..<(days.count / 7), id: \.self) { week in
                GridRow {
                    ForEach(0..<7, id: \.self) { index in
                        let item = days[week * 7 + index]
                        if item.isCurrentMonth {
                            Button {
                                if !store.busy { store.calendarMonth = month }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration)) { selected = !painting && selected == item.day ? "" : item.day }
                                if painting {
                                    let old = item.shift?.rawValue ?? "erase", kind = brush
                                    Task {
                                        do {
                                            try await store.perform("paintShift", ["day": .string(item.day), "kind": .string(kind)])
                                            lastShift = (item.day, old)
                                        } catch { store.error = error.localizedDescription }
                                    }
                                }
                            } label: { CalendarDayCell(item: item, active: selected == item.day).equatable() }
                                .buttonStyle(NativePressStyle()).disabled(painting && (store.busy || (!store.isDemo && monthData[month] == nil)))
                                .accessibilityIdentifier("calendar-day-" + item.day)
                                .accessibilityLabel(item.label + ", " + (item.shift?.title ?? "nessun turno"))
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(minHeight: NativeDesign.Layout.calendarDayHeight).accessibilityHidden(true)
                        }
                    }
                }
                GridRow { Divider().gridCellColumns(7).gridCellUnsizedAxes(.horizontal) }
            }
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    @State private var painting = false
    private var brushPanel: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(spacing: NativeDesign.Space.large) {
                Button(action: goToToday) {
                    Text("Oggi").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
                }
                    .accessibilityIdentifier("calendar-today").disabled(store.busy)
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { painting.toggle(); brush = painting ? "morning" : "consult" } } label: { Label(painting ? "Fine" : "Dipingi turni", systemImage: "paintbrush.pointed").frame(minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle()) }.accessibilityIdentifier("toggle-shift-paint")
                Spacer()
                if let lastShift { Button("Annulla") { Task { await store.run("paintShift", ["day": .string(lastShift.0), "kind": .string(lastShift.1)]); if store.error == nil { self.lastShift = nil } } }.disabled(store.busy) }
            }.font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget)
            if painting {
                Text("Scegli un turno, poi tocca i giorni da assegnare. Usa Cancella per rimuoverlo.").font(.caption).foregroundStyle(NativeDesign.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) { ForEach(ShiftKind.allCases) { kind in
                        Button { brush = kind.rawValue } label: {
                            VStack(spacing: NativeDesign.Space.xs) {
                                Label { Text(kind.title).foregroundStyle(Color.primary) } icon: { Image(systemName: kind.symbol).foregroundStyle(kind.color) }.font(.caption.weight(.semibold))
                                if !kind.time.isEmpty { Text(kind.time).font(.caption2).foregroundStyle(NativeDesign.secondary) }
                            }
                                .padding(NativeDesign.Space.medium).frame(width: brushWidth, height: brushHeight)
                                .modifier(NativeSelectionSurface(selected: brush == kind.rawValue, tint: kind.color, outlined: true))
                        }.buttonStyle(NativePressStyle()).foregroundStyle(kind.color).accessibilityIdentifier("shift-brush-" + kind.rawValue).accessibilityAddTraits(brush == kind.rawValue ? .isSelected : [])
                    } }
                }
            }
        }.buttonStyle(NativePressStyle())
    }
    private var dayCard: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            HStack {
                Text(CivilDate.label(selected)).font(NativeDesign.heading)
                Spacer()
                if painting { Label("Pennello attivo", systemImage: "paintbrush.pointed").font(.caption).foregroundStyle(NativeDesign.accent) }
            }
            if let shift = monthDays[String(selected.prefix(7))]?.first(where: { $0.day == selected })?.shift {
                HStack(spacing: NativeDesign.Space.small) {
                    RoundedRectangle(cornerRadius: NativeDesign.progressRadius).fill(shift.color)
                        .frame(width: NativeDesign.Layout.calendarMarker, height: NativeDesign.Layout.touchTarget).accessibilityHidden(true)
                    Image(systemName: shift.symbol).font(NativeDesign.symbol).foregroundStyle(shift.color)
                        .frame(width: NativeDesign.Layout.touchTarget).accessibilityHidden(true)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { Text(shift.title).font(NativeDesign.body); Text("Turno").font(.caption).foregroundStyle(NativeDesign.secondary) }
                            Spacer(minLength: NativeDesign.Space.small)
                            Text(shift.time).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                        }
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text(shift.title).font(NativeDesign.body)
                            Text(shift.time.isEmpty ? "Turno" : shift.time).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                        }
                    }
                }.frame(minHeight: NativeDesign.Layout.touchTarget).accessibilityElement(children: .combine)
                Divider()
            }
            let dayEvents = eventsByDay[selected] ?? []
            let dayTasks = tasksByDay[selected] ?? []
            ForEach(dayEvents.map { DisplayRecord($0) }) { item in eventRow(item.value); Divider() }
            ForEach(dayTasks.map { DisplayRecord($0) }) { item in
                NativeChecklistRow(title: item.value.text("title"), checked: item.value.text("status") == "done", completionLabel: "Cambia completamento " + item.value.text("title"), onComplete: {
                    Task { await store.run("setTaskStatus", ["id": .int(item.value.integer("id")), "status": .string(NativeTaskList.completionStatus(item.value))]) }
                }, onOpen: { router.sheet = .task(item.value) }).disabled(store.busy)
                Divider()
            }
            Button { router.sheet = .event(["day": .string(selected)]) } label: {
                HStack(spacing: NativeDesign.Space.small) {
                    Image(systemName: "plus.circle").font(NativeDesign.symbol).frame(width: NativeDesign.Layout.touchTarget)
                    Text("Aggiungi evento").font(NativeDesign.body)
                }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
            }.buttonStyle(NativePressStyle()).accessibilityIdentifier("calendar-add-event")
        }.padding(.top, NativeDesign.Space.small)
    }
    private func eventRow(_ r: Record) -> some View {
        let time = r.text("start_time"), location = r.text("location")
        return HStack(spacing: NativeDesign.Space.small) {
            RoundedRectangle(cornerRadius: NativeDesign.progressRadius).fill(NativeDesign.accent.opacity(0.65))
                .frame(width: NativeDesign.Layout.calendarMarker, height: NativeDesign.Layout.touchTarget).accessibilityHidden(true)
            NativeCompletionButton(checked: r.text("occurrence_status") == "done", label: "Cambia completamento evento " + r.text("title")) {
                Task { await store.run("setEventOccurrence", ["id": .int(r.integer("id")), "day": .string(r.text("day")), "status": .string(r.text("occurrence_status") == "done" ? "open" : "done")]) }
            }.accessibilityIdentifier("event-check-" + String(r.integer("id")))
            Button { router.sheet = .event(r) } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: NativeDesign.Space.small) {
                        NativeRowText(title: r.text("title"), subtitle: location, completed: r.text("occurrence_status") == "done", titleIdentifier: "event-title-" + String(r.integer("id")))
                        Text(time.isEmpty ? "Tutto il giorno" : time).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        NativeRowText(title: r.text("title"), subtitle: location, completed: r.text("occurrence_status") == "done", titleIdentifier: "event-title-" + String(r.integer("id")))
                        Text(time.isEmpty ? "Tutto il giorno" : time).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                    }
                }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.borderless).accessibilityLabel(r.text("title"))
                .accessibilityValue([time.isEmpty ? "Tutto il giorno" : time, location].filter { !$0.isEmpty }.joined(separator: ", "))
        }.disabled(store.busy)
    }

}
struct CalendarDayPresentation: Equatable {
    let day: String
    let label: String
    let shift: ShiftKind?
    let hasEvents: Bool
    let isToday: Bool
    let isWeekend: Bool
    let isCurrentMonth: Bool
}
struct CalendarDayCell: View, Equatable {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let item: CalendarDayPresentation
    let active: Bool
    @ScaledMetric(relativeTo: .subheadline) private var numberSize = NativeDesign.Layout.calendarDayNumber
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.item == rhs.item && lhs.active == rhs.active }
    var body: some View {
        let color = item.shift?.color ?? NativeDesign.accent
        VStack(spacing: NativeDesign.Space.xxs) {
            Text(String(Int(item.day.suffix(2)) ?? 0)).font(.subheadline.weight(active || item.isToday ? .semibold : .regular)).monospacedDigit()
                .foregroundStyle(active ? (item.shift == nil ? NativeDesign.canvas : Color.black.opacity(0.85)) : item.isWeekend ? NativeDesign.secondary : Color.primary)
                .minimumScaleFactor(0.8).lineLimit(1).frame(width: numberSize, height: numberSize)
                .background(active ? color : .clear, in: Circle())
                .overlay(Circle().stroke(item.isToday && !active ? color : .clear, lineWidth: 1))
            NativeShiftBadge(shift: item.shift)
            Circle().fill(item.hasEvents ? color : Color.clear).frame(width: NativeDesign.Space.xs, height: NativeDesign.Space.xs)
        }.frame(maxWidth: .infinity).frame(minHeight: NativeDesign.Layout.calendarDayHeight)
            .contentShape(Rectangle()).opacity(item.isCurrentMonth ? 1 : 0.38)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: active)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: item.shift)
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}
extension ShiftKind {
    // Same hues as the original Life OS palette, with a restrained saturation increase.
    var color: Color {
        let light: UInt32, dark: UInt32
        switch self {
        case .morning: light = 0x8FACD9; dark = 0x639BCF
        case .afternoon: light = 0x9BCB83; dark = 0x6CAF7A
        case .night: light = 0x727780; dark = 0xADB2BC
        case .rest: light = 0xE79862; dark = 0xDF986D
        case .holiday: light = 0xA88B18; dark = 0xDEC34E
        case .erase: return .secondary
        }
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    var symbol: String {
        switch self { case .morning: return "sunrise"; case .afternoon: return "sun.max"; case .night: return "moon"; case .rest: return "leaf"; case .holiday: return "sun.horizon"; case .erase: return "eraser" }
    }
}
struct EventEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let record: Record
    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var start = Date()
    @State private var end = Date()
    @State private var hasTime = false
    @State private var hasEnd = false
    @State private var frequency = "none"
    @State private var until = Date()
    @State private var hasUntil = false
    @State private var fromHere = false
    @State private var saving = false
    @State private var error: String?
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section { TextField("Titolo", text: $title); DatePicker("Giorno", selection: $date, displayedComponents: .date); TextField("Luogo", text: $location) }
            Section("Orario") {
                Toggle("Ora iniziale", isOn: $hasTime)
                if hasTime {
                    DatePicker("Inizio", selection: $start, displayedComponents: .hourAndMinute)
                    Toggle("Ora finale", isOn: $hasEnd)
                    if hasEnd { DatePicker("Fine", selection: $end, displayedComponents: .hourAndMinute) }
                }
            }
            Section("Ripetizione") {
                Picker("Frequenza", selection: $frequency) { Text("Mai").tag("none"); Text("Ogni settimana").tag("weekly"); Text("Ogni mese").tag("monthly"); Text("Ogni anno").tag("yearly") }
                if frequency != "none" { Toggle("Data finale", isOn: $hasUntil); if hasUntil { DatePicker("Fino al", selection: $until, in: date..., displayedComponents: .date) } }
                if record.integer("id") > 0 && record.text("frequency", fallback: "none") != "none" {
                    Toggle("Modifica da questa occorrenza", isOn: $fromHere)
                    Text("Le occorrenze precedenti restano nello storico.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
            }
            Section("Note") { TextEditor(text: $notes).frame(minHeight: 90) }
            if record.integer("id") > 0 {
                Section {
                    Button(record.text("occurrence_status") == "done" ? "Riapri questa occorrenza" : "Segna fatta questa occorrenza") {
                        Task { await store.run("setEventOccurrence", ["id": .int(record.integer("id")), "day": .string(record.text("day")), "status": .string(record.text("occurrence_status") == "done" ? "open" : "done")]); if store.error == nil { dismiss() } }
                    }
                    Button("Elimina solo questa occorrenza", role: .destructive) { Task { await store.run("setEventOccurrence", ["id": .int(record.integer("id")), "day": .string(record.text("day")), "status": .string("skipped")]); if store.error == nil { dismiss() } } }
                    Button("Elimina intera serie", role: .destructive) { confirmDelete = true }
                }.disabled(saving || store.busy)
            }
            if let error { NativeInlineMessage(text: error) }
        }.modifier(NativeListAppearance()).navigationTitle(record.integer("id") > 0 ? "Modifica evento" : "Nuovo evento").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) { Button("Salva") { Task { await save() } }.disabled(saving || store.busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .confirmationDialog("Eliminare la serie e tutti gli stati delle occorrenze?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Elimina serie", role: .destructive) { Task { await store.run("deleteEvent", args: [.int(record.integer("id"))]); if store.error == nil { dismiss() } } } }
        .onChange(of: fromHere) { _, value in date = CivilDate.date(value ? record.text("day") : record.text("series_day", fallback: record.text("day"))) }
        .onAppear {
            title = record.text("title"); location = record.text("location"); notes = record.text("notes")
            date = CivilDate.date(record.text("series_day", fallback: record.text("day", fallback: CivilDate.day())))
            frequency = record.text("frequency", fallback: "none"); hasTime = !record.text("start_time").isEmpty; hasEnd = !record.text("end_time").isEmpty
            start = clockDate(record.text("start_time", fallback: "09:00")); end = clockDate(record.text("end_time", fallback: "10:00"))
            hasUntil = !record.text("until_day").isEmpty; until = CivilDate.date(record.text("until_day", fallback: CivilDate.adding(365, to: CivilDate.day())))
        }
    }
    private func clockDate(_ text: String) -> Date {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        return CivilDate.calendar.date(bySettingHour: parts.first ?? 9, minute: parts.last ?? 0, second: 0, of: Date()) ?? Date()
    }
    private func clock(_ date: Date) -> String {
        let parts = CivilDate.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
    private func save() async {
        saving = true; defer { saving = false }
        var payload: Record = ["id": .int(record.integer("id")), "title": .string(title), "day": .string(CivilDate.day(date)), "location": .string(location), "notes": .string(notes),
            "start_time": hasTime ? .string(clock(start)) : .null, "end_time": hasTime && hasEnd ? .string(clock(end)) : .null,
            "frequency": .string(frequency), "until_day": hasUntil && frequency != "none" ? .string(CivilDate.day(until)) : .null]
        if fromHere { payload["split_from"] = record["day"] }
        do { try await store.perform(fromHere ? "splitEventSeries" : "saveEvent", payload); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
