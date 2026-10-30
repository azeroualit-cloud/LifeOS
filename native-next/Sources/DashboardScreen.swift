import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
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
                    routines
                    agenda(summary, today: today)
                    nextTime(context.date)
                    NativeHealthCard(health: health, demo: NativeHealthLaunchPolicy.simulated)
                    NativeConnectionBadge()
                    if let notice = store.notice { Text(notice).font(.caption).foregroundStyle(NativeDesign.secondary) }
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.top, NativeDesign.Space.small).padding(.bottom, NativeDesign.Layout.scrollClearance)
            }
            .background(NativeDesign.canvas).scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("dashboard-scroll")
            .refreshable { await health.refresh() }
            .task(id: today) {
                // Home dates follow today without changing the month being browsed in Calendar.
                await store.loadWeather()
            }
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
                    }.buttonStyle(.plain).opacity(day < today ? NativeDesign.Layout.pastDayOpacity : 1).accessibilityIdentifier("dashboard-day-" + day)
                        .accessibilityLabel(CivilDate.label(day) + ", " + (shift?.title ?? "Turno non disponibile"))
                        .accessibilityAddTraits(current ? .isSelected : [])
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
    private func openCalendar(_ day: String) {
        store.calendarMonth = String(day.prefix(7)); router.showCalendar(day: day)
        Task { await store.sync(scope: .life) }
    }
    private func heading(_ summary: NativeHomeSummary, today: String, now: Date) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: NativeDesign.Space.medium) {
                headingText(summary, today: today)
                Spacer(minLength: NativeDesign.Space.small)
                activeShift(now: now, today: today)
            }
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                headingText(summary, today: today)
                activeShift(now: now, today: today)
            }
        }
    }
    private func headingText(_ summary: NativeHomeSummary, today: String) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(summary.greeting).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("home-greeting")
            Text(CivilDate.label(today).capitalized).font(NativeDesign.value).accessibilityAddTraits(.isHeader)
            if let weather = summary.phrases.first(where: { $0.lead == "A Empoli, " }) {
                Text(weather.detail).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
            }
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
            }.buttonStyle(.plain).accessibilityIdentifier("home-focus")
                .accessibilityLabel(model.title + ", " + model.remainingText + " alla fine")
                .accessibilityHint("Apre il giorno nel calendario")
                .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: NativeDesign.Motion.pressedScale)))
        }
        }.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: model.phase)
    }
    private func agenda(_ summary: NativeHomeSummary, today: String) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            NativeSectionHeader("Prossimi impegni", titleIdentifier: "home-agenda-heading") {
                if !summary.events.isEmpty {
                    NavigationLink { HomeAgendaScreen() } label: {
                        Text("Vedi tutti").font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget)
                    }.accessibilityIdentifier("home-events")
                }
            }
            if summary.events.isEmpty {
                Text(NativeHomeSummary.hasCalendarData(life: store.life, demo: store.isDemo) ? "Nessun appuntamento nei prossimi 7 giorni" : "Calendario da aggiornare")
                    .font(NativeDesign.body).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("home-agenda-empty")
            } else {
                let groups = Dictionary(grouping: summary.events, by: { $0.text("day") })
                VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                    ForEach(groups.keys.sorted(), id: \.self) { day in
                        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                            HomeAgendaDayHeading(day: day, today: today)
                            VStack(spacing: NativeDesign.Space.none) {
                                ForEach(Array((groups[day] ?? []).enumerated()), id: \.element.agendaIdentity) { index, event in
                                    if index > 0 { Divider().padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small) }
                                    HomeAgendaRow(event: event)
                                        .padding(.vertical, NativeDesign.Space.xs)
                                }
                            }
                        }
                    }
                }
            }
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
    private var routines: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            NativeSectionHeader("Abitudini di oggi", titleIdentifier: "home-routines-heading") {
                NavigationLink { RoutinesEditor() } label: { Text("Gestisci").font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget) }.accessibilityIdentifier("home-manage-routines")
            }
            if store.routines.isEmpty {
                NavigationLink { RoutinesEditor() } label: { Label("Aggiungi la prima abitudine", systemImage: "plus").font(.subheadline).frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading) }.accessibilityIdentifier("home-empty-routines")
            } else if store.todayRoutines.isEmpty {
                Text("Nessuna abitudine prevista per oggi.").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                VStack(spacing: NativeDesign.Space.none) {
                    ForEach(Array(store.todayRoutines.enumerated()), id: \.element.integerID) { index, record in
                        if index > 0 { Divider().padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small) }
                        Button { checkRoutine(record) } label: {
                            HStack(spacing: NativeDesign.Space.small) {
                                NativeCheckmark(checked: record.flag("checked"))
                                Text(record.text("title")).font(.body).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                if routineBusy == record.integer("id") { ProgressView().controlSize(.small) }
                            }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(NativePressStyle()).padding(.vertical, NativeDesign.Space.xs).disabled(store.busy || routineBusy != nil)
                            .accessibilityIdentifier("home-routine-\(record.integer("id"))")
                            .accessibilityLabel(record.text("title")).accessibilityValue(record.flag("checked") ? "Completata" : "Da completare")
                    }
                }
            }
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
            subtitle: event.text("start_time"), checked: event.text("occurrence_status") == "done",
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
