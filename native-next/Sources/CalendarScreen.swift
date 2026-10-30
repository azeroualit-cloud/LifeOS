import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
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
    private var focusMonth: String { visibleMonth ?? store.calendarMonth }
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: NativeDesign.Space.none) {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NativeDesign.Space.small, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { month in
                        Section {
                            monthGrid(month)
                        } header: {
                            Text(NativeCalendarWindow.monthLabel(month)).font(.title2.bold()).foregroundStyle(Color.primary)
                                .accessibilityLabel(CivilDate.monthTitle(month)).accessibilityIdentifier("calendar-month-heading-" + month).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, NativeDesign.Space.xs).background(NativeDesign.canvas)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }.id(month)
                    }
                }.scrollTargetLayout()
                    .padding(.horizontal, NativeDesign.Layout.screenInset)
                    .padding(.bottom, NativeDesign.Layout.scrollClearance)
            }
            .scrollPosition(id: $visibleMonth, anchor: .top)
            .accessibilityIdentifier("calendar-scroll")
            .safeAreaInset(edge: .top, spacing: NativeDesign.Space.none) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    brushPanel.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    ProgressView().progressViewStyle(.linear).frame(height: NativeDesign.Space.xxs)
                        .opacity(loading ? 1 : 0).accessibilityLabel("Aggiornamento calendario")
                        .accessibilityHidden(!loading).allowsHitTesting(false)
                    if let loadError {
                        HStack { NativeInlineMessage(text: loadError); Button("Riprova") { reload += 1 } }
                    }
                    HStack {
                        ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, name in
                            Text(name).font(.caption).foregroundStyle(NativeDesign.secondary).frame(maxWidth: .infinity)
                        }
                    }.padding(.vertical, NativeDesign.Space.small).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }.padding(.horizontal, NativeDesign.Layout.screenInset).background(NativeDesign.canvas)
            }
            .onChange(of: jumpMonth) { _, month in
                guard let month else { return }
                ensureWindow(around: month)
                withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { proxy.scrollTo(month, anchor: .top) }
                visibleMonth = month
                let day = selected
                if day.hasPrefix(month) {
                    Task { @MainActor in
                        await Task.yield()
                        guard selected == day else { return }
                        proxy.scrollTo(day, anchor: .bottom)
                    }
                }
                jumpMonth = nil
            }
        }.frame(height: geometry.size.height * NativeDesign.Layout.calendarPaneFraction)
        Divider()
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                if selected.isEmpty {
                    Text("Seleziona un giorno").font(NativeDesign.body).foregroundStyle(NativeDesign.secondary)
                } else { dayCard }
                DisclosureGroup("Esporta turni su Apple (facoltativo)", isExpanded: $appleExport) { ShiftCalendarPanel() }
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.bottom, NativeDesign.Layout.scrollClearance)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("calendar-day-pane")
        }
        }.background(NativeDesign.canvas)
        .onAppear {
            if months.isEmpty {
                let month = String((router.requestedCalendarDay ?? router.calendarDay).prefix(7))
                store.calendarMonth = month
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
        .onChange(of: router.calendarFocusRequest) { _, _ in
            selected = router.calendarDay; jumpMonth = String(selected.prefix(7))
        }
        .onChange(of: painting) { _, _ in
            if !selected.isEmpty { jumpMonth = String(selected.prefix(7)) }
        }
        .onChange(of: visibleMonth) { _, month in if let month { ensureWindow(around: month) } }
        .onChange(of: NativeCalendarSource(life: store.life, demo: store.isDemo, origin: store.server?.absoluteString)) { _, _ in
            monthData = [:]; seedSnapshot(); rebuildMonth(); reload += 1
        }
        .task(id: focusMonth + "-" + String(reload)) { await loadMonth(focusMonth) }
    }
    private func preferredDay(in month: String) -> String {
        if router.calendarDay.hasPrefix(month) { return router.calendarDay }
        return CivilDate.day().hasPrefix(month) ? CivilDate.day() : month + "-01"
    }
    private func ensureWindow(around month: String) {
        if let index = months.firstIndex(of: month), index >= 2 && index < months.count - 2 { return }
        let next = NativeCalendarWindow.extended(months, around: month)
        guard next != months else { return }
        let added = Set(next).subtracting(months)
        months = next
        let retained = Set(next)
        monthData = monthData.filter { retained.contains($0.key) }
        rebuildMonth(changed: added)
    }
    private func seedSnapshot() {
        let month = store.life.text("month", fallback: store.calendarMonth)
        for key in NativeCalendarWindow.coveredMonths(around: month, within: months) { monthData[key] = store.life }
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
            for key in NativeCalendarWindow.coveredMonths(around: month, within: months) { monthData[key] = data }
            rebuildMonth(changed: Set(NativeCalendarWindow.coveredMonths(around: month, within: months))); loading = false
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            loading = false; loadError = error.localizedDescription
        }
    }
    private func rebuildMonth(changed: Set<String>? = nil) {
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
        var grids = monthDays.filter { months.contains($0.key) }
        for month in months where grids[month] == nil || changed?.contains(month) != false {
            grids[month] = CivilDate.gridDates(month).map { date in
                let day = CivilDate.day(date)
                let weekday = CivilDate.calendar.component(.weekday, from: date)
                return CalendarDayPresentation(day: day, label: CivilDate.label(date), shift: allShifts[day].flatMap(ShiftKind.init(rawValue:)), hasEvents: !(eventsByDay[day] ?? []).isEmpty || !(tasksByDay[day] ?? []).isEmpty, isToday: day == today, isWeekend: weekday == 1 || weekday == 7, isCurrentMonth: day.hasPrefix(month))
            }
        }
        monthDays = grids
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
                                .id(item.day).accessibilityIdentifier("calendar-day-" + item.day)
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
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { painting.toggle(); brush = painting ? "morning" : "consult" } } label: { Label(painting ? "Fine" : "Dipingi turni", systemImage: "paintbrush.pointed").labelStyle(.iconOnly).frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle()) }.accessibilityIdentifier("toggle-shift-paint")
                Spacer()
                if let lastShift { Button("Annulla") { Task { await store.run("paintShift", ["day": .string(lastShift.0), "kind": .string(lastShift.1)]); if store.error == nil { self.lastShift = nil } } }.disabled(store.busy) }
                NativeIconButton(symbol: "chevron.left", label: "Mese precedente") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: -1) }.disabled(store.busy)
                NativeIconButton(symbol: "chevron.right", label: "Mese successivo") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: 1) }.disabled(store.busy)
            }.font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget)
            if painting {
                if !typeSize.isAccessibilitySize {
                    Text("Scegli un turno, poi tocca i giorni da assegnare. Usa Cancella per rimuoverlo.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.xs) { ForEach(ShiftKind.allCases) { kind in
                        NativeShiftBrushOption(kind: kind, brush: $brush)
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
                if r.text("day") < CivilDate.day() { router.sheet = .event(r); return }
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
private struct NativeShiftBrushOption: View {
    let kind: ShiftKind
    @Binding var brush: String
    @ScaledMetric(relativeTo: .caption) private var width = NativeDesign.Layout.shiftBrushWidth
    @ScaledMetric(relativeTo: .caption) private var height = NativeDesign.Layout.shiftBrushHeight
    var body: some View {
        Button { brush = kind.rawValue } label: {
            VStack(spacing: NativeDesign.Space.xs) {
                Label { Text(String(kind.title.prefix(1))).foregroundStyle(Color.primary) } icon: { Image(systemName: kind.symbol).foregroundStyle(kind.color) }.font(.caption.weight(.semibold))
                if !kind.time.isEmpty { Text(kind.time.replacingOccurrences(of: ":00", with: "")).font(.caption2).foregroundStyle(NativeDesign.secondary) }
            }.frame(width: width, height: height)
                .modifier(NativeSelectionSurface(selected: brush == kind.rawValue, tint: kind.color, outlined: true))
        }.buttonStyle(NativePressStyle()).foregroundStyle(kind.color)
            .accessibilityLabel(kind.title + (kind.time.isEmpty ? "" : ", " + kind.time))
            .accessibilityHint("Tocca i giorni per applicare questo turno")
            .accessibilityIdentifier("shift-brush-" + kind.rawValue).accessibilityAddTraits(brush == kind.rawValue ? .isSelected : [])
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
enum NativeCalendarDayAppearance { case month, week }

struct CalendarDayCell: View, Equatable {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let item: CalendarDayPresentation
    let active: Bool
    var appearance: NativeCalendarDayAppearance = .month
    @ScaledMetric(relativeTo: .subheadline) private var numberSize = NativeDesign.Layout.calendarDayNumber
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.item == rhs.item && lhs.active == rhs.active && lhs.appearance == rhs.appearance }
    var body: some View {
        let color = item.shift?.color ?? NativeDesign.accent
        VStack(spacing: NativeDesign.Space.xxs) {
            Text(String(Int(item.day.suffix(2)) ?? 0)).font(.subheadline.weight(active || item.isToday ? .semibold : .regular)).monospacedDigit()
                .foregroundStyle(active ? (item.shift == nil ? NativeDesign.canvas : Color.black.opacity(0.85)) : appearance == .month && item.isWeekend ? NativeDesign.secondary : Color.primary)
                .minimumScaleFactor(0.8).lineLimit(1).frame(width: numberSize, height: numberSize)
                .background(active ? color : .clear, in: Circle())
                .overlay(Circle().stroke(item.isToday && !active ? color : .clear, lineWidth: 1))
            NativeShiftBadge(shift: item.shift)
            Circle().fill(item.hasEvents ? color : Color.clear).frame(width: NativeDesign.Space.xs, height: NativeDesign.Space.xs)
        }.frame(maxWidth: .infinity).frame(minHeight: NativeDesign.Layout.calendarDayHeight)
            .contentShape(Rectangle()).opacity(appearance == .week || item.isCurrentMonth ? 1 : 0.38)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: active)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: item.shift)
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}
extension ShiftKind {
    var color: Color { LifeOSShiftPalette.color(rawValue) }
    var symbol: String {
        switch self { case .morning: return "sunrise"; case .afternoon: return "sun.max"; case .night: return "moon"; case .rest: return "leaf"; case .holiday: return "sun.horizon"; case .erase: return "eraser" }
    }
}
struct EventEditor: View {
    let record: Record
    var body: some View { NativeActivityEditor(record: record, source: "event") }
}
