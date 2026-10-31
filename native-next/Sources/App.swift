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
        if ProcessInfo.processInfo.arguments.contains("--widget-preview") { NativeWidgetPreview() }
        else if ProcessInfo.processInfo.arguments.contains("--signin-preview") { NavigationStack { NativeSignInScreen {} } }
        else { NativeRoot() }
        #else
        NativeRoot()
        #endif
    }
}
enum NativeTab: Hashable { case dashboard, tasks, calendar, finance }
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
    func showCalendar(day: String = CivilDate.day()) {
        calendarOpensDay = true
        let alreadyOpen = tab == .calendar
        requestedCalendarDay = alreadyOpen ? nil : day; calendarDay = day; tab = .calendar
        if alreadyOpen { calendarFocusRequest = UUID() }
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
        .modifier(NativeTabBarAppearance())
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
            }.presentationDragIndicator(.visible)
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
        .onChange(of: router.tab) { _, tab in
            if tab == .calendar {
                let day = router.enterCalendar()
                store.calendarMonth = String(day.prefix(7))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { returnedFromBackground = true }
            if phase == .active {
                if returnedFromBackground {
                    returnedFromBackground = false; router.activationDate = Date()
                    if router.tab == .calendar { router.calendarOpensDay = false; router.calendarDay = CivilDate.day(); router.calendarFocusRequest = UUID(); store.calendarMonth = CivilDate.month() }
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
        case .calendar: router.showCalendar()
        case .dashboard: router.tab = .dashboard
        }
    }
    // Native destinations only: no custom capsule, animation or action disguised as a tab.
    private var nativeTabs: some View {
        TabView(selection: $router.tab) {
            dashboard.tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }.tag(NativeTab.dashboard)
            tasks.tabItem { Label("Attività", systemImage: "checklist") }.tag(NativeTab.tasks)
            calendar.tabItem { Label("Calendario", systemImage: "calendar") }.tag(NativeTab.calendar)
            finance.tabItem { Label("Finanza", systemImage: "chart.bar") }.tag(NativeTab.finance)
        }
    }
    private var dashboard: some View { NavigationStack { DashboardScreen().toolbar { tools }.navigationTitle("Dashboard").navigationBarTitleDisplayMode(.inline) } }
    private var tasks: some View { NavigationStack { TasksScreen().toolbar { tools }.navigationTitle("Attività").navigationBarTitleDisplayMode(.inline) } }
    private var calendar: some View { NavigationStack { CalendarScreen().toolbar { tools }.navigationTitle("Calendario").navigationBarTitleDisplayMode(.inline) } }
    private var finance: some View { NavigationStack { FinanceScreen().toolbar { financeTools }.navigationTitle("Finanza").navigationBarTitleDisplayMode(.large) } }
    @ToolbarContentBuilder private var financeTools: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) { settingsControl; addControl }
    }
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
        case .dashboard: router.sheet = .movement([:])
        case .finance: router.sheet = router.financeSection == "Budget" ? .financePlan : .movement([:])
        case .tasks: router.sheet = .task(["list_kind": .string(router.taskCategory)])
        case .calendar: router.sheet = .event(["day": .string(router.calendarDay)])
        }
    }
    private var addLabel: String {
        switch router.tab {
        case .dashboard: return "Aggiungi spesa"
        case .finance: return router.financeSection == "Budget" ? "Nuovo piano" : "Aggiungi spesa"
        case .tasks: return "Aggiungi attività"
        case .calendar: return "Aggiungi evento"
        }
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
