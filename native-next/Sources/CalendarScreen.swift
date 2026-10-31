import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var showingDay = false
    private var selected: String {
        get { router.calendarDay }
        nonmutating set { router.calendarDay = newValue }
    }
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
        ZStack {
            if showingDay {
                dayAgenda.transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                monthOverview.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }.background(NativeDesign.canvas)
        .animation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.navigationResponse), value: showingDay)
        .onAppear {
            if months.isEmpty {
                let month = String(router.calendarDay.prefix(7))
                store.calendarMonth = month
                months = NativeCalendarWindow.months(around: month)
                selected = preferredDay(in: month)
                seedSnapshot(); rebuildMonth(); visibleMonth = month; jumpMonth = month
                showingDay = router.calendarOpensDay
            }
        }
        .onChange(of: router.calendarFocusRequest) { _, _ in
            selected = router.calendarDay
            showingDay = router.calendarOpensDay
            jumpMonth = String(selected.prefix(7))
        }
        .onChange(of: router.calendarDay) { _, day in
            if showingDay { let month = String(day.prefix(7)); ensureWindow(around: month); visibleMonth = month }
        }
        .onChange(of: visibleMonth) { _, month in if let month { ensureWindow(around: month) } }
        .onChange(of: NativeCalendarSource(life: store.life, demo: store.isDemo, origin: store.server?.absoluteString)) { old, new in
            if let changes = new.shiftChanges(from: old) { patchShifts(changes) }
            else { monthData = [:]; seedSnapshot(); rebuildMonth(); reload += 1 }
        }
        .task(id: focusMonth + "-" + String(reload)) { await loadMonth(focusMonth) }
    }
    private var weekdayLabels: some View {
        HStack(spacing: NativeDesign.Space.none) {
            ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, name in
                Text(name).font(.caption.weight(.medium)).foregroundStyle(NativeDesign.secondary).frame(maxWidth: .infinity)
            }
        }.padding(.vertical, NativeDesign.Space.small).accessibilityHidden(true)
    }
    private var monthOverview: some View {
        VStack(spacing: NativeDesign.Space.none) {
            brushPanel.padding(.horizontal, NativeDesign.Layout.screenInset)
            if let loadError { HStack { NativeInlineMessage(text: loadError); Button("Riprova") { reload += 1 } }.padding(.horizontal) }
            Text(CivilDate.monthTitle(focusMonth)).font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, NativeDesign.Layout.screenInset)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("calendar-month-heading-" + focusMonth)
            weekdayLabels.padding(.horizontal, NativeDesign.Layout.screenInset)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: NativeDesign.Space.none) {
                        ForEach(months, id: \.self) { month in
                            monthGrid(month).id(month)
                        }
                    }.scrollTargetLayout().padding(.horizontal, NativeDesign.Layout.screenInset)
                        .padding(.vertical, NativeDesign.Space.large).padding(.bottom, NativeDesign.Layout.scrollClearance)
                }.accessibilityIdentifier("calendar-scroll")
                .scrollPosition(id: $visibleMonth, anchor: .top)
                .task {
                    await Task.yield()
                    proxy.scrollTo(selected, anchor: .center)
                }
                .onChange(of: jumpMonth) { _, month in
                    guard let month else { return }
                    ensureWindow(around: month)
                    proxy.scrollTo(selected.hasPrefix(month) ? selected : month, anchor: selected.hasPrefix(month) ? .center : .top); visibleMonth = month; jumpMonth = nil
                }
            }
        }
    }
    private var dayAgenda: some View {
        VStack(spacing: NativeDesign.Space.none) {
            HStack {
                Button { showingDay = false; jumpMonth = String(selected.prefix(7)) } label: {
                    Label(NativeCalendarWindow.monthLabel(String(selected.prefix(7))), systemImage: "chevron.left")
                        .frame(minHeight: NativeDesign.Layout.touchTarget).padding(.horizontal, NativeDesign.Space.medium).modifier(NativeGlass())
                }.accessibilityIdentifier("calendar-back-month")
                Spacer()
                Button("Oggi") { selected = CivilDate.day(); store.calendarMonth = CivilDate.month() }
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
            }.buttonStyle(.plain).padding(.horizontal, NativeDesign.Layout.screenInset)
            weekdayLabels.padding(.horizontal, NativeDesign.Layout.screenInset)
            HStack(spacing: NativeDesign.Space.none) {
                ForEach(weekDays, id: \.self) { day in
                    Button { selected = day; store.calendarMonth = String(day.prefix(7)) } label: {
                        Text(String(Int(day.suffix(2)) ?? 0)).font(.title3.weight(.semibold))
                            .foregroundStyle(day == selected ? NativeDesign.canvas : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
                            .background { if day == selected { Circle().fill(Color.primary).frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget) } }
                            .contentShape(Rectangle())
                    }.accessibilityIdentifier("calendar-week-day-" + day).accessibilityLabel(CivilDate.label(day))
                        .accessibilityAddTraits(day == selected ? .isSelected : [])
                }
            }.buttonStyle(.plain).padding(.horizontal, NativeDesign.Layout.screenInset).padding(.bottom, NativeDesign.Space.small)
            Divider()
            Text(CivilDate.label(selected).capitalized).font(.headline).padding(.vertical, NativeDesign.Space.medium)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.none) {
                        allDayAgenda
                        dayTimeline
                        Button { router.sheet = .event(["day": .string(selected)]) } label: {
                            Label("Aggiungi evento", systemImage: "plus.circle").frame(minHeight: NativeDesign.Layout.touchTarget)
                        }.accessibilityIdentifier("calendar-add-event")
                    }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.bottom, NativeDesign.Layout.scrollClearance)
                }.accessibilityIdentifier("calendar-day-pane")
                .onAppear { proxy.scrollTo(6, anchor: .top) }
                .onChange(of: selected) { _, _ in proxy.scrollTo(6, anchor: .top) }
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: NativeDesign.Layout.calendarSwipeDistance).onEnded { gesture in
            guard abs(gesture.translation.width) > abs(gesture.translation.height) * 2 else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.selectionDuration)) {
                selected = CivilDate.adding(gesture.translation.width < 0 ? 1 : -1, to: selected)
                store.calendarMonth = String(selected.prefix(7))
            }
        })
    }
    private var dayTimeline: some View {
        let hourHeight = NativeDesign.Layout.timelineHour
        let minimumMinutes = Int(ceil(NativeDesign.Layout.touchTarget / hourHeight * 60))
        let slots = NativeCalendarTimeline.slots(events: eventsByDay[selected] ?? [], tasks: tasksByDay[selected] ?? [], minimumMinutes: minimumMinutes)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: NativeDesign.Space.none) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                        Text(String(format: "%02d:00", hour)).font(.caption).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                            .frame(width: NativeDesign.Layout.timelineLabel, alignment: .trailing)
                        Rectangle().fill(NativeDesign.secondary.opacity(0.25)).frame(height: NativeDesign.Space.hairline).frame(maxWidth: .infinity).padding(.top, NativeDesign.Space.small).accessibilityHidden(true)
                    }.frame(height: hourHeight, alignment: .top).id(hour)
                }
            }
            GeometryReader { geometry in
                let left = NativeDesign.Layout.timelineLabel + NativeDesign.Space.small
                let width = max(NativeDesign.Layout.touchTarget, geometry.size.width - left)
                if let shift = selectedShift, let start = NativeCalendarTimeline.minute(String(shift.time.prefix(5))) {
                    let end = NativeCalendarTimeline.minute(String(shift.time.suffix(5))) ?? start
                    let duration = end > start ? end - start : 1440 - start
                    VStack(alignment: .leading) {
                        Label(shift.title + " · " + shift.time, systemImage: shift.symbol).font(.caption.weight(.medium)).padding(NativeDesign.Space.xs)
                        Spacer(minLength: 0)
                    }.frame(width: width, height: CGFloat(duration) / 60 * hourHeight, alignment: .topLeading)
                        .foregroundStyle(shift.color).background(shift.color.opacity(0.08), in: RoundedRectangle(cornerRadius: NativeDesign.badgeRadius))
                        .offset(x: left, y: CGFloat(start) / 60 * hourHeight).allowsHitTesting(false)
                }
                ForEach(slots) { slot in
                    let laneWidth = width / CGFloat(slot.lanes)
                    Button { router.sheet = slot.source == "event" ? .event(slot.record) : .task(slot.record) } label: {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(slot.record.text("title")).font(.subheadline.weight(.medium)).lineLimit(2)
                            Text(slot.record.text(slot.source == "event" ? "start_time" : "scheduled_time")).font(.caption).monospacedDigit()
                        }.padding(NativeDesign.Space.xs)
                            .frame(width: max(0, laneWidth - NativeDesign.Space.xxs), height: max(NativeDesign.Layout.touchTarget, CGFloat(slot.end - slot.start) / 60 * hourHeight), alignment: .topLeading)
                            .background(NativeDesign.actionSurface, in: RoundedRectangle(cornerRadius: NativeDesign.badgeRadius))
                            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: NativeDesign.progressRadius).fill(NativeDesign.accent).frame(width: NativeDesign.Layout.calendarMarker) }
                            .clipped().contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(Color.primary)
                        .offset(x: left + CGFloat(slot.lane) * laneWidth, y: CGFloat(slot.start) / 60 * hourHeight)
                        .accessibilityIdentifier("calendar-timeline-" + slot.id)
                }
            }
        }.frame(height: hourHeight * 24)
    }
    private var weekDays: [String] {
        let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(selected))
        let monday = CivilDate.adding(-((weekday + 5) % 7), to: selected)
        return (0..<7).map { CivilDate.adding($0, to: monday) }
    }
    private var selectedShift: ShiftKind? { monthDays[String(selected.prefix(7))]?.first { $0.day == selected }?.shift }
    private var allDayAgenda: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            ForEach((eventsByDay[selected] ?? []).filter { $0.text("start_time").isEmpty }.map { DisplayRecord($0) }) { item in eventRow(item.value) }
            ForEach((tasksByDay[selected] ?? []).filter { $0.text("scheduled_time").isEmpty }.map { DisplayRecord($0) }) { item in calendarTaskRow(item.value) }
            if let shift = selectedShift, shift.time.isEmpty { Label(shift.title, systemImage: shift.symbol).foregroundStyle(shift.color).frame(minHeight: NativeDesign.Layout.touchTarget) }
        }.padding(.bottom, NativeDesign.Space.medium)
    }
    private func calendarTaskRow(_ record: Record) -> some View {
        NativeChecklistRow(title: record.text("title"), checked: record.text("status") == "done", completionLabel: "Cambia completamento " + record.text("title"), onComplete: {
            Task { await store.run("setTaskStatus", ["id": .int(record.integer("id")), "status": .string(NativeTaskList.completionStatus(record))]) }
        }, onOpen: { router.sheet = .task(record) }).disabled(store.busy)
    }
    private func patchShifts(_ changes: [String: String]) {
        for (day, raw) in changes {
            let month = String(day.prefix(7))
            for cachedMonth in NativeCalendarWindow.coveredMonths(around: month, within: Array(monthDays.keys)) {
                guard let grid = monthDays[cachedMonth] else { continue }
                monthDays[cachedMonth] = grid.map { item in
                    guard item.day == day else { return item }
                    return CalendarDayPresentation(day: item.day, label: item.label, shift: raw == "erase" ? nil : ShiftKind(rawValue: raw), hasEvents: item.hasEvents, isToday: item.isToday, isWeekend: item.isWeekend, isCurrentMonth: item.isCurrentMonth)
                }
            }
            if var data = monthData[month] {
                var rows = data.records("shifts").filter { $0.text("day") != day }
                if raw != "erase" { rows.append(["day": .string(day), "kind": .string(raw)]) }
                data["shifts"] = .array(rows.map(JSONValue.object)); monthData[month] = data
            }
        }
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
            var data = result.object
            // A read started before a paint tap must not overwrite the local outbox.
            for pending in store.state.pending where pending.method == "paintShift" {
                try LocalLifeMutation.apply(pending.method, pending.payload, to: &data)
            }
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
        selected = CivilDate.day()
        jumpMonth = String(selected.prefix(7))
    }
    private func monthGrid(_ month: String) -> some View {
        let days = monthDays[month] ?? []
        return VStack(spacing: NativeDesign.Space.none) {
            ForEach(days.isEmpty ? [] : NativeCalendarWindow.weekIndexes(month, includeLeading: month == months.first), id: \.self) { week in
                if (0..<7).contains(where: { days[week * 7 + $0].day.hasSuffix("-01") }) {
                    HStack(spacing: NativeDesign.Space.xs) {
                        ForEach(0..<7, id: \.self) { index in
                            let day = days[week * 7 + index].day
                            Text(day.hasSuffix("-01") ? NativeCalendarWindow.monthLabel(String(day.prefix(7))) : "")
                                .font(.title3.weight(.semibold)).frame(maxWidth: .infinity)
                        }
                    }.padding(.top, NativeDesign.Space.medium).padding(.bottom, NativeDesign.Space.small)
                }
                HStack(spacing: NativeDesign.Space.xs) {
                    ForEach(0..<7, id: \.self) { index in
                        let item = days[week * 7 + index]
                        let displayed = CalendarDayPresentation(day: item.day, label: item.label, shift: item.shift, hasEvents: item.hasEvents, isToday: item.isToday, isWeekend: item.isWeekend, isCurrentMonth: true)
                            Button {
                                if !store.busy { store.calendarMonth = String(item.day.prefix(7)) }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration)) { selected = item.day; if !painting { showingDay = true } }
                                if painting {
                                    let old = item.shift?.rawValue ?? "erase", kind = brush
                                    Task {
                                        do {
                                            try await store.perform("paintShift", ["day": .string(item.day), "kind": .string(kind)])
                                            lastShift = (item.day, old)
                                        } catch { store.error = error.localizedDescription }
                                    }
                                }
                            } label: { CalendarDayCell(item: displayed, active: item.isToday).equatable().frame(minHeight: NativeDesign.Layout.calendarMonthDayHeight) }
                                .buttonStyle(NativePressStyle()).disabled(painting && (store.busy || (!store.isDemo && monthData[month] == nil)))
                                .id(item.day).accessibilityIdentifier("calendar-day-" + item.day)
                                .accessibilityLabel(item.label + ", " + (item.shift?.title ?? "nessun turno"))

                    }
                }
                .id("week-" + month + "-" + String(week))
                Divider()
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) { ForEach(ShiftKind.allCases) { kind in
                        NativeShiftBrushOption(kind: kind, brush: $brush)
                    } }
                }
            }
        }.buttonStyle(NativePressStyle())
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
                .modifier(NativeGlass())
                .overlay(Capsule().stroke(brush == kind.rawValue ? kind.color : Color.clear, lineWidth: NativeDesign.Layout.selectionLine))
                .contentShape(Rectangle())
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
            Text(String(Int(item.day.suffix(2)) ?? 0)).font(appearance == .month ? .title3.weight(.semibold) : .subheadline.weight(active || item.isToday ? .semibold : .regular)).monospacedDigit()
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
