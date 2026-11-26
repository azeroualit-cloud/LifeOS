import SwiftUI
import Charts

/// PLAN-DETAIL-RICH-2026-11-26 and RENAME-EVERYWHERE-2026-11-26: rename, month by month, fund chart and the
/// movements linked to a plan, inside Dettagli piano.
enum NativePlanHistory {
    struct Month: Identifiable, Equatable {
        let month: String
        let quotaCents: Int
        let paidCents: Int
        let fundCents: Int
        var id: String { month }
    }

    /// From the first month to the current one (or the last month of the plan): the quota of each month,
    /// what was paid in it and the fund left at its end. Estimated from the plan's own schedule.
    static func months(plan: Record, payments: [Record], current: String = CivilDate.month()) -> [Month] {
        let first = plan.text("startMonth")
        guard NativePlanRules.validMonth(first), first <= current else { return [] }
        let end = plan.text("endMonth").isEmpty ? current : min(current, plan.text("endMonth"))
        guard let list = try? NativePlanRules.months(first, max(first, end)) else { return [] }
        let posted = payments.filter { $0.text("status") != "deleted" }
        var fund = 0
        return list.map { month in
            let quota = NativePlanRules.contribution(plan, month: month)
            let paid = posted.filter { $0.text("date").hasPrefix(month) }.reduce(0) { $0 + $1.integer("amountCents") }
            fund = max(0, fund + quota - paid)
            return Month(month: month, quotaCents: quota, paidCents: paid, fundCents: fund)
        }
    }

    /// Next months of the fund if the quotas continue (at most 12, never past the last month).
    static func forecast(plan: Record, from history: [Month], months count: Int = 12) -> [Month] {
        guard let last = history.last, plan.text("status") == "active" else { return [] }
        var fund = last.fundCents, result: [Month] = []
        for step in 1...count {
            let month = NativePlanRules.adding(step, to: last.month)
            if !plan.text("endMonth").isEmpty, month > plan.text("endMonth") { break }
            let quota = NativePlanRules.contribution(plan, month: month)
            fund += quota
            result.append(Month(month: month, quotaCents: quota, paidCents: 0, fundCents: fund))
        }
        return result
    }
}

struct NativePlanRenameSheet: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let planID: String
    let current: String
    @State private var name: String
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(planID: String, current: String) {
        self.planID = planID; self.current = current
        _name = State(initialValue: current)
    }
    private var cleaned: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Nome del piano") {
                TextField("Nome", text: $name).focused($focused).submitLabel(.done)
                    .accessibilityIdentifier("plan-rename-field")
            }
            Section { Text("Il nuovo nome compare nell'app e sul sito. I movimenti già registrati tengono la loro descrizione.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
            if let error { Section { NativeInlineMessage(text: error) } }
        }
        .modifier(NativeListAppearance())
        .navigationTitle("Rinomina piano").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                NativeSheetConfirm(retry: false) { Task { await save() } }
                    .disabled(saving || cleaned.isEmpty || cleaned == current || cleaned.count > 120)
                    .accessibilityIdentifier("plan-rename-save")
            }
        }
        .onAppear { focused = true }
        .interactiveDismissDisabled(saving)
    }

    private func save() async {
        saving = true; defer { saving = false }
        do {
            try await store.perform("renameFinancePlan", [:], args: [.string(planID), .string(cleaned)])
            await store.loadFinancePlans()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

/// Fund at the end of each month, then the dashed forecast; the amount due as a dashed rule.
struct NativePlanFundChart: View {
    let history: [NativePlanHistory.Month]
    let forecast: [NativePlanHistory.Month]
    let dueCents: Int?

    var body: some View {
        let green = NativeDesign.financialGreen
        let date = { (month: String) in CivilDate.date(month + "-01") }
        Chart {
            ForEach(history) { m in
                AreaMark(x: .value("Mese", date(m.month)), y: .value("Fondo", Double(m.fundCents) / 100))
                    .foregroundStyle(LinearGradient(colors: [green.opacity(0.2), green.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Mese", date(m.month)), y: .value("Fondo", Double(m.fundCents) / 100), series: .value("Serie", "Fondo"))
                    .foregroundStyle(green).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            if let last = history.last {
                ForEach([last] + forecast) { m in
                    LineMark(x: .value("Mese", date(m.month)), y: .value("Fondo", Double(m.fundCents) / 100), series: .value("Serie", "Previsione"))
                        .foregroundStyle(green.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
                }
                PointMark(x: .value("Mese", date(last.month)), y: .value("Fondo", Double(last.fundCents) / 100)).foregroundStyle(green).symbolSize(50)
            }
            if let dueCents, dueCents > 0 {
                RuleMark(y: .value("Da coprire", Double(dueCents) / 100))
                    .foregroundStyle(NativeDesign.secondary.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) { Text("da coprire " + (Double(dueCents) / 100).euro).font(.caption2).foregroundStyle(NativeDesign.secondary) }
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(NativeDesign.secondary.opacity(0.25))
                AxisValueLabel { if let euro = value.as(Double.self) { Text(euro.formatted(.number.precision(.fractionLength(0))) + " €") } }
            }
        }
        .chartLegend(.hidden)
        .frame(height: NativeDesign.Layout.healthChartHeight * 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fondo del piano: " + (history.last.map { (Double($0.fundCents) / 100).euro } ?? "—") + (forecast.last.map { ", previsto " + (Double($0.fundCents) / 100).euro + " a " + CivilDate.monthTitle($0.month) } ?? ""))
        .accessibilityIdentifier("plan-fund-chart")
    }
}

/// The movement behind each payment of the plan, opened in its editor (where it can also be renamed).
struct NativePlanLinkedMovements: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    let payments: [Record]
    @State private var rows: [Int: Record] = [:]

    var body: some View {
        let linked = payments.filter { $0.integer("movementId") > 0 }
        Section("Movimenti collegati") {
            if linked.isEmpty { Text("Nessun movimento collegato").foregroundStyle(NativeDesign.secondary) }
            ForEach(Array(linked.enumerated()), id: \.offset) { _, payment in
                let id = payment.integer("movementId"), row = rows[id]
                Button {
                    if let row { router.sheet = .movement(row) }
                } label: {
                    HStack(spacing: NativeDesign.Space.small) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(row?.text("description", fallback: row?.text("name", fallback: "Movimento") ?? "Movimento") ?? "Movimento").font(.subheadline).foregroundStyle(.primary).lineLimit(2)
                            Text(CivilDate.label(payment.text("date")) + (row.map { " · " + $0.text("category") } ?? "")).font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                        Spacer(minLength: NativeDesign.Space.small)
                        Text((Double(payment.integer("amountCents")) / 100).euro).font(.subheadline.weight(.semibold)).monospacedDigit()
                        NativeDisclosureIndicator()
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(row == nil)
                .accessibilityIdentifier("plan-movement-" + String(id))
            }
            if !linked.isEmpty { Text("Tocca un movimento per aprirlo e rinominarlo.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
        }
        .task(id: linked.map { $0.integer("movementId") }) { await load(linked) }
    }

    private func load(_ linked: [Record]) async {
        for payment in linked {
            let id = payment.integer("movementId")
            guard rows[id] == nil else { continue }
            if store.isDemo { rows[id] = store.transactions.first { $0.integer("row") == id } ?? fallback(payment); continue }
            if let row = try? await store.read("getMovement", args: [.int(id)]).object, !row.isEmpty { rows[id] = row } else { rows[id] = fallback(payment) }
        }
    }
    private func fallback(_ payment: Record) -> Record {
        ["row": .int(payment.integer("movementId")), "date": .string(payment.text("date")), "amount": .number(-Double(payment.integer("amountCents")) / 100), "type": .string("Spesa")]
    }
}
