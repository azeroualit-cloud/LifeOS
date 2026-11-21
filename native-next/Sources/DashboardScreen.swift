import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @AppStorage("native-hide-money") private var hiddenMoney = false
    @State private var routineBusy: Int?
    @State private var routineFeedback = false
    @State private var showingTimes = false
    @EnvironmentObject private var health: NativeHealthStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date, today = CivilDate.day(now)
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                    heading(today: today, now: now)
                    // DASHBOARD-93-2026-11-21: week, things to do, nutrition, finance, appointments.
                    rollingCalendar(today, now: now)
                    checklist(today: today)
                    NativeNutritionQuickEntry()
                    financeOverview
                    upcomingAppointments(today: today)
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

    private func rollingCalendar(_ today: String, now: Date) -> some View {
        let days = NativeHomeSummary.rollingDays(today)
        let marked = Set(store.events.map { $0.text("day") } + store.tasks.map { $0.text("scheduled_date") })
        return NativeCard(density: .compact, topInset: NativeDesign.Space.xs) {
            Button { openCalendar(today) } label: {
                LOCardHeader(title: "Settimana", systemImage: "calendar", section: .calendar, showsChevron: true)
                    .contentShape(Rectangle())
            }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-calendar")
            HStack(spacing: NativeDesign.Space.xs) {
                ForEach(days, id: \.self) { day in
                    let current = day == today, shift = store.shift(day)
                    let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(day))
                    let item = CalendarDayPresentation(day: day, label: CivilDate.label(day), shift: shift,
                        eventCount: marked.contains(day) ? 1 : 0, isToday: current,
                        isWeekend: weekday == 1 || weekday == 7,
                        isCurrentMonth: day.hasPrefix(String(today.prefix(7))))
                    Button { openCalendar(day, opensDay: true) } label: {
                        VStack(spacing: NativeDesign.Space.xs) {
                            Text(["D", "L", "M", "M", "G", "V", "S"][weekday - 1]).font(.caption).foregroundStyle(day < today ? NativeDesign.pastCalendarSecondary : NativeDesign.secondary)
                            CalendarDayCell(item: item, active: current, appearance: .week).equatable()
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle()).opacity(day < today ? NativeDesign.Layout.pastDayOpacity : 1).accessibilityIdentifier("dashboard-day-" + day)
                        .accessibilityLabel(CivilDate.label(day) + ", " + (shift?.title ?? "Turno non disponibile"))
                        .accessibilityAddTraits(current ? .isSelected : [])
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            if let next = NativeDashboard93.nextShift(now: now, shift: { store.shift($0) }) {
                HStack(spacing: NativeDesign.Space.small) {
                    Text("Prossimo turno").foregroundStyle(NativeDesign.secondary)
                    Circle().fill(next.kind.color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                        .accessibilityHidden(true)
                    Text(next.kind.title + ", " + NativeDashboard93.label(next, today: today)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home-next-shift")
            }
        }
    }
    private func openCalendar(_ day: String, opensDay: Bool = false) {
        store.calendarMonth = String(day.prefix(7)); router.showCalendar(day: day, opensDay: opensDay)
        Task { await store.sync(scope: .life) }
    }
    private func heading(today: String, now: Date) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small))
        return layout {
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                Text(CivilDate.date(today).formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT"))))
                    .accessibilityLabel(CivilDate.label(today)).accessibilityIdentifier("home-today")
                    .font(.title.bold()).accessibilityAddTraits(.isHeader)
                    .layoutPriority(1)
                nextTime(now)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            activeShift(now: now, today: today)
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
                Text(model.title).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, NativeDesign.Space.medium)
                    .padding(.vertical, NativeDesign.Space.xs)
                    .background {
                        NativeShiftProgressBar(model: model, now: focusNow, activation: router.activationDate)
                    }
                    .clipShape(Capsule())
                    .frame(minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
            }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-focus")
                .accessibilityLabel(model.title + ", " + model.remainingText + " alla fine")
                .accessibilityHint("Apre il calendario completo")
                .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: NativeDesign.Motion.pressedScale)))
        }
        }.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: model.phase)
    }
    private func checklist(today: String) -> some View {
        let items = NativeHomeChecklist.rows(events: store.dashboardEvents, routines: store.todayRoutines, today: today)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(spacing: NativeDesign.Space.medium) {
                Text("Cose da fare").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home-checklist-heading")
                Spacer(minLength: NativeDesign.Space.small)
                Menu {
                    Button("Attività") { router.tab = .tasks }
                    Button("Abitudini") { router.sheet = .routines }
                    Button("Calendario") { openCalendar(today) }
                } label: {
                    Text("Gestisci").font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                        .padding(.horizontal, NativeDesign.Space.medium)
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                        .modifier(NativeGlass())
                }
            }
            if items.isEmpty {
                Text("Nessun impegno da mostrare").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                LOListCard {
                    ForEach(items) { item in
                        checklistRow(item)
                            .padding(.leading, NativeDesign.Space.xs)
                            .padding(.trailing, NativeDesign.Space.large)
                            .padding(.vertical, NativeDesign.Space.xxs)
                            .frame(minHeight: NativeDesign.Layout.rowHeight)
                            .loRowSeparator(hidden: item.id == items.last?.id, leadingInset: NativeDesign.Layout.touchTarget + NativeDesign.Space.small)
                    }
                }
            }
        }
    }
    @ViewBuilder private func checklistRow(_ item: NativeHomeChecklistItem) -> some View {
        let record = item.record
        switch item.kind {
        case .event: HomeAgendaRow(event: record)
        case .routine:
            NativeChecklistRow(title: record.text("title"), subtitle: "Abitudine", checked: record.flag("checked"), completionLabel: "Completa abitudine " + record.text("title"), onComplete: { checkRoutine(record) }, onOpen: { router.sheet = .routines })
                .disabled(store.busy || routineBusy != nil)

        }
    }
    @ViewBuilder private func nextTime(_ now: Date) -> some View {
        if let next = NativeNextTime.next(now: now) {
            Button { showingTimes = true } label: {
                Text(next.time).font(.subheadline.weight(.medium)).monospacedDigit()
                    .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
                    .contentShape(Rectangle())
            }.buttonStyle(NativePressStyle())
                .accessibilityLabel("Prossimo orario, " + next.label + (next.day == CivilDate.day(now) ? "" : ", domani"))
                .accessibilityValue(next.time)
                .accessibilityIdentifier("home-next-time")
                .sheet(isPresented: $showingTimes) {
                    NavigationStack {
                        List {
                            ForEach(Array(Set([CivilDate.day(now), next.day])).sorted(), id: \.self) { day in
                                Section("Empoli · " + CivilDate.label(day)) {
                                    ForEach(NativeNextTime.schedule(day: day), id: \.label) { time in
                                        LabeledContent(time.label, value: time.time).monospacedDigit()
                                    }
                                }
                            }
                            Section { Text("Empoli · Europe/Rome").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                        }.modifier(NativeListAppearance()).navigationTitle("Orari").navigationBarTitleDisplayMode(.inline).toolbar { DoneButton() }
                    }.presentationDetents([.medium, .large])
                }
        }
    }
    /// Finance card (DASHBOARD-93-2026-11-21): what is left this month, per day, spent/left bar.
    /// Adding an expense lives in Finanza's bottom glass action.
    private var financeOverview: some View {
        let overview = NativeFinanceOverview(summary: store.summary, month: store.financeMonth)
        let spent = store.summary.amount("monthlySpent")
        let fraction = NativeDashboard93.spentFraction(spent: spent, remaining: overview.remaining)
        let amount = hiddenMoney ? "•••• €" : overview.remaining.map(\.euro) ?? "—"
        let daily = hiddenMoney ? "•••• €" : overview.daily.euro
        // Explicit path write, like the Calendar entry: a value link did not push
        // after a programmatic Calendar visit (gate 91 run 43999971306).
        return Button { router.dashboardPath = [.finance] } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                LOCardHeader(title: "Finanza", systemImage: "chart.bar", section: .finance, showsChevron: true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                        financeAmount(amount)
                        Spacer(minLength: NativeDesign.Space.small)
                        financeDaily(daily, overview: overview)
                    }
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        financeAmount(amount)
                        financeDaily(daily, overview: overview)
                    }
                }
                if let fraction, !hiddenMoney {
                    LOSplitBar(segments: [LOSegment(id: "spent", value: fraction, color: NativeDesign.financialRed),
                                          LOSegment(id: "left", value: 1 - fraction, color: NativeDesign.financialGreen)],
                               scale: 1, height: NativeDesign.Space.small,
                               accessibilityText: "Speso \(Int((fraction * 100).rounded())) per cento, rimane \(Int(((1 - fraction) * 100).rounded())) per cento")
                }
            }
            .padding(NativeDesign.Layout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityLabel(financeLabel(overview))
        .accessibilityIdentifier("home-finance")
    }
    private func financeLabel(_ overview: NativeFinanceOverview) -> String {
        if hiddenMoney { return "Finanza, importo nascosto disponibili" }
        guard let remaining = overview.remaining else { return "Finanza, nessun dato disponibili" }
        let perDay: String = overview.daily.euro
        return "Finanza, " + remaining.euro + " disponibili, " + perDay + " al giorno"
    }
    private func financeAmount(_ amount: String) -> some View {
        Text(amount).font(.title.bold()).monospacedDigit().foregroundStyle(.primary)
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityIdentifier("home-budget-value")
    }
    @ViewBuilder private func financeDaily(_ daily: String, overview: NativeFinanceOverview) -> some View {
        if overview.remaining != nil && overview.days > 0 {
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                Text(daily).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text("al giorno").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home-budget-label")
        }
    }
    private func upcomingLabel(_ event: Record) -> String {
        var parts: [String] = [event.text("title", fallback: "Appuntamento"), CivilDate.label(event.text("day"))]
        if !event.text("start_time").isEmpty { parts.append(event.text("start_time")) }
        return parts.joined(separator: ", ")
    }
    /// Events after the checklist window, at most three (preview "Prossimi appuntamenti").
    @ViewBuilder private func upcomingAppointments(today: String) -> some View {
        let source = store.isDemo ? store.events : store.life.records("upcomingEvents") + store.events
        let rows = NativeDashboard93.upcoming(events: source, today: today)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                Text("Prossimi appuntamenti").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                LOListCard {
                    ForEach(rows, id: \.agendaIdentity) { event in
                        Button { router.sheet = .event(event) } label: {
                            LOListRow(isLast: event.agendaIdentity == rows.last?.agendaIdentity, leadingInset: NativeDesign.Space.large + NativeDesign.Layout.touchTarget) {
                                let date = CivilDate.date(event.text("day"))
                                VStack(spacing: NativeDesign.Space.none) {
                                    Text(date.formatted(.dateTime.day())).font(.body.weight(.bold)).monospacedDigit()
                                    Text(date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "it_IT")))).font(.caption2).foregroundStyle(NativeDesign.secondary)
                                }
                                .frame(width: NativeDesign.Layout.touchTarget)
                                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                    Text(event.text("title", fallback: "Appuntamento")).font(.body).foregroundStyle(.primary).lineLimit(2)
                                    let detail = event.text("start_time")
                                    if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                                }
                                Spacer(minLength: NativeDesign.Space.small)
                                NativeDisclosureIndicator()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NativePressStyle())
                        .accessibilityLabel(upcomingLabel(event))
                        .accessibilityIdentifier("home-upcoming-" + event.agendaIdentity)
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
