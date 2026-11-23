import SwiftUI
import UserNotifications

/// Avvisi di Finanza (FINANCE-ALERTS-2026-11-21): three alerts with switches and parameters,
/// frequency limits and quiet hours 22-8. Evaluated on the phone from the finance snapshot.
struct NativeFinanceAlertSettings: Codable, Equatable {
    var rhythmOn = true
    var rhythmThreshold = 10        // 5...30 %
    var recurringOn = true
    var recurringPercent = 25       // 10...60 %
    var recurringEuro = 15          // 5...50 €
    var weeklyOn = true
    var weeklyHour = 9              // 6...21
    var frequency = 1               // 0 week, 1 per item a month, 2 a month overall
    static let frequencies = ["1 a settimana", "1 per voce al mese", "1 al mese in tutto"]
    static let quietStart = 22, quietEnd = 8
    var activeCount: Int { [rhythmOn, recurringOn, weeklyOn].filter { $0 }.count }
    var clamped: NativeFinanceAlertSettings {
        var c = self
        c.rhythmThreshold = min(30, max(5, rhythmThreshold)); c.recurringPercent = min(60, max(10, recurringPercent))
        c.recurringEuro = min(50, max(5, recurringEuro)); c.weeklyHour = min(21, max(6, weeklyHour)); c.frequency = min(2, max(0, frequency))
        return c
    }
}

struct NativeFinanceAlertCandidate: Equatable {
    let key: String
    let title: String
    let body: String
}

enum NativeFinanceAlertRules {
    static func candidates(finance: Record, transactions: [Record], settings: NativeFinanceAlertSettings, month: String) -> [NativeFinanceAlertCandidate] {
        var result: [NativeFinanceAlertCandidate] = []
        if settings.rhythmOn {
            let flows = NativeFinanceAnalysis93.flows(finance, before: month)
            if let pace = NativeFinanceAnalysis93.pace(flows, months: 3), pace * 100 > Double(settings.rhythmThreshold) {
                let percent = Int((pace * 100).rounded())
                let remaining = finance.record("summary").amount("monthlyRemaining")
                result.append(.init(key: "rhythm", title: "Ritmo sopra la norma",
                                    body: "Negli ultimi 3 mesi stai spendendo il " + String(percent) + "% sopra la tua norma. Budget rimanente " + remaining.euro + "."))
            }
        }
        if settings.recurringOn {
            for row in finance.records("recurring") {
                let name = row.text("name"), norm = row.amount("estimate")
                guard !name.isEmpty, norm > 0 else { continue }
                let actual = transactions.filter {
                    $0.text("date").hasPrefix(month) && $0.amount("amount") < 0 &&
                    ($0.text("category") == name || $0.text("displayCategory") == name)
                }.reduce(0) { $0 - $1.amount("amount") }
                let over = actual - norm
                if actual > norm * (1 + Double(settings.recurringPercent) / 100), over >= Double(settings.recurringEuro) {
                    let percent = Int((over / norm * 100).rounded())
                    result.append(.init(key: "recurring-" + name, title: name,
                                        body: actual.euro + ", il " + String(percent) + "% sopra la norma (" + norm.euro + ")."))
                }
            }
        }
        return result
    }

    /// Weekly summary text from the last seven days of movements.
    static func weekly(transactions: [Record], today: String) -> String {
        let start = CivilDate.adding(-7, to: today)
        let rows = transactions.filter { $0.text("date") > start && $0.text("date") <= today && $0.amount("amount") < 0 && $0.text("type") != "Entrata" }
        let total = rows.reduce(0) { $0 - $1.amount("amount") }
        var byCategory: [String: Double] = [:]
        for row in rows { byCategory[row.text("displayCategory", fallback: row.text("category", fallback: "Altro")), default: 0] -= row.amount("amount") }
        var text = "Spesi " + total.euro + " negli ultimi 7 giorni."
        if let top = byCategory.max(by: { $0.value < $1.value }) { text += " " + top.key + " la voce più alta (" + top.value.euro + ")." }
        return text
    }

    /// Frequency limits: one a week overall, one per item a month, or one a month overall.
    static func allowed(_ key: String, now: Date, log: [String: Date], frequency: Int) -> Bool {
        let calendar = CivilDate.calendar
        switch frequency {
        case 0:
            guard let last = log.values.max() else { return true }
            return now.timeIntervalSince(last) >= 7 * 24 * 3600
        case 2:
            guard let last = log.values.max() else { return true }
            return !calendar.isDate(last, equalTo: now, toGranularity: .month)
        default:
            guard let last = log[key] else { return true }
            return !calendar.isDate(last, equalTo: now, toGranularity: .month)
        }
    }

    /// Delivery time outside the quiet hours (22-8): quiet times move to 8:00.
    static func delivery(after now: Date) -> Date {
        let calendar = CivilDate.calendar
        let hour = calendar.component(.hour, from: now)
        guard hour >= NativeFinanceAlertSettings.quietStart || hour < NativeFinanceAlertSettings.quietEnd else { return now.addingTimeInterval(5) }
        let base = hour >= NativeFinanceAlertSettings.quietStart ? calendar.date(byAdding: .day, value: 1, to: now) ?? now : now
        return calendar.date(bySettingHour: NativeFinanceAlertSettings.quietEnd, minute: 0, second: 0, of: base) ?? now
    }
}

@MainActor final class NativeFinanceAlerts: ObservableObject {
    static let shared = NativeFinanceAlerts()
    private static let settingsKey = "native-finance-alerts-93", logKey = "native-finance-alerts-log-93"
    private let defaults = UserDefaults.standard
    @Published var settings: NativeFinanceAlertSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
            // ALERTS-CLARITY-2026-11-24: the site shows and edits these too (newest copy wins).
            if !applyingRemote { defaults.set(Date().timeIntervalSince1970 * 1000, forKey: Self.modifiedKey) }
        }
    }
    static let modifiedKey = "native-finance-alerts-modified-95"
    private var applyingRemote = false
    var modified: Double { defaults.double(forKey: Self.modifiedKey) }
    /// Settings that came from the site.
    func applyRemote(_ value: NativeFinanceAlertSettings, modified: Double) {
        applyingRemote = true; settings = value.clamped; applyingRemote = false
        defaults.set(modified, forKey: Self.modifiedKey)
    }
    @Published private(set) var recent: [NativeFinanceAlertCandidate] = []
    private init() {
        settings = (defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(NativeFinanceAlertSettings.self, from: $0) } ?? NativeFinanceAlertSettings()).clamped
    }
    private var log: [String: Date] {
        get { (defaults.dictionary(forKey: Self.logKey) as? [String: Date]) ?? [:] }
        set { defaults.set(newValue, forKey: Self.logKey) }
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Re-evaluates after every finance refresh. Demo data never notifies.
    func update(finance: Record, transactions: [Record], month: String, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard enabled, status == .authorized || status == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: ["financealert-weekly"]); return
        }
        let settings = self.settings, now = Date()
        // Weekly summary: repeating Monday trigger, text refreshed at every update.
        if settings.weeklyOn {
            let content = UNMutableNotificationContent()
            content.title = "La tua settimana"
            content.body = NativeFinanceAlertRules.weekly(transactions: transactions, today: CivilDate.day())
            content.sound = .default
            content.userInfo = ["route": "dashboard"]
            var components = DateComponents(); components.weekday = 2; components.hour = settings.weeklyHour; components.minute = 0
            try? await center.add(UNNotificationRequest(identifier: "financealert-weekly", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["financealert-weekly"])
        }
        guard month == CivilDate.month() else { return }
        var log = self.log
        for candidate in NativeFinanceAlertRules.candidates(finance: finance, transactions: transactions, settings: settings, month: month)
        where NativeFinanceAlertRules.allowed(candidate.key, now: now, log: log, frequency: settings.frequency) {
            let content = UNMutableNotificationContent()
            content.title = candidate.title; content.body = candidate.body; content.sound = .default
            content.userInfo = ["route": "dashboard"]
            let at = NativeFinanceAlertRules.delivery(after: now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, at.timeIntervalSince(now)), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: "financealert-" + candidate.key, content: content, trigger: trigger))
                log[candidate.key] = now
                recent.insert(candidate, at: 0); recent = Array(recent.prefix(3))
            } catch {}
        }
        self.log = log
    }
}

/// Avvisi screen (preview "Avvisi di Finanza"): rules with switch and parameters, limits.
struct NativeFinanceAlertsScreen: View {
    @ObservedObject private var alerts = NativeFinanceAlerts.shared
    @State private var open: Int?
    /// A sample notification (example text, not the user's data).
    private func example(_ title: String, when: String, body: String) -> some View {
        HStack(alignment: .top, spacing: NativeDesign.Space.medium) {
            Image(systemName: "chart.bar.fill").font(.subheadline).foregroundStyle(NativeDesign.financeTitle)
                .frame(width: NativeDesign.Layout.iconTile, height: NativeDesign.Layout.iconTile)
                .loTileSurface()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: NativeDesign.Space.small)
                    Text(when).font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
                Text(body).font(.footnote).foregroundStyle(NativeDesign.secondary)
            }
        }
        .padding(.horizontal, NativeDesign.Layout.cardInset).padding(.vertical, NativeDesign.Layout.cardInsetVertical)
        .loCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Esempio di avviso: " + title + ", " + body)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                if !alerts.recent.isEmpty {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                        LOSectionLabel(title: "Ultimi avvisi")
                        LOListCard {
                            ForEach(Array(alerts.recent.enumerated()), id: \.offset) { index, item in
                                LOListRow(isLast: index == alerts.recent.count - 1) {
                                    VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                        Text(item.title).font(.subheadline.weight(.semibold))
                                        Text(item.body).font(.footnote).foregroundStyle(NativeDesign.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }
                // Preview 93: how an alert looks on the lock screen before choosing the rules.
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    LOSectionLabel(title: "Come arrivano")
                    example("Ritmo sopra la norma", when: "adesso", body: "Negli ultimi 3 mesi spendi il 12% sopra la tua norma.")
                    example("La tua settimana", when: "lunedì " + String(alerts.settings.weeklyHour) + ":00", body: "Spesi 186 € negli ultimi 7 giorni. Spesa la voce più alta.")
                }
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    LOSectionLabel(title: "Quando scattano")
                    LOListCard {
                        rule(0, "Ritmo sopra la norma", "media 3 mesi oltre il " + String(alerts.settings.rhythmThreshold) + "% della norma", isOn: $alerts.settings.rhythmOn) {
                            stepper("Soglia", String(alerts.settings.rhythmThreshold) + "%", value: $alerts.settings.rhythmThreshold, range: 5...30, step: 5, id: "alerts-rhythm")
                        }
                        rule(1, "Spese ricorrenti fuori norma", "bollette e abbonamenti oltre +" + String(alerts.settings.recurringPercent) + "% e +" + String(alerts.settings.recurringEuro) + " €", isOn: $alerts.settings.recurringOn) {
                            stepper("Oltre la norma", "+" + String(alerts.settings.recurringPercent) + "%", value: $alerts.settings.recurringPercent, range: 10...60, step: 5, id: "alerts-recurring-percent")
                            stepper("E almeno", String(alerts.settings.recurringEuro) + " €", value: $alerts.settings.recurringEuro, range: 5...50, step: 5, id: "alerts-recurring-euro")
                        }
                        rule(2, "Riepilogo del lunedì", "una notifica alle " + String(alerts.settings.weeklyHour) + ":00", isOn: $alerts.settings.weeklyOn, last: true) {
                            stepper("Ora", String(alerts.settings.weeklyHour) + ":00", value: $alerts.settings.weeklyHour, range: 6...21, step: 1, id: "alerts-weekly-hour")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    LOSectionLabel(title: "Limiti")
                    LOListCard {
                        LOListRow {
                            LOStepperRow(title: "Al massimo", value: NativeFinanceAlertSettings.frequencies[alerts.settings.frequency],
                                         decrement: alerts.settings.frequency > 0 ? { alerts.settings.frequency -= 1 } : nil,
                                         increment: alerts.settings.frequency < 2 ? { alerts.settings.frequency += 1 } : nil,
                                         identifier: "alerts-frequency")
                        }
                        LOListRow(isLast: true) {
                            Text("Silenzio")
                            Spacer()
                            Text("22:00 - 8:00").foregroundStyle(NativeDesign.secondary).monospacedDigit()
                        }
                    }
                }
                // ALERTS-CLARITY-2026-11-24: say plainly how they arrive and where else they are managed.
                Text("Notifiche su questo iPhone, con suono; nessuna sveglia. Le vedi e modifichi anche dal sito, in Avvisi, insieme agli avvisi personali e alla preghiera.")
                    .font(.footnote).foregroundStyle(NativeDesign.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("alerts-delivery-note")
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.medium)
        }
        .background(NativeDesign.canvas)
        .navigationTitle("Avvisi").navigationBarTitleDisplayMode(.large)
        .task { if alerts.settings.activeCount > 0 { await alerts.requestPermission() } }
    }
    private func rule<Params: View>(_ index: Int, _ title: String, _ subtitle: String, isOn: Binding<Bool>, last: Bool = false, @ViewBuilder params: () -> Params) -> some View {
        let expanded = open == index
        return VStack(alignment: .leading, spacing: NativeDesign.Space.none) {
            LOListRow(isLast: last && !expanded) {
                Button { open = expanded ? nil : index } label: {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                        Text(title).font(.subheadline).foregroundStyle(Color.primary)
                        Text(subtitle).font(.footnote).foregroundStyle(NativeDesign.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(expanded ? "Aperto" : "Chiuso")
                .accessibilityIdentifier("alerts-rule-" + String(index))
                Toggle(title, isOn: isOn).labelsHidden().accessibilityIdentifier("alerts-switch-" + String(index))
            }
            if expanded {
                VStack(spacing: NativeDesign.Space.xs) { params() }
                    .padding(.horizontal, NativeDesign.Space.large)
                    .padding(.bottom, NativeDesign.Space.medium)
            }
        }
    }
    private func stepper(_ title: String, _ value: String, value binding: Binding<Int>, range: ClosedRange<Int>, step: Int, id: String) -> some View {
        LOStepperRow(title: title, value: value,
                     decrement: binding.wrappedValue > range.lowerBound ? { binding.wrappedValue = max(range.lowerBound, binding.wrappedValue - step) } : nil,
                     increment: binding.wrappedValue < range.upperBound ? { binding.wrappedValue = min(range.upperBound, binding.wrappedValue + step) } : nil,
                     identifier: id)
    }
}
