import SwiftUI
import Charts
import LocalAuthentication

// MARK: - LIFE-STATS-2026-11-25
// «Statistiche»: shifts, spending, calories and the private log of the same days, side by side.
// The numbers show how things go together on the same days; they never claim a cause.

enum NativeLifeStats {
    /// «1 incontro», «3 incontri» (INCONTRI-NAME: singular and plural where needed).
    static func count(_ n: Int, _ one: String, _ many: String) -> String { String(n) + " " + (n == 1 ? one : many) }
    static let kinds = ["morning", "afternoon", "night", "rest", "holiday", "none"]

    static func title(_ kind: String) -> String { kind == "none" ? "Senza turno" : ShiftKind(rawValue: kind)?.title ?? kind }
    static func color(_ kind: String) -> Color { kind == "none" ? NativeDesign.secondary : (ShiftKind(rawValue: kind)?.color ?? NativeDesign.secondary) }

    struct Group: Identifiable, Equatable {
        let kind: String
        let days: Int
        let privateCount: Int
        /// Average spending per day of this kind (days without spending count as zero).
        let spend: Double
        /// Average kcal on the days with a diary; nil when no such day.
        let kcal: Double?
        var id: String { kind }
        var privateRate: Double { days > 0 ? Double(privateCount) / Double(days) : 0 }
    }

    struct Month: Identifiable, Equatable {
        let month: String
        let kind: String
        let count: Int
        var id: String { month + kind }
    }

    /// The days of the period, up to today.
    static func days(months: [String], today: String = CivilDate.day()) -> [String] {
        months.flatMap { month in (0..<31).map { CivilDate.adding($0, to: month + "-01") }.filter { $0.hasPrefix(month) && $0 <= today } }
    }

    static func groups(days: [String], shifts: [String: String], privateDays: [String: Int], spend: [String: Double], kcal: [String: Double]) -> [Group] {
        let byKind = Dictionary(grouping: days) { day -> String in
            let kind = shifts[day] ?? "none"
            return kinds.contains(kind) ? kind : "none"
        }
        return kinds.compactMap { kind in
            guard let list = byKind[kind], !list.isEmpty else { return nil }
            let logged = list.compactMap { kcal[$0] }.filter { $0 > 0 }
            return Group(kind: kind, days: list.count, privateCount: list.reduce(0) { $0 + (privateDays[$1] ?? 0) },
                         spend: list.reduce(0) { $0 + (spend[$1] ?? 0) } / Double(list.count),
                         kcal: logged.isEmpty ? nil : logged.reduce(0, +) / Double(logged.count))
        }
    }

    static func months(_ months: [String], shifts: [String: String]) -> [Month] {
        months.flatMap { month in
            ["morning", "afternoon", "night"].map { kind in
                Month(month: month, kind: kind, count: shifts.filter { $0.key.hasPrefix(month) && $0.value == kind }.count)
            }
        }
    }

    /// Short sentences on the clearest differences between kinds of day (at least 4 days per kind).
    static func insights(_ groups: [Group], includePrivate: Bool, hideMoney: Bool) -> [String] {
        let solid = groups.filter { $0.days >= 4 }
        let total = groups.reduce(0) { $0 + $1.days }
        guard total > 0, !solid.isEmpty else { return [] }
        var out: [String] = []
        let spendAverage = groups.reduce(0) { $0 + $1.spend * Double($1.days) } / Double(total)
        if spendAverage > 0, let top = solid.max(by: { $0.spend < $1.spend }), top.spend >= spendAverage * 1.2 {
            out.append("Nei giorni di " + title(top.kind) + " spendi di più: " + (hideMoney ? "••••" : top.spend.euro) + " al giorno contro " + (hideMoney ? "••••" : spendAverage.euro) + " di media.")
        }
        let withKcal = solid.compactMap { g in g.kcal.map { (g, $0) } }
        if withKcal.count >= 2, let top = withKcal.max(by: { $0.1 < $1.1 }), let low = withKcal.min(by: { $0.1 < $1.1 }), top.1 >= low.1 * 1.1 {
            out.append("Mangi di più nei giorni di " + title(top.0.kind) + " (" + String(Int(top.1.rounded())) + " kcal) che in quelli di " + title(low.0.kind) + " (" + String(Int(low.1.rounded())) + " kcal).")
        }
        if includePrivate {
            let count = groups.reduce(0) { $0 + $1.privateCount }
            let rate = Double(count) / Double(total)
            if count >= 3, let top = solid.max(by: { $0.privateRate < $1.privateRate }), top.privateRate >= rate * 1.3 {
                out.append("Incontri: più spesso nei giorni di " + title(top.kind) + " (" + per10(top.privateRate) + " ogni 10 giorni, in media " + per10(rate) + ").")
            }
        }
        return out
    }

    static func per10(_ rate: Double) -> String { String(format: "%.1f", rate * 10).replacingOccurrences(of: ".", with: ",") }
    static func shortMonth(_ month: String) -> String {
        let names = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
        return names[max(0, min(11, (Int(month.suffix(2)) ?? 1) - 1))]
    }

    /// Demo only: a regular rota with typical numbers, so the screen can be checked without real data.
    static func demo(days: [String]) -> (shifts: [String: String], spend: [String: Double], kcal: [String: Double]) {
        let rota = ["morning", "morning", "afternoon", "afternoon", "night", "night", "rest", "rest"]
        var shifts: [String: String] = [:], spend: [String: Double] = [:], kcal: [String: Double] = [:]
        for (index, day) in days.enumerated() {
            let kind = rota[index % rota.count]
            shifts[day] = kind
            let wobble = Double((index * 7) % 5)
            spend[day] = (kind == "rest" ? 26 : kind == "night" ? 17 : 12) + wobble * 2
            kcal[day] = (kind == "night" ? 2450 : kind == "rest" ? 2050 : 2200) + wobble * 30
        }
        return (shifts, spend, kcal)
    }
}

struct NativeLifeStatsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NativeStore
    @AppStorage("lifeos-stats-months") private var range = 3
    @AppStorage("native-hide-money") private var hideMoney = false
    @State private var shifts: [String: String] = [:]
    @State private var spend: [String: Double] = [:]
    @State private var kcal: [String: Double] = [:]
    @State private var privateEntries: [Record] = []
    @State private var loading = false
    @State private var unlocked = false

    private var months: [String] { (0..<range).reversed().map { String(CivilDate.adding(-$0, to: CivilDate.month() + "-01", component: .month).prefix(7)) } }

    var body: some View {
        let days = NativeLifeStats.days(months: months)
        let privateDays = Dictionary(grouping: privateEntries.map { $0.text("day") }.filter { days.contains($0) }, by: { $0 }).mapValues(\.count)
        let groups = NativeLifeStats.groups(days: days, shifts: shifts, privateDays: privateDays, spend: spend, kcal: kcal)
        VStack(spacing: NativeDesign.Space.none) {
            HStack(spacing: NativeDesign.Space.small) {
                NativeToolbarButton(symbol: "chevron.left", label: "Indietro") { dismiss() }.accessibilityIdentifier("stats-back")
                Text("Statistiche").font(.title.bold()).lineLimit(1).accessibilityAddTraits(.isHeader)
                Spacer(minLength: NativeDesign.Space.small)
                if loading { ProgressView() }
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                    Picker("Periodo", selection: $range) {
                        Text("3 mesi").tag(3); Text("6 mesi").tag(6); Text("12 mesi").tag(12)
                    }
                    .pickerStyle(.segmented).accessibilityIdentifier("stats-range")
                    summary(groups)
                    shiftsCard(groups)
                    byKindCard(groups)
                    privateCard(groups, privateDays: privateDays)
                    Text("Le statistiche mettono vicini dati dello stesso giorno: mostrano cosa va insieme, non il perché. Calorie solo dei giorni con il diario.")
                        .font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
                .padding(.horizontal, NativeDesign.Layout.screenInset)
                .padding(.vertical, NativeDesign.Space.medium)
            }
        }
        .background(NativeDesign.canvas)
        .task(id: String(range) + (store.isDemo ? "|demo" : "|real")) { await load() }
        .accessibilityIdentifier("stats-screen")
    }

    // MARK: Cards

    private func card<Content: View>(_ title: String, _ detail: String, id: String, @ViewBuilder content: () -> Content) -> some View {
        NativeCard {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                }
                content()
            }
        }
        .accessibilityIdentifier(id)
    }

    private func summary(_ groups: [NativeLifeStats.Group]) -> some View {
        let lines = NativeLifeStats.insights(groups, includePrivate: unlocked, hideMoney: hideMoney)
        return card("In breve", "Le differenze più nette tra i tipi di giornata.", id: "stats-summary") {
            if lines.isEmpty {
                Text(loading ? "Sto leggendo i dati…" : "Ancora troppi pochi giorni per vedere differenze.").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                    Circle().fill(NativeDesign.calendarTitle).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                    Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func shiftsCard(_ groups: [NativeLifeStats.Group]) -> some View {
        let rows = NativeLifeStats.months(months, shifts: shifts)
        let worked = rows.reduce(0) { $0 + $1.count }
        let kinds = ["morning", "afternoon", "night"]
        return card("Turni", String(worked) + " turni lavorati in " + String(range) + " mesi", id: "stats-shifts") {
            Chart(rows) { row in
                BarMark(x: .value("Mese", NativeLifeStats.shortMonth(row.month)), y: .value("Turni", row.count))
                    .foregroundStyle(by: .value("Turno", NativeLifeStats.title(row.kind)))
            }
            .chartForegroundStyleScale(domain: kinds.map(NativeLifeStats.title), range: kinds.map(NativeLifeStats.color))
            .chartLegend(position: .bottom, spacing: NativeDesign.Space.small)
            .frame(height: NativeDesign.Layout.categoryWidth * 1.6)
            HStack(spacing: NativeDesign.Space.small) {
                ForEach(groups.filter { ["rest", "holiday"].contains($0.kind) }) { group in
                    Text(NativeLifeStats.title(group.kind) + " " + String(group.days)).font(.footnote).foregroundStyle(NativeLifeStats.color(group.kind))
                }
            }
        }
    }

    private func byKindCard(_ groups: [NativeLifeStats.Group]) -> some View {
        let topSpend = max(groups.map(\.spend).max() ?? 1, 1)
        let topKcal = max(groups.compactMap(\.kcal).max() ?? 1, 1)
        return card("Per tipo di giornata", "Media al giorno: spese e calorie.", id: "stats-by-kind") {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    HStack(spacing: NativeDesign.Space.small) {
                        Capsule().fill(NativeLifeStats.color(group.kind)).frame(width: NativeDesign.Space.xs, height: NativeDesign.Space.large)
                        Text(NativeLifeStats.title(group.kind)).font(.subheadline.weight(.semibold))
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(NativeLifeStats.count(group.days, "giorno", "giorni")).font(.footnote).foregroundStyle(NativeDesign.secondary)
                    }
                    bar(label: hideMoney ? "••••" : group.spend.euro, fraction: group.spend / topSpend, color: NativeDesign.financeTitle)
                    bar(label: group.kcal.map { String(Int($0.rounded())) + " kcal" } ?? "— kcal", fraction: (group.kcal ?? 0) / topKcal, color: NativeDesign.nutritionTitle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("stats-kind-" + group.kind)
            }
        }
    }

    private func bar(label: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: NativeDesign.Space.small) {
            ProgressView(value: min(max(fraction, 0), 1)).tint(color)
            Text(label).font(.footnote).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                .frame(width: NativeDesign.Layout.categoryWidth, alignment: .trailing)
        }
    }

    private func privateCard(_ groups: [NativeLifeStats.Group], privateDays: [String: Int]) -> some View {
        card("Incontri", unlocked ? "Incontri del periodo." : "Nascosto finché non lo apri con Face ID o codice.", id: "stats-private") {
            if unlocked {
                let inPeriod = privateEntries.filter { privateDays[$0.text("day")] != nil }
                let perMonth = months.map { month in (month, inPeriod.filter { $0.text("day").hasPrefix(month) }.count) }
                let people = Dictionary(grouping: inPeriod, by: { $0.text("person", fallback: "—") }).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
                Chart(perMonth, id: \.0) { item in
                    BarMark(x: .value("Mese", NativeLifeStats.shortMonth(item.0)), y: .value("Volte", item.1)).foregroundStyle(NativeDesign.secondary)
                }
                .frame(height: NativeDesign.Layout.categoryWidth * 1.2)
                Text(NativeLifeStats.count(inPeriod.count, "incontro", "incontri") + " in " + String(range) + " mesi · " + String(privateEntries.count) + " in tutto").font(.subheadline.weight(.semibold))
                ForEach(people, id: \.0) { person in
                    LabeledContent(person.0, value: String(person.1)).font(.subheadline)
                }
                Text("Ogni 10 giorni, per tipo di giornata").font(.footnote).foregroundStyle(NativeDesign.secondary)
                ForEach(groups) { group in
                    bar(label: NativeLifeStats.title(group.kind) + " " + NativeLifeStats.per10(group.privateRate),
                        fraction: group.privateRate / max(groups.map(\.privateRate).max() ?? 1, 0.01), color: NativeLifeStats.color(group.kind))
                }
            } else {
                Button("Mostra") { unlock() }.font(.subheadline.weight(.semibold)).accessibilityIdentifier("stats-private-unlock")
            }
        }
    }

    // MARK: Data

    private func load() async {
        loading = true
        defer { loading = false }
        let period = months, days = NativeLifeStats.days(months: period)
        privateEntries = await NativePrivateLog.load(store)
        if store.isDemo {
            let demo = NativeLifeStats.demo(days: days)
            shifts = demo.shifts; spend = demo.spend; kcal = demo.kcal
            return
        }
        var nextShifts: [String: String] = [:], nextSpend: [String: Double] = [:]
        for month in period {
            if let life = try? await store.read("getLifeData", args: [.string(month)]).object {
                for row in life.records("shifts") where row.text("day").hasPrefix(month) { nextShifts[row.text("day")] = row.text("kind") }
            }
            if let finance = try? await store.read("getFinanceData", args: [.int(Int(month.prefix(4)) ?? 2026), .int(Int(month.suffix(2)) ?? 1)]).object {
                for (day, value) in NativeFinanceAnalysis93.daily(finance.records("transactions"), month: month) {
                    nextSpend[month + "-" + (day < 10 ? "0" : "") + String(day)] = value
                }
            }
            if Task.isCancelled { return }
        }
        var nextKcal: [String: Double] = [:]
        for entry in NativeNutritionUIFixture.current.entries where entry.confirmed && entry.deletionPending != true {
            nextKcal[CivilDate.day(entry.date), default: 0] += NSDecimalNumber(decimal: entry.calories).doubleValue
        }
        shifts = nextShifts; spend = nextSpend; kcal = nextKcal
    }

    private func unlock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { unlocked = true; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Mostra le statistiche private") { ok, _ in
            Task { @MainActor in unlocked = ok }
        }
    }
}
