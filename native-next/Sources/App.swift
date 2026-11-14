import SwiftUI
import Combine
import UIKit

@main struct LifeOSProbe: App {
    @StateObject private var store: NativeStore
    @StateObject private var health: NativeHealthStore
    init() {
        var directory: URL?
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--visual-test") {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("visual-" + UUID().uuidString)
            UserDefaults.standard.set(args.contains("--dark") ? "dark" : "light", forKey: "native-theme")
            UserDefaults.standard.set(false, forKey: "native-hide-money")
        }
        #endif
        let value = directory == nil ? NativeServices.store : NativeStore(directory: directory, migrateLegacy: false)
        _health = StateObject(wrappedValue: directory == nil ? NativeServices.health : NativeHealthStore())
        #if DEBUG
        if args.contains("--expense-routing") { value.seedVisualExpenseRouting() }
        if args.contains("--activity-agenda") { value.seedVisualActivityAgenda() }
        if args.contains("--compact-calendar") { value.seedVisualCompactCalendar() }
        if args.contains("--off-day-habit") { value.seedVisualOffDayHabit() }
        if args.contains("--stress-content") { value.seedVisualTasks() }
        if args.contains("--stress-money") { value.seedVisualMoney() }
        if args.contains("--six-weeks") { value.calendarMonth = "2026-03" }
        if args.contains("--empty-home") { value.seedVisualHome(empty: true) }
        if args.contains("--busy-home") { value.seedVisualHome(empty: false) }
        #endif
        NativeNotifications.shared.start()
        _store = StateObject(wrappedValue: value)
    }
    @StateObject private var router = NativeRouter()
    var body: some Scene {
        WindowGroup {
            rootContent.environmentObject(store).environmentObject(health).environmentObject(router).tint(NativeDesign.accent)
                .environment(\.calendar, CivilDate.calendar)
                .environment(\.timeZone, CivilDate.calendar.timeZone)
                .modifier(NativeVisualTestSize()).modifier(NativeVisualTestMotion())
        }
    }
    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--apple-health-reference-seed") { NativeAppleHealthReferenceSeed() }
        else if ProcessInfo.processInfo.arguments.contains("--widget-preview") { NativeWidgetPreview() }
        else if ProcessInfo.processInfo.arguments.contains("--signin-preview") { NavigationStack { NativeSignInScreen {} } }
        else { NativeRoot() }
        #else
        NativeRoot()
        #endif
    }
}
enum NativeTab: Int, CaseIterable, Hashable, Identifiable {
    case dashboard, tasks, health, bloom, finance, calendar
    var id: Self { self }
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .tasks: return "Attività"
        case .health: return "Salute"
        case .bloom: return "Bloom"
        case .finance: return "Finanza"
        case .calendar: return "Calendario"
        }
    }
    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .tasks: return "checklist"
        case .health: return "heart"
        case .bloom: return "books.vertical"
        case .finance: return "chart.pie"
        case .calendar: return "calendar"
        }
    }
}
enum NativeDashboardDestination: Hashable { case finance, calendar }
enum NativeSheet: Identifiable {
    case weight(NativeWeightTransfer?)
    case financePlan, settings, task(Record), event(Record), movement(Record), extra(Record), routines, categories, budget, recurring(Record), planning
    var id: String {
        switch self {
        case .weight(let transfer): return "weight-" + (transfer?.id.uuidString ?? "new")
        case .financePlan: return "finance-plan"; case .settings: return "settings"; case .task: return "task"; case .event: return "event"
        case .movement: return "movement"; case .extra: return "extra"; case .routines: return "routines"
        case .categories: return "categories"; case .budget: return "budget"; case .recurring: return "recurring"; case .planning: return "planning"
        }
    }
}
@MainActor final class NativeRouter: ObservableObject {
    @Published var tab: NativeTab = .dashboard
    @Published var dashboardPath: [NativeDashboardDestination] = []
    @Published var bloomCaptureURL: String?
    @Published var sheet: NativeSheet?
    @Published var taskCategory = "action"
    @Published var financeSection = "Panoramica"
    @Published var calendarDay = CivilDate.day()
    @Published var activationDate = Date()
    @Published var calendarOpensDay = false
    @Published var calendarFocusRequest = UUID()
    var requestedCalendarDay: String?
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--six-weeks") { requestedCalendarDay = "2026-03-01"; calendarDay = "2026-03-01" }
        #endif
    }
    func enterCalendar(today: String = CivilDate.day()) -> String {
        let day = requestedCalendarDay ?? today
        calendarOpensDay = requestedCalendarDay != nil
        requestedCalendarDay = nil; calendarDay = day; calendarFocusRequest = UUID()
        return day
    }
    func showCalendar(day: String = CivilDate.day(), opensDay: Bool = true) {
        calendarOpensDay = opensDay
        let alreadyOpen = tab == .dashboard && dashboardPath.last == .calendar
        requestedCalendarDay = alreadyOpen ? nil : day; calendarDay = day; tab = .dashboard
        dashboardPath = [.calendar]; calendarFocusRequest = UUID()
    }
}
struct NativeRoot: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("native-theme") private var theme = "system"
    @State private var currentDay = CivilDate.day()
    @State private var returnedFromBackground = false
    @EnvironmentObject private var health: NativeHealthStore
    @AppStorage("native-reminders-enabled") private var remindersEnabled = false
    var body: some View {
        nativeTabs
        .symbolVariant(.none).symbolRenderingMode(.monochrome)
        .font(NativeDesign.body)
        .environment(\.defaultMinListRowHeight, NativeDesign.Layout.touchTarget)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .sheet(item: $router.sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .weight(let transfer): NativeAddWeightSheet(health: health, transfer: transfer)
                case .financePlan: NativePlanEditor()
                case .settings: NativeSettings()
                case .task(let record): TaskEditor(record: record)
                case .event(let record): EventEditor(record: record)
                case .movement(let record): MovementEditor(record: record)
                case .extra(let record): ExtraEditor(record: record)
                case .routines: RoutinesEditor()
                case .categories: CategoriesEditor()
                case .budget: BudgetDetail()
                case .recurring: NativePlansScreen()
                case .planning: PlanningEditor()
                }
            }.modifier(NativeVisualTestSize()).modifier(NativeVisualTestMotion())
                .presentationDragIndicator(.visible)
        }
        .alert("Operazione non riuscita", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task {
            if let url = NativeIntentDraft.pendingURL { route(url) }
            if NativeIntentDraft.taskTitle != nil { route(URL(string: "lifeos://task")!) }
            await health.start(demo: NativeHealthLaunchPolicy.simulated)
            await store.sync(automatic: true)
        }
        .onOpenURL { route($0) }
        .onReceive(NotificationCenter.default.publisher(for: .lifeOSRoute)) { note in
            if let url = note.object as? URL { route(url) }
        }
        .onChange(of: store.life, initial: true) { _, _ in updateReminders() }
        .task(id: NativeUrgentAlarmSource(life: store.life, editing: router.sheet != nil)) {
            guard router.sheet == nil, !store.isDemo else { return }
            do { try await NativeUrgentAlarm.reconcile(life: store.life) }
            catch { if !Task.isCancelled { store.error = "Controlla le sveglie urgenti: " + error.localizedDescription } }
        }
        .onChange(of: remindersEnabled) { _, _ in updateReminders() }
        .onChange(of: store.isDemo) { _, _ in updateReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { returnedFromBackground = true }
            if phase == .active {
                if returnedFromBackground {
                    returnedFromBackground = false; router.activationDate = Date()
                }
                currentDay = CivilDate.day(); store.rollover(); Task { await store.sync(automatic: true) } }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            let day = CivilDate.day()
            if day != currentDay {
                currentDay = day; store.rollover()
                Task { await store.sync(automatic: true) }
            } else if scenePhase == .active { Task { await store.sync(automatic: true) } }
        }
    }
    private func updateReminders() { NativeNotifications.shared.update(life: store.life, enabled: remindersEnabled && !store.isDemo) }
    private func route(_ url: URL) {
        if let target = NativeReminderTarget(url) {
            NativeIntentDraft.pendingURL = nil
            switch target.kind {
            case .task:
                router.tab = .tasks
                if let record = store.tasks.first(where: { $0.integer("id") == target.id }) {
                    router.taskCategory = record.text("list_kind", fallback: "action")
                    router.sheet = .task(record)
                } else { store.notice = "L’attività non è più disponibile. Aggiorna i dati per verificarla." }
            case .event, .day:
                router.showCalendar(day: target.day); store.calendarMonth = String(target.day.prefix(7))
                if target.kind == .event, let record = store.events.first(where: { $0.integer("id") == target.id && $0.text("day") == target.day }) { router.sheet = .event(record) }
            }
            return
        }
        if url.scheme == "lifeos", url.host == "bloom" {
            if let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "url" })?.value {
                guard router.sheet == nil else { store.notice = "Chiudi la schermata aperta e riapri il link per preparare la nota Bloom."; return }
                guard let target = URL(string: raw), ["https", "http"].contains(target.scheme?.lowercased() ?? ""), target.host != nil else { store.error = "Link Bloom non valido."; return }
                router.bloomCaptureURL = raw
            }
            NativeIntentDraft.pendingURL = nil; router.tab = .bloom
            return
        }
        if url.scheme == "lifeos", url.host == "weight", url.query != nil {
            do {
                let transfer = try NativeWeightTransfer(url: url)
                guard router.sheet == nil else { throw Message(text: "Chiudi prima la schermata aperta e riapri la pesata.") }
                router.sheet = .weight(transfer)
            } catch { store.error = error.localizedDescription }
            return
        }
        guard let route = LifeOSRoute(url) else { return }
        NativeIntentDraft.pendingURL = nil
        switch route {
        case .activities: router.tab = .tasks
        case .task:
            guard router.sheet == nil else { store.notice = "Chiudi la schermata aperta per aggiungere un’attività."; return }
            var record: Record = ["list_kind": .string(router.taskCategory)]
            if let title = NativeIntentDraft.taskTitle { record["title"] = .string(title); NativeIntentDraft.taskTitle = nil }
            router.tab = .tasks; router.sheet = .task(record)
        case .weight: router.tab = .dashboard; router.sheet = .weight(nil)
        case .calendar: router.showCalendar(opensDay: false)
        case .dashboard: router.tab = .dashboard
        }
    }
    @State private var keyboardVisible = false
    private var nativeTabs: some View {
        NativeTabContainer(selection: router.tab) { tab in
            AnyView(tabContent(tab)
                .environmentObject(store).environmentObject(router).environmentObject(health)
                .environment(\.calendar, CivilDate.calendar)
                .environment(\.timeZone, CivilDate.calendar.timeZone)
                .environment(\.defaultMinListRowHeight, NativeDesign.Layout.touchTarget)
                .font(NativeDesign.body).tint(NativeDesign.accent)
                .symbolVariant(.none).symbolRenderingMode(.monochrome)
                .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
                .modifier(NativeVisualTestSize()).modifier(NativeVisualTestMotion()))
        }
        .background(NativeDesign.canvas)
        .safeAreaInset(edge: .bottom, spacing: NativeDesign.Space.none) {
            if !keyboardVisible {
                NativeSixTabBar(selection: $router.tab) {
                    if router.tab == .dashboard { router.dashboardPath = [] }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
    }
    @ViewBuilder private func tabContent(_ tab: NativeTab) -> some View {
        Group {
            switch tab {
            case .dashboard: dashboard
            case .tasks: tasks
            case .health: NavigationStack { NativeHealthDetail(health: health, demo: NativeHealthLaunchPolicy.simulated) }
            case .bloom: NavigationStack { NativeBloomScreen() }
            case .finance: NavigationStack { FinanceScreen() }
            case .calendar: NavigationStack { CalendarScreen() }
            }
        }
        .modifier(NativeTabArrival(tab: tab))
    }
    private var dashboard: some View {
        NavigationStack(path: $router.dashboardPath) {
            DashboardScreen().toolbar { tools }.navigationTitle("Dashboard").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: NativeDashboardDestination.self) { destination in
                    switch destination {
                    case .finance: FinanceScreen()
                    case .calendar: CalendarScreen()
                    }
                }
        }
    }
    private var tasks: some View { NavigationStack { TasksScreen().toolbar { tools }.navigationTitle("Attività").navigationBarTitleDisplayMode(.inline) } }
    @ToolbarContentBuilder private var tools: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { addControl }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarLeading) { settingsControl }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { addControl }
            ToolbarItem(placement: .topBarLeading) { settingsControl }
        }
    }
    private var addControl: some View {
        NativeToolbarButton(symbol: "plus", label: addLabel, action: addItem)
            .accessibilityIdentifier("primary-add")
    }
    private var settingsControl: some View {
        NativeToolbarButton(symbol: "gearshape", label: "Impostazioni") { router.sheet = .settings }
            .contextMenu { Button("Sincronizza", systemImage: "arrow.triangle.2.circlepath") { Task { await store.sync() } }.disabled(store.busy || store.syncing) }
    }
    private func addItem() {
        switch router.tab {
        case .dashboard, .finance: router.sheet = .movement([:])
        case .calendar: router.sheet = .event(["day": .string(router.calendarDay)])
        case .health: break
        case .bloom: break
        case .tasks: router.sheet = .task(["list_kind": .string(router.taskCategory)])
        }
    }
    private var addLabel: String {
        switch router.tab {
        case .dashboard, .finance: return "Aggiungi spesa"
        case .calendar: return "Aggiungi evento"
        case .health: return "Aggiungi nutrienti"
        case .bloom: return "Nuova nota"
        case .tasks: return "Aggiungi attività"
        }
    }
}
private struct NativeTabArrival: ViewModifier {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let tab: NativeTab
    @EnvironmentObject private var router: NativeRouter
    private var selection: NativeTab { router.tab }
    @State private var offset: CGFloat = 0
    @State private var arrivalTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.offset(x: offset)
            .onChange(of: selection) { previous, current in
                reset()
                guard current == tab, !reduceMotion else { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { offset = current.rawValue > previous.rawValue ? 28 : -28 }
                arrivalTask = Task { @MainActor in
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: NativeDesign.Motion.selectionDuration)) { offset = 0 }
                }
            }
            .onChange(of: reduceMotion) { _, reduced in if reduced { reset() } }
            .onDisappear { reset() }
    }

    private func reset() {
        arrivalTask?.cancel()
        arrivalTask = nil
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { offset = 0 }
    }
}

struct MoneyText: View {
    let amount: Double
    var large = false
    var body: some View {
        Text(amount.euro).font(large ? .system(.largeTitle, weight: .bold) : .body)
            .modifier(NativeNumericFeedback(value: amount))
            .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
    }
}
struct MonthControl: View {
    @EnvironmentObject var store: NativeStore
    let finance: Bool
    var body: some View {
        HStack {
            Button { Task { await store.changeMonth(-1, finance: finance) } } label: { Image(systemName: "chevron.left").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Mese precedente")
            Spacer(); Text(CivilDate.monthTitle(finance ? store.financeMonth : store.calendarMonth)).font(.headline).accessibilityIdentifier(finance ? "finance-month" : "calendar-month")
            Spacer(); Button { Task { await store.changeMonth(1, finance: finance) } } label: { Image(systemName: "chevron.right").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Mese successivo")
        }.buttonStyle(NativePressStyle()).disabled(store.busy)
    }
}
struct DoneButton: ToolbarContent {
    @Environment(\.dismiss) private var dismiss
    var body: some ToolbarContent { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
}

struct NativeVisualTestSize: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--large-text") { content.dynamicTypeSize(.accessibility2) }
        else { content }
        #else
        content
        #endif
    }
}

/// A local test override; normal launches retain the user's system preference.
struct NativeVisualTestMotion: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reduce-motion") {
            content.environment(\.nativeForceReduceMotion, true)
        } else { content }
        #else
        content
        #endif
    }
}
