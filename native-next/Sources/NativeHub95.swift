import Foundation
import HealthKit
import UserNotifications

/// SITE-ADMIN-HUB-2026-11-23: the site is where goals, alert rules and prayer notifications are
/// managed; the iPhone stays light. On launch and when the app becomes active it reads the shared
/// settings, keeps the nutrition goals in step (newest copy wins), tells the site its computed
/// targets, schedules the local notifications and reports the ones already shown.
@MainActor final class NativeHub95 {
    static let shared = NativeHub95()
    private let defaults = UserDefaults.standard
    nonisolated private static let goalsModifiedKey = "native-nutrition-goals-modified-95"
    private static let fibreGoalKey = "native-fibre-goal-95"
    private static let targetsSentKey = "native-nutrition-targets-sent-95"
    private static let loggedKey = "native-alert-log-sent-95"
    static let prefix = "hub95-"
    private var running = false

    /// Fibre target chosen on the site (nil: none).
    var fibreGoal: Double? {
        let value = defaults.double(forKey: Self.fibreGoalKey)
        return value > 0 ? value : nil
    }

    func refresh(store: NativeStore, health: NativeHealthStore) async {
        guard !running, !store.isDemo, store.server != nil else { return }
        running = true; defer { running = false }
        let read: (String, [JSONValue]) async throws -> JSONValue = { method, args in try await store.read(method, args: args) }
        guard let probe = try? await read("getSettings", [.string("alerts")]) else { return } // Worker not updated yet
        await syncGoals(read)
        await publishTargets(read, health: health)
        await reportDelivered(read)
        schedule(probe.object.record("doc"), store: store, health: health)
    }

    // MARK: Goals

    private func syncGoals(_ read: (String, [JSONValue]) async throws -> JSONValue) async {
        guard let remote = try? await read("getSettings", [.string("nutrition-goals")]).object else { return }
        let remoteModified = remote.amount("modified")
        let localModified = defaults.double(forKey: Self.goalsModifiedKey)
        let doc = remote.record("doc")
        if doc["fibre"]?.number != nil { defaults.set(doc.amount("fibre"), forKey: Self.fibreGoalKey) }
        let preferences = NativeHealthPreferences.shared
        if remoteModified > localModified, let goals = Self.goals(from: doc, base: preferences.goals) {
            preferences.goals = goals
            defaults.set(remoteModified, forKey: Self.goalsModifiedKey)
        } else if localModified > remoteModified {
            var merged = doc
            for (key, value) in Self.record(preferences.goals) { merged[key] = value }
            _ = try? await read("saveSettings", [.string("nutrition-goals"), .object(merged), .number(localModified)])
        }
    }
    /// Called when the goals change on this iPhone, so the next sync sends them to the site.
    nonisolated static func goalsChangedOnPhone() { UserDefaults.standard.set(Date().timeIntervalSince1970 * 1000, forKey: goalsModifiedKey) }

    static func goals(from doc: Record, base: NativeNutritionGoals) -> NativeNutritionGoals? {
        guard !doc.isEmpty else { return nil }
        var goals = base
        if let mode = NativeNutritionGoals.CalorieMode(rawValue: doc.text("calorieMode")) { goals.calorieMode = mode }
        if doc["adjustment"]?.number != nil { goals.adjustment = doc.amount("adjustment") }
        if doc["fixedCalories"]?.number != nil { goals.fixedCalories = doc.amount("fixedCalories") }
        if let unit = NativeNutritionGoals.MacroUnit(rawValue: doc.text("proteinUnit")) { goals.proteinUnit = unit }
        if doc["protein"]?.number != nil { goals.protein = doc.amount("protein") }
        if let unit = NativeNutritionGoals.MacroUnit(rawValue: doc.text("fatUnit")) { goals.fatUnit = unit }
        if doc["fat"]?.number != nil { goals.fat = doc.amount("fat") }
        return goals
    }
    static func record(_ goals: NativeNutritionGoals) -> Record {
        ["calorieMode": .string(goals.calorieMode.rawValue), "adjustment": .number(goals.adjustment), "fixedCalories": .number(goals.fixedCalories),
         "proteinUnit": .string(goals.proteinUnit.rawValue), "protein": .number(goals.protein), "fatUnit": .string(goals.fatUnit.rawValue), "fat": .number(goals.fat)]
    }

    private func publishTargets(_ read: (String, [JSONValue]) async throws -> JSONValue, health: NativeHealthStore) async {
        guard let targets = health.goalTargets else { return }
        var doc: Record = ["calories": .number(targets.calories), "protein": .number(targets.protein), "carbohydrate": .number(targets.carbohydrate), "fat": .number(targets.fat)]
        if let tdee = health.estimate?.tdee { doc["tdee"] = .number(tdee.rounded()) }
        if let weight = health.goalWeight { doc["weight"] = .number((weight * 10).rounded() / 10) }
        let signature = [targets.calories, targets.protein, targets.carbohydrate, targets.fat].map { String(Int($0)) }.joined(separator: "|")
        guard defaults.string(forKey: Self.targetsSentKey) != signature else { return }
        if (try? await read("saveSettings", [.string("nutrition-targets"), .object(doc), .number(Date().timeIntervalSince1970 * 1000)])) != nil {
            defaults.set(signature, forKey: Self.targetsSentKey)
        }
    }

    // MARK: Log of shown alerts

    private func reportDelivered(_ read: (String, [JSONValue]) async throws -> JSONValue) async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications().filter { $0.request.identifier.hasPrefix(Self.prefix) }
        var sent = Set(defaults.stringArray(forKey: Self.loggedKey) ?? [])
        let fresh = delivered.filter { !sent.contains($0.request.identifier) }
        guard !fresh.isEmpty else { return }
        let rows: [JSONValue] = fresh.prefix(100).map { note in
            .object(["id": .string(note.request.identifier), "rule": .string(note.request.content.threadIdentifier),
                     "at": .string(ISO8601DateFormatter().string(from: note.date)), "title": .string(note.request.content.title), "body": .string(note.request.content.body)])
        }
        if (try? await read("addAlertLog", [.array(rows)])) != nil {
            sent.formUnion(fresh.map(\.request.identifier))
            defaults.set(Array(sent.suffix(400)), forKey: Self.loggedKey)
        }
    }

    // MARK: Scheduling

    private func schedule(_ doc: Record, store: NativeStore, health: NativeHealthStore) {
        let plan = NativeHubPlan.make(doc: doc, now: Date(), context: NativeHubContext(store: store, health: health))
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            guard !plan.isEmpty else { return }
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            for item in plan {
                let content = UNMutableNotificationContent()
                content.title = item.title; content.body = item.body; content.sound = .default
                content.threadIdentifier = item.rule
                let parts = CivilDate.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                let request = UNNotificationRequest(identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
                try? await center.add(request)
            }
        }
    }
}

/// What the rules can look at, read once when scheduling.
struct NativeHubContext {
    var remaining: Double?
    var daily: Double?
    var daysLeft: Int
    var categorySpend: [String: Double]
    var weekSpend: Double
    var eventsByDay: [String: [String]]
    var shiftByDay: [String: String]
    var intake: [String: Double]
    var goals: [String: Double]

    @MainActor init(store: NativeStore, health: NativeHealthStore) {
        let overview = NativeFinanceOverview(summary: store.summary, month: store.financeMonth)
        remaining = overview.remaining
        daily = overview.remaining == nil ? nil : overview.daily
        daysLeft = overview.days
        var spend: [String: Double] = [:], week = 0.0
        let month = CivilDate.month(), weekStart = CivilDate.adding(-6, to: CivilDate.day())
        for row in store.transactions where row.amount("amount") < 0 && row.text("type") != "Entrata" {
            let date = row.text("date")
            if date.hasPrefix(month) { spend[row.text("displayCategory", fallback: row.text("category")), default: 0] += -row.amount("amount") }
            if date >= weekStart { week += -row.amount("amount") }
        }
        categorySpend = spend; weekSpend = week
        var events: [String: [String]] = [:]
        for event in store.dashboardEvents where event.text("occurrence_status") != "skipped" {
            events[event.text("day"), default: []].append(event.text("title", fallback: "Evento"))
        }
        eventsByDay = events
        var shifts: [String: String] = [:]
        for offset in 0...8 { let day = CivilDate.adding(offset, to: CivilDate.day()); if let kind = store.shift(day) { shifts[day] = kind.title } }
        shiftByDay = shifts
        let values = health.nutrients(on: .now)
        intake = ["kcal": health.calories(on: .now) ?? 0, "protein": values[.dietaryProtein] ?? 0, "fibre": values[.dietaryFiber] ?? 0]
        var goal: [String: Double] = [:]
        if let targets = health.goalTargets { goal["kcal"] = targets.calories; goal["protein"] = targets.protein }
        if let fibre = NativeHub95.shared.fibreGoal { goal["fibre"] = fibre }
        goals = goal
    }
    init(remaining: Double?, daily: Double?, daysLeft: Int, categorySpend: [String: Double], weekSpend: Double, eventsByDay: [String: [String]], shiftByDay: [String: String], intake: [String: Double], goals: [String: Double]) {
        self.remaining = remaining; self.daily = daily; self.daysLeft = daysLeft; self.categorySpend = categorySpend; self.weekSpend = weekSpend
        self.eventsByDay = eventsByDay; self.shiftByDay = shiftByDay; self.intake = intake; self.goals = goals
    }
}

/// Notifications to schedule for the next days from the site's rules (pure, tested).
enum NativeHubPlan {
    struct Item: Equatable { let id: String; let rule: String; let date: Date; let title: String; let body: String }
    static let prayerKeys = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
    static let prayerNames = ["fajr": "Fajr", "sunrise": "Sorgere del sole", "dhuhr": "Dhuhr", "asr": "Asr", "maghrib": "Maghrib", "isha": "Isha"]

    static func make(doc: Record, now: Date, context: NativeHubContext, days: Int = 2) -> [Item] {
        var items: [Item] = []
        let today = CivilDate.day(now)
        let quiet = doc.record("quiet")
        let maxPerDay = max(1, min(20, doc.integer("maxPerDay") == 0 ? 6 : doc.integer("maxPerDay")))
        for offset in 0..<days {
            let day = CivilDate.adding(offset, to: today)
            var count = 0
            for rule in doc.records("rules") where rule["enabled"]?.bool != false {
                let time = rule.text("time", fallback: "09:00")
                guard let date = moment(day, time), date > now, weekdayAllowed(rule, day: day),
                      !inQuiet(time, from: quiet.text("from"), to: quiet.text("to")), count < maxPerDay,
                      let text = content(rule, day: day, context: context) else { continue }
                count += 1
                items.append(Item(id: NativeHub95.prefix + rule.text("id") + "-" + day, rule: rule.text("id"), date: date, title: text.title, body: text.body))
            }
            let prayer = doc.record("prayer")
            if prayer.flag("enabled") {
                let before = Double(max(0, min(60, prayer.integer("before"))))
                let times = SolarTimes.calculate(day)
                for (index, key) in prayerKeys.enumerated() where index < times.count && prayer.record("prayers").flag(key) {
                    guard let base = moment(day, times[index].1) else { continue }
                    let date = base.addingTimeInterval(-before * 60)
                    guard date > now else { continue }
                    let name = prayerNames[key] ?? key
                    items.append(Item(id: NativeHub95.prefix + "prayer-" + key + "-" + day, rule: "prayer", date: date,
                                      title: name, body: before > 0 ? name + " tra " + String(Int(before)) + " minuti, alle " + times[index].1 : "È l'ora di " + name + " (" + times[index].1 + ")"))
                }
            }
        }
        return Array(items.sorted { $0.date < $1.date }.prefix(60))
    }

    static func content(_ rule: Record, day: String, context: NativeHubContext) -> (title: String, body: String)? {
        let params = rule.record("params"), name = rule.text("name", fallback: "Avviso")
        let tomorrow = CivilDate.adding(1, to: day)
        switch rule.text("type") {
        case "budgetBelow":
            guard let remaining = context.remaining, remaining < params.amount("amount") else { return nil }
            return (name, "Ti restano " + remaining.euro + (context.daysLeft > 0 ? " per " + String(context.daysLeft) + " giorni." : "."))
        case "categoryOver":
            let category = params.text("category"), spent = context.categorySpend[category] ?? 0
            guard !category.isEmpty, spent > params.amount("amount") else { return nil }
            return (name, category + ": " + spent.euro + " questo mese, oltre " + params.amount("amount").euro + ".")
        case "dailyBudget":
            guard let daily = context.daily else { return nil }
            return (name, "Oggi puoi spendere " + daily.euro + ".")
        case "nutritionBelow":
            let key = params.text("nutrient", fallback: "protein")
            guard let goal = context.goals[key], goal > 0 else { return nil }
            let value = context.intake[key] ?? 0, percent = params.amount("percent") > 0 ? params.amount("percent") : 70
            guard value < goal * percent / 100 else { return nil }
            let label = ["kcal": "Calorie", "protein": "Proteine", "fibre": "Fibre"][key] ?? key
            let unit = key == "kcal" ? " kcal" : " g"
            return (name, label + ": " + String(Int(value.rounded())) + " / " + String(Int(goal.rounded())) + unit + ".")
        case "eventTomorrow":
            guard let list = context.eventsByDay[tomorrow], !list.isEmpty else { return nil }
            return (name, "Domani: " + list.prefix(3).joined(separator: ", ") + (list.count > 3 ? " e altri." : "."))
        case "shiftTomorrow":
            guard let shift = context.shiftByDay[tomorrow] else { return nil }
            return (name, "Domani: " + shift + ".")
        case "weeklySummary":
            return (name, "Spesi " + context.weekSpend.euro + " negli ultimi 7 giorni.")
        case "custom":
            let title = params.text("title", fallback: name)
            return (title, params.text("body"))
        default:
            return nil
        }
    }
    static func moment(_ day: String, _ time: String) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return CivilDate.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: CivilDate.date(day))
    }
    /// Days 1 = Monday … 7 = Sunday; an empty list means every day.
    static func weekdayAllowed(_ rule: Record, day: String) -> Bool {
        let allowed = (rule["days"]?.array ?? []).map { Int($0.number) }
        guard !allowed.isEmpty else { return true }
        let weekday = CivilDate.calendar.component(.weekday, from: CivilDate.date(day))
        return allowed.contains(weekday == 1 ? 7 : weekday - 1)
    }
    static func inQuiet(_ time: String, from: String, to: String) -> Bool {
        guard !from.isEmpty, !to.isEmpty, from != to else { return false }
        return from < to ? (time >= from && time < to) : (time >= from || time < to)
    }
}
