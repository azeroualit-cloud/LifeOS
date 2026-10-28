import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @State private var routineBusy: Int?
    @State private var routineFeedback = false
    @State private var showingTimes = false
    @EnvironmentObject private var health: NativeHealthStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date, today = CivilDate.day(now)
            let summary = NativeHomeSummary(now: now, todayShift: store.shift(today), tomorrowShift: store.shift(CivilDate.adding(1, to: today)), previousShift: store.shift(CivilDate.adding(-1, to: today)), events: store.dashboardEvents, weather: store.weather == "Meteo non disponibile" ? nil : store.weatherDetails, weatherDate: store.weatherDate, calendarAvailable: NativeHomeSummary.hasCalendarData(life: store.life, demo: store.isDemo))
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                    heading(summary, today: today)
                    rollingCalendar(today)
                    focus(now: now, today: today)
                    agenda(summary, today: today)
                    nextTime(context.date)
                    routines
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
            HStack {
                Text(CivilDate.monthTitle(String(today.prefix(7)))).font(.subheadline).foregroundStyle(NativeDesign.secondary)
                Spacer()
                NativeIconButton(symbol: "calendar", label: "Apri calendario") { openCalendar(today) }
            }
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
                            Text(["D", "L", "M", "M", "G", "V", "S"][weekday - 1]).font(.caption).foregroundStyle(NativeDesign.secondary)
                            CalendarDayCell(item: item, active: current).equatable()
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("dashboard-day-" + day)
                        .accessibilityLabel(CivilDate.label(day) + ", " + (shift?.title ?? "Turno non disponibile"))
                        .accessibilityAddTraits(current ? .isSelected : [])
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
    private func openCalendar(_ day: String) {
        store.calendarMonth = String(day.prefix(7)); router.calendarDay = day; router.tab = .calendar
        Task { await store.sync(scope: .life) }
    }
    private func heading(_ summary: NativeHomeSummary, today: String) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(summary.greeting).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("home-greeting")
            Text(CivilDate.label(today).capitalized)
                .font(NativeDesign.value).accessibilityAddTraits(.isHeader)
        }
    }
    private func focus(now: Date, today: String) -> some View {
        let model = NativeDashboardFocus(now: now, todayShift: store.shift(today), previousShift: store.shift(CivilDate.adding(-1, to: today)))
        return Button { openCalendar(today) } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                HStack {
                    Text(model.phase).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(NativeDesign.secondary).accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                    if let shift = model.shift {
                        Text(shift.letter).font(NativeDesign.heading).foregroundStyle(shift.color)
                    }
                    Text(model.title).font(NativeDesign.value).foregroundStyle(Color.primary)
                }
                if model.interval != nil {
                    Text(model.shift?.time ?? "").font(NativeDesign.body).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                    Text(model.remainingText).font(NativeDesign.heading).monospacedDigit().foregroundStyle(Color.primary)
                    Text(model.countdownLabel).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                } else {
                    Text(model.detail).font(NativeDesign.body).foregroundStyle(NativeDesign.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(NativeDesign.Layout.cardInset)
                .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius))
                .contentShape(Rectangle())
        }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-focus")
            .accessibilityHint("Apre il giorno nel calendario")
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
                ForEach(Array(summary.events.prefix(3).enumerated()), id: \.offset) { _, event in
                    Button { router.sheet = .event(event) } label: {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text(agendaDate(event, today: today)).font(NativeDesign.metadata).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                            HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                                Image(systemName: "circle.fill").font(.caption2).foregroundStyle(NativeDesign.accent).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                                    Text(event.text("title", fallback: "Appuntamento")).font(NativeDesign.heading).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
                                    if !event.text("location").isEmpty { Text(event.text("location")).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary) }
                                }
                                Spacer(minLength: 0)
                            }
                        }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                            .padding(.vertical, NativeDesign.Space.small).contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-agenda-" + String(event.integer("id")) + "-" + event.text("day"))
                }
            }
        }
    }
    private func agendaDate(_ event: Record, today: String) -> String {
        let day = event.text("day")
        let label = day == today ? "Oggi" : day == CivilDate.adding(1, to: today) ? "Domani" : CivilDate.label(day)
        return label + " · " + (event.text("start_time").isEmpty ? "Tutto il giorno" : event.text("start_time"))
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
            NativeSectionHeader("Abitudini", titleIdentifier: "home-routines-heading") {
                NavigationLink { RoutinesEditor() } label: { Text("Gestisci").font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget) }.accessibilityIdentifier("home-manage-routines")
            }
            if store.routines.isEmpty {
                NavigationLink { RoutinesEditor() } label: { Label("Aggiungi la prima abitudine", systemImage: "plus").font(.subheadline).frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading) }.accessibilityIdentifier("home-empty-routines")
            } else if store.todayRoutines.isEmpty {
                Text("Nessuna abitudine prevista per oggi.").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                NativeGroupedCard {
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

private extension Dictionary where Key == String, Value == JSONValue { var integerID: Int { integer("id") } }

private struct HomeAgendaScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    private var events: [Record] { NativeHomeSummary(now: Date(), todayShift: nil, tomorrowShift: nil, events: store.dashboardEvents, weather: nil, weatherDate: nil).events }
    var body: some View {
        List {
            if events.isEmpty { ContentUnavailableView("Nessun appuntamento", systemImage: "calendar") }
            ForEach(events.map { DisplayRecord($0) }) { item in
                Button { router.sheet = .event(item.value) } label: {
                    NativeRowText(title: item.value.text("title"), subtitle: CivilDate.label(item.value.text("day")) + (item.value.text("start_time").isEmpty ? "" : " · " + item.value.text("start_time")))
                }.buttonStyle(.plain)
            }
        }.modifier(NativeListAppearance()).navigationTitle("Prossimi appuntamenti").navigationBarTitleDisplayMode(.inline)
    }
}
