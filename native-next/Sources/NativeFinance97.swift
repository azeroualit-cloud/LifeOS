import SwiftUI

/// PLANS-SCREEN-97: «Piani» shows every active plan as a map of rectangles sized by the amount (quota of the month or
/// money set aside), coloured by kind; a tap opens the plan, «+» adds one, the rows are one tap away under the map.
enum NativePlansMap {
    struct Tile: Identifiable, Equatable {
        let id: String
        let name: String
        let value: Double
        let group: Int
    }
    static let groupTitles = ["Fondi", "Utenze stimate", "Rate e anticipi"]

    static func group(kind: String) -> Int {
        switch kind {
        case "estimated": 1
        case "recovery", "advance": 2
        default: 0
        }
    }
    /// Active plans with a positive value for the chosen measure, largest first.
    static func tiles(_ plans: [Record], setAside: Bool) -> [Tile] {
        plans.filter { $0.text("status") == "active" }.compactMap { plan -> Tile? in
            let cents = setAside ? plan.integer("fundCents") : abs(plan.integer("contributionCents"))
            guard cents > 0 else { return nil }
            return Tile(id: plan.text("id"), name: plan.text("name", fallback: "Piano"), value: Double(cents) / 100, group: group(kind: plan.text("kind")))
        }.sorted { $0.value == $1.value ? $0.name < $1.name : $0.value > $1.value }
    }
    static func color(_ group: Int) -> Color {
        [NativeDesign.financeGroups[0], NativeDesign.estimate, NativeDesign.healthWeight][min(max(group, 0), 2)]
    }
}

struct NativePlansMapScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @AppStorage("native-hide-money") private var hidden = false
    @State private var measure = "Al mese"
    @State private var opened: String?
    @State private var showingList = false

    private var plans: [Record] { store.finance.record("plansV2").records("plans") }

    var body: some View {
        let tiles = NativePlansMap.tiles(plans, setAside: measure == "Da parte")
        let total = tiles.reduce(0) { $0 + $1.value }
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                LOSegmented(options: [("Al mese", "month"), ("Da parte", "fund")], selection: $measure, identifierPrefix: "plans-measure-")
                if tiles.isEmpty {
                    Text("Nessun piano attivo. Con + ne crei uno.").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                } else {
                    NativeCard {
                        HStack {
                            Text(measure == "Al mese" ? CivilDate.monthTitle(store.financeMonth) : "Da parte").font(.headline)
                            Spacer(minLength: NativeDesign.Space.small)
                            Text(hidden ? "••••" : total.euro + (measure == "Al mese" ? " al mese" : "")).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                        }
                        GeometryReader { proxy in
                            let rects = NativeSalaryMap.squarify(NativeSalaryMap.floored(tiles.map(\.value), minShare: 0.06), in: CGRect(origin: .zero, size: proxy.size))
                            ZStack(alignment: .topLeading) {
                                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                                    tileView(tile, rect: rects[index], total: total)
                                }
                            }
                        }
                        .frame(height: NativeDesign.Layout.healthChartHeight * 1.3)
                        legend(tiles)
                    }
                    DisclosureGroup(isExpanded: $showingList) {
                        ForEach(tiles) { tile in
                            Button { opened = tile.id } label: {
                                HStack {
                                    Circle().fill(NativePlansMap.color(tile.group)).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                                    Text(tile.name).font(.subheadline).foregroundStyle(.primary)
                                    Spacer(minLength: NativeDesign.Space.small)
                                    Text(hidden ? "••••" : tile.value.euro).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                                }.frame(minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    } label: { Text("Elenco · " + String(tiles.count)).font(.subheadline.weight(.semibold)) }
                    .accessibilityIdentifier("plans-list")
                }
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
        }
        .background(NativeDesign.canvas)
        .accessibilityIdentifier("plans-map-scroll")
        .navigationTitle("Piani").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { router.sheet = .financePlan } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuovo piano").accessibilityIdentifier("plans-map-add")
            }
        }
        .navigationDestination(item: $opened) { id in NativePlanDetail(planID: id) }
        .task { await store.loadFinancePlans() }
    }

    private func tileView(_ tile: NativePlansMap.Tile, rect: CGRect, total: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: NativeDesign.badgeRadius, style: .continuous)
        let big = rect.height > 52 && rect.width > 70
        return Button { opened = tile.id } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(tile.name).font(.footnote.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.75)
                if !hidden && big { Text(tile.value.euro).font(.caption2).monospacedDigit() }
            }
            .foregroundStyle(.white)
            .padding(NativeDesign.Space.small)
            .frame(width: max(0, rect.width - 2), height: max(0, rect.height - 2), alignment: .topLeading)
            .background(NativePlansMap.color(tile.group), in: shape)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .offset(x: rect.minX + 1, y: rect.minY + 1)
        .accessibilityLabel(tile.name + (hidden ? "" : ": " + tile.value.euro) + ", " + NativePlansMap.groupTitles[tile.group])
        .accessibilityIdentifier("plans-tile-" + tile.id)
    }

    private func legend(_ tiles: [NativePlansMap.Tile]) -> some View {
        HStack(spacing: NativeDesign.Space.medium) {
            ForEach(0..<3, id: \.self) { group in
                let sum = tiles.filter { $0.group == group }.reduce(0) { $0 + $1.value }
                if sum > 0 {
                    HStack(spacing: NativeDesign.Space.xs) {
                        Circle().fill(NativePlansMap.color(group)).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                        Text(NativePlansMap.groupTitles[group] + (hidden ? "" : " " + sum.euro)).font(.caption2).foregroundStyle(NativeDesign.secondary).monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// BUDGET-MAP-97: the month's budget as a map in three parts (instalments, plans, the month's expenses not covered
/// by a plan) plus what is still free; the final budget right under it.
struct NativeBudgetMapCard: View {
    let flow: NativeBudgetFlow
    let month: String
    let plans: [Record]
    let categories: [Record]
    let hidden: Bool
    private struct Part: Identifiable { let id: String; let name: String; let value: Double; let color: Color }

    var body: some View {
        let instalments = flow.rows.filter { NativeInstalments.isInstalment($0, plans: plans) }
        let planRows = flow.rows.filter { !NativeInstalments.isInstalment($0, plans: plans) }
        var parts: [Part] = []
        for row in instalments where row.amountCents > 0 { parts.append(Part(id: "rate-" + String(row.id), name: row.name, value: Double(row.amountCents) / 100, color: NativeDesign.healthWeight)) }
        for row in planRows where row.amountCents > 0 { parts.append(Part(id: "plan-" + String(row.id), name: row.name, value: Double(row.amountCents) / 100, color: NativeDesign.financeGroups[0])) }
        let spent = categories.map { ($0.text("name", fallback: "Altro"), $0.amount("amount")) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        let spentTotal = Double(flow.spentCents) / 100, listed = spent.reduce(0) { $0 + $1.1 }
        let scale = listed > 0 && spentTotal > 0 ? min(1, spentTotal / listed) : 1
        for (name, value) in spent.prefix(6) { parts.append(Part(id: "spent-" + name, name: name, value: value * scale, color: NativeDesign.financialRed)) }
        let rest = spent.dropFirst(6).reduce(0) { $0 + $1.1 } * scale
        if rest > 0 { parts.append(Part(id: "spent-altro", name: "Altre spese", value: rest, color: NativeDesign.financialRed.opacity(0.75))) }
        if flow.remainingCents > 0 { parts.append(Part(id: "free", name: "Libero", value: Double(flow.remainingCents) / 100, color: NativeDesign.financialGreen)) }
        let total = parts.reduce(0) { $0 + $1.value }
        return NativeCard {
            HStack {
                Text("Budget di " + CivilDate.monthTitle(month)).font(.headline)
                Spacer(minLength: NativeDesign.Space.small)
                Text(hidden ? "••••" : "stipendio " + (Double(flow.salaryCents) / 100).euro).font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit()
            }
            if total > 0 {
                GeometryReader { proxy in
                    let rects = NativeSalaryMap.squarify(NativeSalaryMap.floored(parts.map(\.value), minShare: 0.05), in: CGRect(origin: .zero, size: proxy.size))
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
                            let rect = rects[index]
                            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                Text(part.name).font(.caption2.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.7)
                                if !hidden && rect.height > 40 && rect.width > 56 { Text(part.value.euro).font(.caption2).monospacedDigit() }
                            }
                            .foregroundStyle(.white)
                            .padding(NativeDesign.Space.xs)
                            .frame(width: max(0, rect.width - 2), height: max(0, rect.height - 2), alignment: .topLeading)
                            .background { RoundedRectangle(cornerRadius: NativeDesign.badgeRadius, style: .continuous).fill(part.color) }
                            .offset(x: rect.minX + 1, y: rect.minY + 1)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(part.name + (hidden ? "" : ": " + part.value.euro))
                        }
                    }
                }
                .frame(height: NativeDesign.Layout.healthChartHeight * 1.2)
                .accessibilityIdentifier("budget-map")
            }
            HStack(spacing: NativeDesign.Space.medium) {
                legend("Rate", instalments.reduce(0) { $0 + $1.amountCents }, NativeDesign.healthWeight)
                legend("Piani", planRows.reduce(0) { $0 + $1.amountCents }, NativeDesign.financeGroups[0])
                legend("Spese del mese", flow.spentCents, NativeDesign.financialRed)
            }
            HStack {
                Text("Budget finale").font(.headline)
                Spacer(minLength: NativeDesign.Space.small)
                Text(hidden ? "•••• €" : (Double(flow.remainingCents) / 100).euro).font(.headline).monospacedDigit()
                    .foregroundStyle(flow.remainingCents < 0 ? NativeDesign.danger : NativeDesign.financialGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("budget-map-final")
        }
    }
    private func legend(_ title: String, _ cents: Int, _ color: Color) -> some View {
        HStack(spacing: NativeDesign.Space.xs) {
            Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            Text(title + (hidden ? "" : " " + (Double(cents) / 100).euro)).font(.caption2).foregroundStyle(NativeDesign.secondary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// ANALYSIS-CLARITY-97: what a normal month costs, from the spending categories of the chosen months, without
/// transfers, investments and savings moves; the three biggest categories per month underneath.
struct NativeNormalMonthCard: View {
    let rows: [Record]
    let months: Int
    let loading: Bool
    let hidden: Bool
    static let excluded = ["trasferim", "investiment", "risparmi", "giroconto", "accantonament"]
    static func spending(_ rows: [Record]) -> [(name: String, amount: Double)] {
        rows.map { (name: $0.text("name", fallback: "Altro"), amount: $0.amount("amount")) }
            .filter { row in row.amount > 0 && !excluded.contains { row.name.lowercased().contains($0) } }
            .sorted { $0.amount > $1.amount }
    }
    var body: some View {
        let spending = Self.spending(rows), count = Double(max(1, months))
        let perMonth = spending.reduce(0) { $0 + $1.amount } / count
        LOAnalysisCard(title: "Spese di un mese normale", trailing: months == 1 ? "ultimo mese" : "ultimi " + String(months) + " mesi", identifier: "finance-normal-month") {
            if loading && rows.isEmpty { ProgressView().frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget) }
            else if spending.isEmpty { Text("Nessuna spesa nel periodo").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            else {
                Text(hidden ? "•••• €" : perMonth.euro).font(.title.bold()).monospacedDigit()
                Text("Media al mese delle spese del budget, senza trasferimenti, investimenti e soldi messi da parte.")
                    .font(.footnote).foregroundStyle(NativeDesign.secondary)
                ForEach(Array(spending.prefix(3).enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.name).font(.subheadline)
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(hidden ? "••••" : (row.amount / count).euro + " al mese").font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                    }
                }
            }
        }
    }
}
