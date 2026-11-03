import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @AppStorage("native-hide-money") private var hiddenMoney = false
    @State private var routineBusy: Int?
    @State private var routineFeedback = false
    @State private var showingTimes = false
    @EnvironmentObject private var health: NativeHealthStore
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date, today = CivilDate.day(now)
            let summary = NativeHomeSummary(now: now, todayShift: store.shift(today), tomorrowShift: store.shift(CivilDate.adding(1, to: today)), previousShift: store.shift(CivilDate.adding(-1, to: today)), events: store.dashboardEvents, weather: store.weather == "Meteo non disponibile" ? nil : store.weatherDetails, weatherDate: store.weatherDate, calendarAvailable: NativeHomeSummary.hasCalendarData(life: store.life, demo: store.isDemo))
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                    heading(summary, today: today, now: now)
                    rollingCalendar(today)
                    checklist(today: today)
                    financeOverview
                    NativeNutritionQuickEntry()
                    NativeConnectionBadge()
                    if let notice = store.notice { Text(notice).font(.caption).foregroundStyle(NativeDesign.secondary) }
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.top, NativeDesign.Space.small).padding(.bottom, NativeDesign.Layout.scrollClearance)
            }
            .background(NativeDesign.canvas).scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("dashboard-scroll")
            .refreshable { await health.refresh() }

        }.sensoryFeedback(.success, trigger: routineFeedback)
        .task { await health.start(demo: NativeHealthLaunchPolicy.simulated) }
        .onChange(of: store.life.records("health"), initial: true) { _, rows in
            health.setLegacyRecords(store.isDemo ? [] : rows)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifeOSWeightSaved)) { _ in Task { await health.refresh() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await health.refresh() } } }
    }

    private func rollingCalendar(_ today: String) -> some View {
        let days = NativeHomeSummary.rollingDays(today)
        let marked = Set(store.events.map { $0.text("day") } + store.tasks.map { $0.text("scheduled_date") })
        return VStack(spacing: NativeDesign.Space.small) {
            HStack(spacing: NativeDesign.Space.xs) {
                ForEach(days, id: \.self) { day in
                    let current = day == today, shift = store.shift(day)
                    let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(day))
                    let item = CalendarDayPresentation(day: day, label: CivilDate.label(day), shift: shift,
                        hasEvents: marked.contains(day), isToday: current,
                        isWeekend: weekday == 1 || weekday == 7,
                        isCurrentMonth: day.hasPrefix(String(today.prefix(7))))
                    Button { openCalendar(day) } label: {
                        VStack(spacing: NativeDesign.Space.xs) {
                            Text(["D", "L", "M", "M", "G", "V", "S"][weekday - 1]).font(.caption).foregroundStyle(day < today ? NativeDesign.pastCalendarSecondary : NativeDesign.secondary)
                            CalendarDayCell(item: item, active: current, appearance: .week).equatable()
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle()).opacity(day < today ? NativeDesign.Layout.pastDayOpacity : 1).accessibilityIdentifier("dashboard-day-" + day)
                        .accessibilityLabel(CivilDate.label(day) + ", " + (shift?.title ?? "Turno non disponibile"))
                        .accessibilityAddTraits(current ? .isSelected : [])
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }.padding(NativeDesign.Space.small).background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
    }
    private func openCalendar(_ day: String) {
        store.calendarMonth = String(day.prefix(7)); router.showCalendar(day: day, opensDay: false)
        Task { await store.sync(scope: .life) }
    }
    private func heading(_ summary: NativeHomeSummary, today: String, now: Date) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.medium) {
                headingText(summary, today: today, now: now)
                Spacer(minLength: NativeDesign.Space.small)
                activeShift(now: now, today: today)
            }
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                headingText(summary, today: today, now: now)
                activeShift(now: now, today: today)
            }
        }
    }
    private func headingText(_ summary: NativeHomeSummary, today: String, now: Date) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(CivilDate.label(today).capitalized).accessibilityIdentifier("home-today").font(.title.bold()).accessibilityAddTraits(.isHeader)
            nextTime(now)
        }
    }
    private func focusDate(_ now: Date) -> Date {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--active-shift") { return CivilDate.calendar.date(bySettingHour: 13, minute: 40, second: 0, of: now)! }
        if ProcessInfo.processInfo.arguments.contains("--inactive-shift") { return CivilDate.calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now)! }
        #endif
        return now
    }
    @ViewBuilder private func activeShift(now: Date, today: String) -> some View {
        let focusNow = focusDate(now)
        let model = NativeDashboardFocus(now: focusNow, todayShift: store.shift(today), previousShift: store.shift(CivilDate.adding(-1, to: today)))
        ZStack(alignment: .trailing) {
        if model.phase == "Adesso" {
            Button { openCalendar(today) } label: {
                VStack(alignment: .trailing, spacing: NativeDesign.Space.small) {
                    Text(model.title).font(NativeDesign.heading).foregroundStyle(model.shift?.color ?? NativeDesign.accent)
                    NativeShiftProgressBar(model: model, now: focusNow, activation: router.activationDate)
                        .frame(width: NativeDesign.Layout.shiftProgressWidth)
                }.frame(minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
            }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-focus")
                .accessibilityLabel(model.title + ", " + model.remainingText + " alla fine")
                .accessibilityHint("Apre il calendario completo")
                .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: NativeDesign.Motion.pressedScale)))
        }
        }.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: model.phase)
    }
    private func checklist(today: String) -> some View {
        let items = NativeHomeChecklist.rows(tasks: store.tasks, events: store.dashboardEvents, routines: store.todayRoutines, today: today)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            NativeSectionHeader("Cose da fare", titleIdentifier: "home-checklist-heading") {
                Menu("Gestisci") {
                    Button("Attività") { router.tab = .tasks }
                    Button("Abitudini") { router.sheet = .routines }
                    Button("Calendario") { openCalendar(today) }
                }.frame(minHeight: NativeDesign.Layout.touchTarget)
            }
            if items.isEmpty { Text("Nessun impegno da mostrare").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            ForEach(items) { item in
                checklistRow(item, today: today)
                if item.id != items.last?.id { Divider().padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small) }
            }
        }
    }
    @ViewBuilder private func checklistRow(_ item: NativeHomeChecklistItem, today: String) -> some View {
        let record = item.record
        switch item.kind {
        case .event: HomeAgendaRow(event: record)
        case .routine:
            NativeChecklistRow(title: record.text("title"), subtitle: "Abitudine", checked: record.flag("checked"), completionLabel: "Completa abitudine " + record.text("title"), onComplete: { checkRoutine(record) }, onOpen: { router.sheet = .routines })
                .disabled(store.busy || routineBusy != nil)
        case .task:
            NativeChecklistRow(title: record.text("title"), subtitle: "Attività" + (item.time.isEmpty ? "" : " · " + item.time), checked: false, dueDay: record.text("due_date"), completionLabel: "Completa attività " + record.text("title"), onComplete: {
                Task { await store.run("setTaskStatus", ["id": .int(record.integer("id")), "status": .string(NativeTaskList.completionStatus(record))]) }
            }, onOpen: { router.sheet = .task(record) }).disabled(store.busy)
        }
    }
    @ViewBuilder private func nextTime(_ now: Date) -> some View {
        if let next = NativeNextTime.next(now: now) {
            Button { showingTimes = true } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: NativeDesign.Space.small) {
                        Image(systemName: next.symbol).foregroundStyle(NativeDesign.secondary)
                        Text(next.label).foregroundStyle(NativeDesign.secondary)
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(next.displayTime).fontWeight(.medium).monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        Label(next.label, systemImage: next.symbol).foregroundStyle(NativeDesign.secondary)
                        Text(next.displayTime).fontWeight(.medium).monospacedDigit()
                    }
                }.font(.subheadline).frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(NativePressStyle())
                .accessibilityLabel("Prossimo orario, " + next.label + ", " + next.displayTime)
                .accessibilityIdentifier("home-next-time")
                .sheet(isPresented: $showingTimes) {
                    NavigationStack {
                        List {
                            Section("Empoli · " + CivilDate.label(next.day)) {
                                ForEach(NativeNextTime.schedule(day: next.day), id: \.label) { time in
                                    LabeledContent(time.label, value: time.time).monospacedDigit()
                                }
                            }
                            Section { Text("Orari indicativi calcolati sul dispositivo per Empoli, nel fuso Europe/Rome.").font(.caption).foregroundStyle(NativeDesign.secondary) }
                        }.modifier(NativeListAppearance()).navigationTitle("Orari").navigationBarTitleDisplayMode(.inline).toolbar { DoneButton() }
                    }.presentationDetents([.medium, .large])
                }
        }
    }
    private var financeOverview: some View {
        NativeCard {
            NavigationLink(value: NativeDashboardDestination.finance) {
                HStack {
                    Label("Finanza", systemImage: "chart.bar").font(.headline)
                    Spacer()
                    NativeDisclosureIndicator()
                }.frame(minHeight: NativeDesign.Layout.touchTarget)
            }.buttonStyle(NativePressStyle())
            let overview = NativeFinanceOverview(summary: store.summary, month: store.financeMonth)
            LabeledContent("Budget rimanente", value: hiddenMoney ? "•••• €" : overview.remaining.map(\.euro) ?? "Da aggiornare")
            LabeledContent("Conto principale", value: hiddenMoney ? "•••• €" : overview.balance.map(\.euro) ?? "Da aggiornare")
                .foregroundStyle(NativeDesign.secondary)
            Text(CivilDate.monthTitle(store.financeMonth)).font(.caption).foregroundStyle(NativeDesign.secondary)
            Button("Aggiungi spesa", systemImage: "plus") { router.sheet = .movement([:]) }
                .frame(minHeight: NativeDesign.Layout.touchTarget)
        }
    }
    private func checkRoutine(_ record: Record) {
        guard routineBusy == nil else { return }
        routineBusy = record.integer("id")
        Task {
            defer { routineBusy = nil }
            do {
                try await store.perform("setRoutineCheck", ["id": .int(record.integer("id")), "day": .string(CivilDate.day()), "checked": .bool(!record.flag("checked"))])
                routineFeedback.toggle()
            } catch { store.error = error.localizedDescription }
        }
    }

}

private extension Dictionary where Key == String, Value == JSONValue {
    var integerID: Int { integer("id") }
    var agendaIdentity: String { String(integer("id")) + "-" + text("day") }
}

private struct HomeAgendaDayHeading: View {
    let day: String
    let today: String
    private var title: String {
        day == today ? "Oggi" : day == CivilDate.adding(1, to: today) ? "Domani" : CivilDate.label(day)
    }
    var body: some View {
        Text(title).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("home-day-" + day)
    }
}

private struct HomeAgendaRow: View {
    @EnvironmentObject private var store: NativeStore
    @EnvironmentObject private var router: NativeRouter
    @State private var completing = false
    let event: Record
    var body: some View {
        NativeChecklistRow(title: event.text("title", fallback: "Appuntamento"),
            subtitle: "Evento · " + CivilDate.label(event.text("day")) + (event.text("start_time").isEmpty ? "" : " · " + event.text("start_time")), checked: event.text("occurrence_status") == "done",
            showsDisclosure: false,
            completionIdentifier: "home-event-check-" + event.agendaIdentity,
            openIdentifier: "home-agenda-" + event.agendaIdentity,
            completionLabel: "Completa evento " + event.text("title"),
            onComplete: complete, onOpen: { router.sheet = .event(event) })
            .disabled(completing || store.busy)
    }
    private func complete() {
        guard !completing else { return }
        completing = true
        Task {
            defer { completing = false }
            await store.run("setEventOccurrence", ["id": .int(event.integer("id")), "day": .string(event.text("day")), "status": .string("done")])
        }
    }
}

private struct HomeAgendaScreen: View {
    @EnvironmentObject var store: NativeStore
    private var events: [Record] { NativeHomeSummary(now: Date(), todayShift: nil, tomorrowShift: nil, events: store.dashboardEvents, weather: nil, weatherDate: nil).events }
    var body: some View {
        List {
            if events.isEmpty { ContentUnavailableView("Nessun appuntamento", systemImage: "calendar") }
            let groups = Dictionary(grouping: events, by: { $0.text("day") })
            ForEach(groups.keys.sorted(), id: \.self) { day in
                Section {
                    ForEach(groups[day] ?? [], id: \.agendaIdentity) { event in
                        HomeAgendaRow(event: event)
                    }
                } header: { HomeAgendaDayHeading(day: day, today: CivilDate.day()) }
            }
        }.modifier(NativeListAppearance()).navigationTitle("Prossimi appuntamenti").navigationBarTitleDisplayMode(.inline)
    }
}
