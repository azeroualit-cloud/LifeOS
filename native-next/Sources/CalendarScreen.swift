import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The Calendar reserves the floating tab bar inside its own content. Any
    /// safe-area modifier around this screen (safeAreaInset or safeAreaPadding)
    /// makes SwiftUI measure every lazy week on each animation frame and the
    /// main thread never idles (spindumps of runs 43708179109 and 43722940589).
    /// Build 92: the month ignores the system tab bar's bottom safe area for
    /// the same reason and keeps a fixed clearance instead.
    @State private var privateDay: NativePrivateDay?
    @State private var showingDay = false
    @State private var monthReturnDay: String?
    private var selected: String {
        get { router.calendarDay }
        nonmutating set { router.calendarDay = newValue }
    }
    private var brush: String {
        get { router.calendarBrush }
        nonmutating set { router.calendarBrush = newValue }
    }
    @State private var lastShift: (String, String)?
    @State private var months: [String] = []
    @State private var visibleMonth: String?
    @State private var jumpMonth: String?
    @State private var restoringWindow = false
    @State private var monthPositionReady = false
    @State private var positionRequest = UUID()
    @State private var requestedWeek: String?
    @State private var scrollWeek: String?
    @State private var anchoredWeek: String?
    @State private var anchoredMonth: String?
    @State private var viewportHeight: CGFloat = 0
    @State private var monthDays: [String: [CalendarDayPresentation]] = [:]
    @State private var calendarWeeks: [CalendarWeek] = []
    @State private var monthData: [String: Record] = [:]
    @State private var eventsByDay: [String: [Record]] = [:]
    @State private var tasksByDay: [String: [Record]] = [:]
    @State private var loading = false
    @State private var loadError: String?
    @State private var reload = 0
    private var focusMonth: String { visibleMonth ?? store.calendarMonth }
    private var loadTarget: String { showingDay ? String(selected.prefix(7)) : focusMonth }
    var body: some View {
        ZStack {
            // Keep the month mounted so the scroll position survives a visit to a day.
            monthOverview
                .opacity(showingDay ? 0 : 1)
                .allowsHitTesting(!showingDay)
                .accessibilityHidden(showingDay)
            if showingDay {
                dayAgenda
                    .background(NativeDesign.calendarCanvas)
                    .zIndex(1)
                    .transition(reduceMotion ? .identity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(NativeDesign.calendarCanvas)
        .toolbar(.hidden, for: .navigationBar).tint(NativeDesign.accent)
        .animation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.navigationResponse), value: showingDay)
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear {
            if months.isEmpty {
                let month = String(router.calendarDay.prefix(7))
                store.calendarMonth = month
                months = NativeCalendarWindow.months(around: month)
                selected = preferredDay(in: month)
                seedSnapshot(); rebuildMonth(); visibleMonth = month; jumpMonth = month
                monthReturnDay = router.calendarOpensDay ? selected : nil
                showingDay = router.calendarOpensDay
            }
        }
        .onChange(of: router.calendarFocusRequest) { _, _ in
            let month = String(selected.prefix(7))
            ensureWindow(around: month)
            position(month: month, day: selected)
            monthReturnDay = router.calendarOpensDay ? selected : nil
            showingDay = router.calendarOpensDay
        }
        .onChange(of: visibleMonth) { _, month in if let month { ensureWindow(around: month) } }
        .onChange(of: NativeCalendarSource(life: store.life, demo: store.isDemo, origin: store.server?.absoluteString)) { old, new in
            if let changes = new.shiftChanges(from: old) { patchShifts(changes) }
            else { monthData = [:]; seedSnapshot(); rebuildMonth(); reload += 1 }
        }
        .task(id: loadTarget + "-" + String(reload)) {
            let target = loadTarget
            ensureWindow(around: target)
            if showingDay {
                let previous = String(CivilDate.adding(-1, to: selected).prefix(7))
                if previous != target { await loadMonth(previous) }
            }
            guard !Task.isCancelled else { return }
            await loadMonth(target)
            // The agenda looks 30 days ahead: load the following month too.
            if showingDay {
                let ahead = String(CivilDate.adding(NativeCalendarAgendaRange.days, to: selected).prefix(7))
                if ahead != target, !Task.isCancelled { await loadMonth(ahead) }
            }
        }
    }
    private var weekdayLabels: some View {
        HStack(spacing: CalendarMetrics92.xs) {
            ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, name in
                Text(name).font(.footnote.weight(.medium)).foregroundStyle(NativeDesign.secondary).frame(maxWidth: .infinity)
            }
        }.padding(.vertical, NativeDesign.Space.small).accessibilityHidden(true)
    }
    private var monthOverview: some View {
        VStack(spacing: NativeDesign.Space.none) {
            HStack {
                Button { if router.tab == .calendar { router.tab = .dashboard } else { dismiss() } } label: { Image(systemName: "chevron.left").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Torna alla Dashboard").accessibilityIdentifier("other-back")
                Text(CivilDate.monthTitle(focusMonth)).font(.title.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("calendar-month-heading-" + focusMonth)
                Spacer(minLength: NativeDesign.Space.small)
                NativeToolbarButton(symbol: "plus", label: "Aggiungi evento") { router.sheet = .event(["day": .string(selected)]) }
                    .accessibilityIdentifier("primary-add")
            }.padding(.horizontal, CalendarMetrics92.inset)
            brushPanel.padding(.horizontal, CalendarMetrics92.inset)
            if let loadError { HStack { NativeInlineMessage(text: loadError); Button("Riprova") { reload += 1 } }.padding(.horizontal) }
            weekdayLabels.padding(.horizontal, CalendarMetrics92.inset)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: NativeDesign.Space.none) {
                        ForEach(calendarWeeks) { week in
                            weekGrid(week.month, week: week.index).id(week.id)
                                .background {
                                    // Frames are only needed while a requested week is being reached:
                                    // reporting them on every scroll frame made scrolling stutter.
                                    if requestedWeek != nil {
                                        GeometryReader { geometry in
                                            Color.clear.preference(key: NativeCalendarMonthFrames.self, value: [week.id: geometry.frame(in: .named("calendar-viewport"))])
                                        }
                                    }
                                }
                        }
                    }.scrollTargetLayout().padding(.horizontal, CalendarMetrics92.inset)
                        .padding(.vertical, NativeDesign.Space.large).padding(.bottom, NativeDesign.Layout.scrollClearance + NativeDesign.Layout.tabBarClearance)
                }.scrollPosition(id: $scrollWeek, anchor: .top)
                .ignoresSafeArea(.container, edges: .bottom)
                .onChange(of: scrollWeek) { _, week in
                    guard monthPositionReady, !restoringWindow, !showingDay, let week else { return }
                    updateVisibleMonth(for: week)
                }
                .accessibilityIdentifier("calendar-scroll")
                .modifier(NativeUITestValue(value: scrollDiagnostics))
                .coordinateSpace(name: "calendar-viewport")
                .onPreferenceChange(NativeCalendarMonthFrames.self) { frames in
                    if let target = requestedWeek {
                        guard let frame = frames[target], frame.maxY > 0,
                              frame.minY < viewportHeight - NativeDesign.Layout.tabBarClearance else { return }
                        requestedWeek = nil; restoringWindow = false; monthPositionReady = true
                        if let anchoredMonth { visibleMonth = anchoredMonth }
                    }
                }
                .task { position(month: String(selected.prefix(7)), day: selected) }
                .task(id: positionRequest) {
                    guard let target = requestedWeek else { return }
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: NativeCalendarViewportHeight.self, value: geometry.size.height)
                    }
                }
                .onPreferenceChange(NativeCalendarViewportHeight.self) { viewportHeight = $0 }
                .onChange(of: jumpMonth) { _, month in
                    guard let month else { return }
                    ensureWindow(around: month)
                    position(month: month, day: selected.hasPrefix(month) ? selected : nil)
                    jumpMonth = nil
                }
            }
        }
    }
    private var scrollDiagnostics: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--visual-test") {
            return "target=\(scrollWeek ?? "nil") requested=\(requestedWeek ?? "nil") height=\(viewportHeight) ready=\(monthPositionReady)"
        }
        #endif
        return ""
    }
    private func position(month: String, day: String?) {
        let target = weekID(for: day ?? month + "-01")
        guard calendarWeeks.contains(where: { $0.id == target }) else { return }
        requestedWeek = target; monthPositionReady = false; restoringWindow = true
        anchoredWeek = target; anchoredMonth = month; visibleMonth = month
        // Keep the native retention anchor and the explicit reader request in
        // agreement. Never clear this binding before assigning the target.
        scrollWeek = target
        positionRequest = UUID()
    }
    private func updateVisibleMonth(for week: String) {
        guard calendarWeeks.contains(where: { $0.id == week }) else { return }
        if week == anchoredWeek, let anchoredMonth { visibleMonth = anchoredMonth; return }
        anchoredWeek = nil; anchoredMonth = nil
        visibleMonth = NativeCalendarWindow.focusMonth(weekStarting: String(week.dropFirst("week-".count)))
    }
    private var dayAgenda: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.none) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                HStack(spacing: NativeDesign.Space.small) {
                    Button(action: returnToMonth) {
                        Label("Mese", systemImage: "chevron.left")
                    }
                    .buttonStyle(NativeGlassButtonStyle())
                    .accessibilityLabel("Torna al mese")
                    .accessibilityIdentifier("calendar-back-month")
                    Spacer(minLength: NativeDesign.Space.none)
                    NativeIconButton(symbol: "chevron.left", label: "Giorno precedente") { moveDay(by: -1) }
                        .accessibilityIdentifier("calendar-previous-day")
                    NativeIconButton(symbol: "chevron.right", label: "Giorno successivo") { moveDay(by: 1) }
                        .accessibilityIdentifier("calendar-next-day")
                }
                if !typeSize.isAccessibilitySize { viewSwitch }
                Text(CivilDate.agendaTitle(selected))
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("calendar-day-heading")
                if let shift = selectedShift {
                    Label(shift.time.isEmpty ? shift.title : shift.title + " · " + shift.time, systemImage: shift.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(shift.color)
                        .padding(.horizontal, NativeDesign.Space.medium)
                        .padding(.vertical, NativeDesign.Space.xs)
                        .background(shift.color.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.small)
            agendaContent
        }
        .loBottomActions {
            Button {
                router.sheet = .event(["day": .string(selected)])
            } label: {
                LOActionLabel(title: "Aggiungi evento", systemImage: "plus", section: .calendar)
            }
            .buttonStyle(LOGlassButtonStyle(fillsWidth: true))
            .accessibilityIdentifier("calendar-add-event")
        }
    }

    private var agendaContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                if let loadError {
                    HStack { NativeInlineMessage(text: loadError); Button("Riprova") { reload += 1 } }
                }
                // CALENDAR-RAMADAN-EID / CALENDAR-PRIVATE-ENTRY (24/11/2026): tags of the day and a discreet «Privato».
                HStack(spacing: NativeDesign.Space.small) {
                    ForEach(NativeIslamicDays.events(on: selected), id: \.self) { NativeIslamicTag(title: $0) }
                    Spacer(minLength: 0)
                    Button { privateDay = NativePrivateDay(day: selected) } label: {
                        Text("Privato").font(.footnote).foregroundStyle(NativeDesign.secondary)
                            .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
                    }
                    .buttonStyle(NativePressStyle())
                    .accessibilityIdentifier("calendar-private")
                }
                // The selected day uses the same rows as the following days (user, 23/11/2026).
                selectedDayList
                // Accessibility sizes keep the single-day agenda proven in build 92.
                if !typeSize.isAccessibilitySize {
                    ForEach(followingDays, id: \.self) { day in followingDay(day) }
                }
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.medium)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(item: $privateDay) { item in NativePrivateDaySheet(day: item.day) }
        .accessibilityIdentifier("calendar-day-pane")
        .id(selected)
    }

    /// The next 30 days after the selected one that have at least one event or task
    /// (user request 22/11/2026: the agenda lists only days with commitments). Only loaded months count.
    private var followingDays: [String] {
        (1...NativeCalendarAgendaRange.days).map { CivilDate.adding($0, to: selected) }.filter { day in
            guard monthData[String(day.prefix(7))] != nil else { return false }
            let events = (eventsByDay[day] ?? []).filter { $0.text("occurrence_status") != "skipped" }
            return !events.isEmpty || !(tasksByDay[day] ?? []).isEmpty || !NativeIslamicDays.events(on: day).isEmpty
        }
    }
    private func followingDay(_ day: String) -> some View {
        let events = (eventsByDay[day] ?? []).filter { $0.text("occurrence_status") != "skipped" }
            .sorted { ($0.text("start_time").isEmpty ? "00:00" : $0.text("start_time"), $0.integer("id")) < ($1.text("start_time").isEmpty ? "00:00" : $1.text("start_time"), $1.integer("id")) }
        let tasks = tasksByDay[day] ?? []
        let dayShift = self.shift(on: day)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                Text(CivilDate.agendaTitle(day)).font(.headline)
                if let dayShift {
                    Text(dayShift.title).font(.subheadline.weight(.semibold)).foregroundStyle(dayShift.color)
                }
                ForEach(NativeIslamicDays.events(on: day), id: \.self) { NativeIslamicTag(title: $0) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("calendar-next-day-" + day)
            followingRows(day)
        }
    }
    /// The rows of one day: time | shift-coloured bar | title with end time or place.
    private func followingRows(_ day: String) -> some View {
        let events = (eventsByDay[day] ?? []).filter { $0.text("occurrence_status") != "skipped" }
            .sorted { ($0.text("start_time").isEmpty ? "00:00" : $0.text("start_time"), $0.integer("id")) < ($1.text("start_time").isEmpty ? "00:00" : $1.text("start_time"), $1.integer("id")) }
        let tasks = tasksByDay[day] ?? []
        let dayShift = self.shift(on: day)
        return LOListCard {
            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                agendaRow(time: event.text("start_time").isEmpty ? "Giornata" : event.text("start_time"),
                          title: event.text("title", fallback: "Evento"), detail: eventDetail(event),
                          color: dayShift?.color ?? NativeDesign.calendarTitle, isLast: index == events.count - 1 && tasks.isEmpty) {
                    router.sheet = .event(event)
                }
                .accessibilityIdentifier("calendar-timeline-event:" + String(event.integer("id")))
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                agendaRow(time: task.text("scheduled_time").isEmpty ? "Attività" : task.text("scheduled_time"),
                          title: task.text("title"), detail: "", color: NativeDesign.secondary, isLast: index == tasks.count - 1) {
                    router.sheet = .task(task)
                }
                .accessibilityIdentifier("calendar-timeline-task:" + String(task.integer("id")))
            }
        }
    }
    @ViewBuilder private var selectedDayList: some View {
        let events = (eventsByDay[selected] ?? []).filter { $0.text("occurrence_status") != "skipped" }
        if events.isEmpty && (tasksByDay[selected] ?? []).isEmpty {
            LOListCard {
                LOListRow(isLast: true) { Text("Nessun impegno").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            }
        } else {
            followingRows(selected)
        }
    }
    private func eventDetail(_ event: Record) -> String {
        var parts: [String] = []
        if !event.text("end_time").isEmpty && !event.text("start_time").isEmpty { parts.append("fino alle " + event.text("end_time")) }
        if !event.text("location").isEmpty { parts.append(event.text("location")) }
        return parts.joined(separator: " · ")
    }
    private func agendaRow(time: String, title: String, detail: String, color: Color, isLast: Bool, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            LOListRow(isLast: isLast) {
                Text(time).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                    .frame(width: NativeDesign.Layout.categoryWidth * 0.7, alignment: .leading)
                Capsule().fill(color).frame(width: NativeDesign.Space.xs, height: NativeDesign.Layout.toolbarVisual - NativeDesign.Space.xxs)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(title).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
                    if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                }
                Spacer(minLength: NativeDesign.Space.small)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityLabel(time + ", " + title + (detail.isEmpty ? "" : ", " + detail))
    }
    private func returnToMonth() {
        if let origin = monthReturnDay {
            selected = origin
            let month = String(origin.prefix(7))
            store.calendarMonth = month
            // Always bring the origin week back to the top: the month scroll runs
            // under the floating tab bar, so a week that is merely inside the
            // window can still sit behind the bar and not be tappable.
            ensureWindow(around: month)
            position(month: month, day: origin)
        }
        showingDay = false
    }

    private func moveDay(by offset: Int) {
        selected = CivilDate.adding(offset, to: selected)
        store.calendarMonth = String(selected.prefix(7))
    }
    private var agenda: [NativeCalendarAgendaNode] {
        let previous = CivilDate.adding(-1, to: selected)
        return NativeCalendarTimeline.agenda(events: eventsByDay[selected] ?? [], tasks: tasksByDay[selected] ?? [], shift: nil, previousShift: nil, previousEvents: eventsByDay[previous] ?? [])
    }
    private func openAgendaEntry(_ item: NativeCalendarAgendaEntry) {
        router.sheet = item.source == "event" ? .event(item.record) : .task(item.record)
    }
    private func shift(on day: String) -> ShiftKind? {
        monthDays[String(day.prefix(7))]?.first { $0.day == day }?.shift
    }
    private var selectedShift: ShiftKind? { shift(on: selected) }
    private var allDayEntries: [NativeCalendarAgendaEntry] {
        (eventsByDay[selected] ?? []).filter { $0.text("start_time").isEmpty }.map {
            NativeCalendarAgendaEntry(id: "event:" + String($0.integer("id")), record: $0, source: "event", start: 0, end: nil)
        } + (tasksByDay[selected] ?? []).filter { $0.text("scheduled_time").isEmpty }.map {
            NativeCalendarAgendaEntry(id: "task:" + String($0.integer("id")), record: $0, source: "task", start: 0, end: nil)
        }
    }
    private func allDayStrip(_ entries: [NativeCalendarAgendaEntry]) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text("Tutto il giorno").font(.footnote).foregroundStyle(NativeDesign.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NativeDesign.Space.small) {
                    ForEach(entries) { item in
                        Button { openAgendaEntry(item) } label: {
                            NativeCalendarAgendaTitle(entry: item, color: NativeCalendarEventStyle.color(for: item))
                                .lineLimit(1)
                                .frame(maxWidth: NativeDesign.Layout.allDayChipWidth, minHeight: NativeDesign.Layout.touchTarget,
                                       alignment: .leading)
                                .padding(.trailing, NativeDesign.Space.small)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(item.record.text("title"))
                    }
                }
            }.accessibilityIdentifier("calendar-all-day-strip")
        }
    }
    private func patchShifts(_ changes: [String: String]) {
        for (day, raw) in changes {
            let month = String(day.prefix(7))
            for cachedMonth in NativeCalendarWindow.coveredMonths(around: month, within: Array(monthDays.keys)) {
                guard let grid = monthDays[cachedMonth] else { continue }
                monthDays[cachedMonth] = grid.map { item in
                    guard item.day == day else { return item }
                    return CalendarDayPresentation(day: item.day, label: item.label, shift: raw == "erase" ? nil : ShiftKind(rawValue: raw), eventCount: item.eventCount, isToday: item.isToday, isWeekend: item.isWeekend, isCurrentMonth: item.isCurrentMonth)
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
                return CalendarDayPresentation(day: day, label: CivilDate.label(date), shift: allShifts[day].flatMap(ShiftKind.init(rawValue:)), eventCount: eventsByDay[day]?.count ?? 0, isToday: day == today, isWeekend: weekday == 1 || weekday == 7, isCurrentMonth: day.hasPrefix(month))
            }
        }
        monthDays = grids
        calendarWeeks = weeks(in: grids)
    }
    private func goToToday() {
        selected = CivilDate.day()
        jumpMonth = String(selected.prefix(7))
    }
    private struct CalendarWeek: Identifiable {
        let id: String
        let month: String
        let index: Int
    }
    private func weeks(in grids: [String: [CalendarDayPresentation]]) -> [CalendarWeek] {
        months.flatMap { month in
            let days = grids[month] ?? []
            return (days.isEmpty ? [] : NativeCalendarWindow.weekIndexes(month, includeLeading: month == months.first)).map { index in
                CalendarWeek(id: "week-" + days[index * 7].day, month: month, index: index)
            }
        }
    }
    private func weekID(for day: String) -> String {
        let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(day))
        return "week-" + CivilDate.adding(-((weekday + 5) % 7), to: day)
    }
    /// Week rows have exact heights so lazy estimates match realized rows and the
    /// anchored scroll offset is never corrected in a loop.
    private var monthLabelLine: CGFloat {
        let size = min(typeSize, .xxxLarge)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return UIFont.preferredFont(forTextStyle: .title3, compatibleWith: traits).lineHeight.rounded(.up)
    }
    private func weekGrid(_ month: String, week: Int) -> some View {
        let days = monthDays[month] ?? []
        return VStack(spacing: NativeDesign.Space.none) {
                if (0..<7).contains(where: { days[week * 7 + $0].day.hasSuffix("-01") }) {
                    HStack(spacing: CalendarMetrics92.xs) {
                        ForEach(0..<7, id: \.self) { index in
                            let day = days[week * 7 + index].day
                            Text(day.hasSuffix("-01") ? NativeCalendarWindow.monthLabel(String(day.prefix(7))) : "")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(day.hasPrefix(CivilDate.month()) ? Color.primary : NativeDesign.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }.frame(height: monthLabelLine).padding(.top, CalendarMetrics92.medium).padding(.bottom, NativeDesign.Space.small)
                    Divider()
                }
                HStack(alignment: .top, spacing: CalendarMetrics92.xs) {
                    ForEach(0..<7, id: \.self) { index in
                        let item = days[week * 7 + index]
                        let displayed = CalendarDayPresentation(day: item.day, label: item.label, shift: item.shift, eventCount: item.eventCount, isToday: item.isToday, isWeekend: item.isWeekend, isCurrentMonth: true)
                            Button {
                                if !store.busy { store.calendarMonth = String(item.day.prefix(7)) }
                                selected = item.day
                                if !painting {
                                    monthReturnDay = item.day
                                    showingDay = true
                                }
                                if painting {
                                    let old = item.shift?.rawValue ?? "erase", kind = brush
                                    Task {
                                        do {
                                            try await store.perform("paintShift", ["day": .string(item.day), "kind": .string(kind)])
                                            lastShift = (item.day, old)
                                        } catch { store.error = error.localizedDescription }
                                    }
                                }
                            } label: {
                                CalendarDayCell(item: displayed, active: item.day == selected)
                                    .equatable()
                                    .padding(.vertical, (NativeDesign.Layout.calendarMonthDayHeight - NativeDesign.Layout.calendarDayHeight) / 2)
                                    .contentShape(Rectangle())
                            }
                                .buttonStyle(NativePressStyle()).disabled(painting && (store.busy || (!store.isDemo && monthData[month] == nil)))
                                .id(item.day).accessibilityIdentifier("calendar-day-" + item.day)
                                .accessibilityLabel(item.label + ", " + (item.shift?.title ?? "nessun turno"))
                                .accessibilityValue(item.eventCount == 1 ? "1 evento" : "\(item.eventCount) eventi")
                                .accessibilityAddTraits(item.day == selected ? .isSelected : [])

                    }
                }.frame(height: NativeDesign.Layout.calendarMonthDayHeight, alignment: .top)
                Divider()
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    /// Mese / Agenda (build 93 preview). Agenda opens the selected day with the next days.
    private var viewSwitch: some View {
        LOSegmented(options: [("Mese", "month"), ("Agenda", "agenda")], selection: Binding(
            get: { showingDay ? "Agenda" : "Mese" },
            set: { value in
                if value == "Agenda", !showingDay { monthReturnDay = selected; showingDay = true }
                else if value == "Mese", showingDay { returnToMonth() }
            }), identifierPrefix: "calendar-view-")
    }
    private var painting: Bool {
        get { router.calendarPainting }
        nonmutating set { router.calendarPainting = newValue }
    }
    private var brushPanel: some View {
        brushPanelContent
    }
    private var brushPanelContent: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            // Accessibility sizes keep the build 92 header exactly (Oggi in the row below, no
            // switch): the month stays the version proven with large text; days open the agenda.
            if !typeSize.isAccessibilitySize {
                HStack(spacing: NativeDesign.Space.small) {
                    // Same visible height as the Mese/Agenda switch; the touch area stays 44 pt.
                    Button(action: goToToday) {
                        Text("Oggi").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            .padding(.horizontal, NativeDesign.Space.medium)
                            .frame(height: NativeDesign.Layout.compactControl)
                            .modifier(NativeGlass())
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(NativePressStyle())
                        .accessibilityIdentifier("calendar-today").disabled(store.busy)
                    viewSwitch
                }
            }
            HStack(spacing: NativeDesign.Space.large) {
                if typeSize.isAccessibilitySize {
                    Button(action: goToToday) {
                        Text("Oggi").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("calendar-today").disabled(store.busy)
                }
                Button { withAnimation(reduceMotion || typeSize.isAccessibilitySize ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { painting.toggle(); brush = painting ? "morning" : "consult" } } label: { Label(painting ? "Fine" : "Dipingi turni", systemImage: painting ? "checkmark" : "calendar.badge.clock").labelStyle(.iconOnly).frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle()) }.accessibilityIdentifier("toggle-shift-paint")
                Spacer()
                if let lastShift { Button("Annulla") { Task { await store.run("paintShift", ["day": .string(lastShift.0), "kind": .string(lastShift.1)]); if store.error == nil { self.lastShift = nil } } }.disabled(store.busy) }
                NativeIconButton(symbol: "chevron.left", label: "Mese precedente") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: -1) }.disabled(store.busy)
                NativeIconButton(symbol: "chevron.right", label: "Mese successivo") { jumpMonth = NativeCalendarWindow.offset(focusMonth, by: 1) }.disabled(store.busy)
            }.font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget)
            if painting {
                ScrollView(.horizontal) {
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(ShiftKind.allCases) { kind in
                            NativeShiftBrushOption(kind: kind, brush: Binding(get: { router.calendarBrush }, set: { router.calendarBrush = $0 }))
                        }
                    }
                    .padding(.vertical, NativeDesign.Space.xs)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("shift-brush-scroll")
            }
        }.buttonStyle(NativePressStyle()).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

}
private struct NativeShiftBrushOption: View {
    let kind: ShiftKind
    @Binding var brush: String
    var body: some View {
        Button { brush = kind.rawValue } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                HStack(spacing: NativeDesign.Space.xs) {
                    if kind == .erase {
                        Image(systemName: kind.symbol).font(.footnote.weight(.semibold))
                    } else {
                        Circle().fill(kind.color).frame(width: NativeDesign.Space.medium, height: NativeDesign.Space.medium)
                    }
                    Text(kind.title).font(.footnote.weight(.semibold)).lineLimit(1)
                }
                if !kind.time.isEmpty {
                    Text(kind.time).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
                .padding(.horizontal, NativeDesign.Space.small)
                .padding(.vertical, NativeDesign.Space.xs)
                .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Rectangle())
        }.buttonStyle(NativeGlassButtonStyle())
            .background { Capsule().fill(brush == kind.rawValue && kind != .erase ? kind.color.opacity(0.28) : .clear) }
            .overlay(Capsule()
                .strokeBorder(brush == kind.rawValue ? (kind == .erase ? NativeDesign.secondary : kind.color) : .clear, lineWidth: NativeDesign.Layout.selectionLine))
            .accessibilityLabel(kind.title + (kind.time.isEmpty ? "" : ", " + kind.time))
            .accessibilityHint("Tocca i giorni per applicare questo turno")
            .accessibilityIdentifier("shift-brush-" + kind.rawValue).accessibilityAddTraits(brush == kind.rawValue ? .isSelected : [])
    }
}

struct CalendarDayPresentation: Equatable {
    let day: String
    let label: String
    let shift: ShiftKind?
    let eventCount: Int
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
    @ScaledMetric(relativeTo: .title3) private var calendarNumberSize = NativeDesign.Layout.calendarDateNumber
    var body: some View {
        let color = item.shift?.color ?? NativeDesign.accent
        VStack(spacing: NativeDesign.Space.xxs) {
            if appearance == .week {
                Text(String(Int(item.day.suffix(2)) ?? 0)).font(.subheadline.weight(active || item.isToday ? .semibold : .regular)).monospacedDigit()
                    .foregroundStyle(active ? (item.shift == nil ? NativeDesign.canvas : Color.black.opacity(0.85)) : Color.primary)
                    .minimumScaleFactor(0.8).lineLimit(1).frame(width: numberSize, height: numberSize)
                    .background(active ? color : .clear, in: Circle())
                    .overlay(Circle().stroke(item.isToday && !active ? color : .clear, lineWidth: NativeDesign.Space.hairline))
            } else {
                Text(String(Int(item.day.suffix(2)) ?? 0)).font(NativeDesign.calendarNumber(size: calendarNumberSize))
                    .foregroundStyle(active ? (item.shift == nil ? NativeDesign.onAccent : Color.black) : item.isWeekend ? NativeDesign.secondary : Color.primary)
                    .minimumScaleFactor(0.8).lineLimit(1)
                    .frame(width: NativeDesign.Layout.calendarDateLine, height: NativeDesign.Layout.calendarDateLine)
                    .background(active ? color : .clear, in: Circle())
                    .overlay(Circle().strokeBorder(item.isToday && !active ? color : .clear))
            }
            Group {
                if appearance == .week {
                    NativeShiftBadge(shift: item.shift)
                } else {
                    Capsule()
                        .fill(item.shift.map { $0.color.opacity(item.isWeekend ? 0.76 : 1) } ?? .clear)
                        .frame(height: CalendarMetrics92.xs)
                        .padding(.horizontal, NativeDesign.Space.xxs)
                        .padding(.vertical, CalendarMetrics92.xs)
                        .accessibilityHidden(true)
                }
            }
            eventDots
        }.frame(maxWidth: .infinity)
            .frame(minHeight: NativeDesign.Layout.calendarDayHeight, alignment: appearance == .month ? .top : .center)
            .contentShape(Rectangle()).opacity(appearance != .month || item.isCurrentMonth ? 1 : 0.38)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: active)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: item.shift)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var eventDots: some View {
        let count = appearance == .month ? item.eventCount : min(item.eventCount, 1)
        let color = item.shift?.color ?? NativeDesign.secondary
        let dotsPerRow = 3
        return VStack(spacing: NativeDesign.Space.xxs) {
            ForEach(0..<((count + dotsPerRow - 1) / dotsPerRow), id: \.self) { row in
                HStack(spacing: NativeDesign.Space.xxs) {
                    ForEach(0..<min(dotsPerRow, count - row * dotsPerRow), id: \.self) { _ in
                        Circle().fill(color).frame(width: NativeDesign.Space.xs, height: NativeDesign.Space.xs)
                    }
                }
            }
        }
        .frame(minHeight: NativeDesign.Space.xs)
        .accessibilityHidden(true)
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

/// Read-only geometry is kept outside the calendar's data projection. It never
/// writes a native scroll offset during a user gesture.
private struct NativeCalendarMonthFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { old, new in old.union(new) })
    }
}

private struct NativeCalendarViewportHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Build 92 spacing for the month grid: the week rows keep the exact heights the anchored,
/// lazily realized month scroll was proven with (large text included).
enum CalendarMetrics92 {
    static let xs: CGFloat = 4
    static let medium: CGFloat = 12
    static let inset: CGFloat = 20
}

/// How far the agenda looks ahead of the selected day.
enum NativeCalendarAgendaRange {
    static let days = 30
}
