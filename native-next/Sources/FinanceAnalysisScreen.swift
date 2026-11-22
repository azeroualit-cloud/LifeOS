import SwiftUI
import Charts

struct FinanceAnalysisScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var categoryRange = 3
    @State private var categoryCache = NativeCategoryPeriodCache()
    @State private var categoryLoadedMonths = 0
    @State private var categoryRows: [Record] = []
    @State private var categoryLoading = false
    @State private var categoryError: String?
    @State private var retry = 0
    @State private var activeLoad = UUID()
    @State private var loadedKey = ""
    @State private var flowSelection: String?
    @State private var salarySelection: String?
    @AppStorage("native-hide-money") private var hidden = false
    private var lifetime: Record { store.finance.record("lifetime") }
    private var months: [String] { NativeCategoryPeriod.months(ending: store.financeMonth, count: categoryRange) }
    private var sourceScope: String { (store.state.endpoint ?? "offline") + (store.isDemo ? "|demo" : "|real") }
    private var requestKey: String { "\(sourceScope)|\(store.financeGeneration)|\(store.financeMonth)|\(categoryRange)|\(retry)" }
    private var categoryScope: String { "\(sourceScope)|\(store.financeGeneration)" }
    private func selected(_ rows: [Record]) -> [Record] {
        let first = NativeCategoryPeriod.months(ending: store.financeMonth, count: 12).first ?? store.financeMonth
        return rows.filter { $0.text("month") >= first && $0.text("month") <= store.financeMonth }.sorted { $0.text("month") < $1.text("month") }
    }
    var body: some View {
        let flows = NativeFinanceAnalysis93.flows(store.finance, before: CivilDate.month())
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                NativeRhythmCard(flows: flows, hidden: hidden)
                NativeFundRunwayCard(fund: NativeFinanceAnalysis93.fund(store.finance), surplus: NativeFinanceAnalysis93.surplus(store.finance),
                                     norm: NativeFinanceAnalysis93.norm(flows), hidden: hidden)
                LOAnalysisCard(title: "Stima patrimonio", trailing: "6 mesi prima · 6 dopo", identifier: "finance-wealth-estimate") {
                    NativeForecastCard()
                }
                categories
                incomeAndSpending(flows)
                salary
                NativeDailySpendCard(month: store.financeMonth, daily: NativeFinanceAnalysis93.daily(store.transactions, month: store.financeMonth), hidden: hidden)
                wealth
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.medium)
        }
        .background(NativeDesign.canvas)
        .task(id: requestKey) { await loadCategories() }
        .onChange(of: store.finance) { _, _ in
            if !categoryLoading { updateCurrentMonth() }
        }
        .navigationTitle("Analisi").navigationBarTitleDisplayMode(.large)
    }
    private var categoryTrailing: String {
        guard let first = months.first, let last = months.last else { return "" }
        return NativeFinanceAnalysis93.shortMonth(first) + " – " + NativeFinanceAnalysis93.shortMonth(last)
    }
    private var categories: some View {
        LOAnalysisCard(title: "Spese per categoria", trailing: categoryTrailing, identifier: "finance-categories") {
            LOSegmented(options: [("3 mesi", "3"), ("6 mesi", "6"), ("12 mesi", "12")], selection: Binding(
                get: { String(categoryRange) + " mesi" },
                set: { categoryRange = Int($0.prefix(while: { $0.isNumber })) ?? 3 }), identifierPrefix: "category-period-")
            if categoryLoading || loadedKey != requestKey { ProgressView("Categorie: \(categoryLoadedMonths) di \(months.count) mesi…") }
            else if let categoryError { NativeInlineMessage(text: categoryError) }
            else if categoryRows.isEmpty { Text("Nessuna spesa nel periodo").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            else { NativeCategoryBars93(rows: categoryRows, months: months.count, hidden: hidden) }
            if store.server != nil, categoryError != nil {
                Button("Riprova") { retry &+= 1 }.disabled(categoryLoading || loadedKey != requestKey)
            }
        }
    }
    private func flowBar(_ flow: NativeMonthFlow) -> LOBarPicker.Bar {
        let spoken: String = hidden ? "" : ": entrate " + flow.income.euro + ", uscite " + flow.spent.euro
        return LOBarPicker.Bar(id: flow.month, label: NativeFinanceAnalysis93.shortMonth(flow.month), values: [flow.income, flow.spent],
                               accessibility: CivilDate.monthTitle(flow.month) + spoken)
    }
    private func flowSummary(_ flow: NativeMonthFlow) -> String {
        if hidden { return "••••" }
        let sign: String = flow.saved >= 0 ? "+" : "−"
        return flow.income.euro + " · " + flow.spent.euro + " · " + sign + abs(flow.saved).euro
    }
    private func incomeAndSpending(_ flows: [NativeMonthFlow]) -> some View {
        let bars: [LOBarPicker.Bar] = flows.suffix(6).map(flowBar)
        let current: NativeMonthFlow? = flows.first { $0.month == flowSelection } ?? flows.last
        let trailing: String = flows.first.map { "da " + NativeFinanceAnalysis93.shortMonth($0.month) } ?? ""
        return LOAnalysisCard(title: "Entrate e uscite", trailing: trailing, identifier: "finance-income-spending") {
            if bars.isEmpty { Text("Nessun mese completo").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            else {
                LOBarPicker(bars: bars, colors: [NativeDesign.financialGreen, NativeDesign.financeBudget[0]], selected: $flowSelection, identifierPrefix: "finance-flow-")
                HStack(spacing: NativeDesign.Space.medium) {
                    legend("entrate", NativeDesign.financialGreen)
                    legend("uscite", NativeDesign.financeBudget[0])
                }
                if let current {
                    HStack(alignment: .firstTextBaseline) {
                        Text(CivilDate.monthTitle(current.month)).font(.subheadline)
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(flowSummary(current)).font(.footnote.weight(.semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("finance-flow-selected")
                }
            }
        }
    }
    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: NativeDesign.Space.xs) {
            Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            Text(title).font(.footnote).foregroundStyle(NativeDesign.secondary)
        }
    }
    @MainActor private func loadCategories() async {
        let key = requestKey, scope = categoryScope, requested = months, token = UUID()
        activeLoad = token
        categoryLoading = true; categoryError = nil; categoryRows = []
        defer {
            if requestKey == key && activeLoad == token { categoryLoading = false; loadedKey = key }
        }
        do {
            categoryCache.prepare(scope: scope)
            categoryLoadedMonths = requested.count - categoryCache.missing(in: requested).count
            await store.loadAnalysis()
            try Task.checkCancellation()
            guard requestKey == key && activeLoad == token else { return }
            if store.isDemo {
                var samples = Dictionary(uniqueKeysWithValues: requested.map { ($0, [Record]()) })
                for row in store.finance.records("transactions") where ["Spesa", "Rimborso"].contains(row.text("type")) {
                    let month = String(row.text("date").prefix(7))
                    guard samples[month] != nil else { continue }
                    samples[month, default: []].append(["name": .string(row.text("displayCategory", fallback: row.text("category", fallback: "Altro"))), "amount": .number(-row.amount("amount"))])
                }
                if store.financeMonth == CivilDate.month(), case .array(let rows)? = store.finance["categories"] {
                    samples[store.financeMonth] = rows.map(\.object)
                }
                categoryRows = try NativeCategoryPeriod.aggregate(samples, months: requested)
                return
            }
            guard store.server != nil else {
                throw Message(text: "Collega il server per analizzare 3, 6 o 12 mesi. Lo snapshot locale non garantisce la copertura del periodo.")
            }
            if store.analysisIsCurrent, case .array(let rows)? = store.finance["categories"] {
                try categoryCache.store(rows.map(\.object), month: store.financeMonth)
            }
            categoryLoadedMonths = requested.count - categoryCache.missing(in: requested).count
            if !categoryCache.missing(in: requested).isEmpty {
                try Task.checkCancellation()
                let response = try await store.read("getFinanceCategoryPeriod", args: [.string(store.financeMonth), .int(categoryRange)])
                try Task.checkCancellation()
                guard requestKey == key && activeLoad == token else { return }
                try categoryCache.storePeriod(response, ending: store.financeMonth, count: categoryRange)
                categoryLoadedMonths = requested.count
            }
            guard requestKey == key && activeLoad == token else { return }
            if store.analysisIsCurrent, case .array(let rows)? = store.finance["categories"] {
                try categoryCache.store(rows.map(\.object), month: store.financeMonth)
            }
            categoryRows = try categoryCache.aggregate(months: requested)
        } catch is CancellationError {} catch {
            guard requestKey == key && activeLoad == token, !Task.isCancelled else { return }
            categoryRows = []
            categoryError = error.localizedDescription + " Premi Riprova per caricare il periodo."
        }
    }
    private func updateCurrentMonth() {
        guard !store.isDemo, categoryCache.scope == categoryScope, store.analysisIsCurrent,
              case .array(let rows)? = store.finance["categories"] else { return }
        do {
            try categoryCache.store(rows.map(\.object), month: store.financeMonth)
            if categoryCache.missing(in: months).isEmpty {
                categoryRows = try categoryCache.aggregate(months: months); categoryError = nil
            }
        } catch { categoryRows = []; categoryError = "Dati categoria non validi. Riprova." }
    }
    @ViewBuilder private var wealth: some View {
        let source = store.finance.records("wealthHistory").isEmpty ? lifetime.records("series") : store.finance.records("wealthHistory")
        let rows = selected(source).filter { row in
            ["measured", "estimated", "wealth"].contains { key in
                if case .number(let value)? = row[key] { return value.isFinite }; return false
            }
        }
        LOAnalysisCard(title: "Patrimonio", trailing: "12 mesi", identifier: "finance-wealth") {
            if rows.isEmpty || hidden { Text(hidden ? "Importi nascosti" : "Storico non disponibile").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            else { wealthChart(rows) }
        }
    }
    private func wealthChart(_ rows: [Record]) -> some View {
        Chart {
            ForEach(rows.enumerated().map { IndexedRecord(index: $0.offset, value: $0.element) }) { item in
                LineMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", wealthValue(item.value))).foregroundStyle(NativeDesign.financeBudget[0])
                PointMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", wealthValue(item.value))).foregroundStyle(NativeDesign.financeBudget[0])
            }
        }
        .chartXAxis {
            AxisMarks(values: NativeFinanceMonthAxis.ticks(rows.map { $0.text("month") })) { value in
                AxisValueLabel {
                    if let month = value.as(String.self) { Text(NativeFinanceMonthAxis.label(month)).font(.caption2).multilineTextAlignment(.center).fixedSize() }
                }
            }
        }
        .frame(height: 160).accessibilityIdentifier("finance-wealth-history-chart")
    }
    private func salaryBar(_ row: Record) -> LOBarPicker.Bar {
        let total: Double = row.amount("base") + row.amount("additional")
        let spoken: String = hidden ? "" : ": " + total.euro
        return LOBarPicker.Bar(id: row.text("month"), label: NativeFinanceAnalysis93.shortMonth(row.text("month")), values: [total],
                               accessibility: CivilDate.monthTitle(row.text("month")) + spoken)
    }
    @ViewBuilder private var salary: some View {
        let rows = selected(lifetime.records("salaryHistory"))
        let bars: [LOBarPicker.Bar] = rows.suffix(6).map(salaryBar)
        let current: Record? = rows.first { $0.text("month") == salarySelection } ?? rows.last
        LOAnalysisCard(title: "Stipendi per competenza", trailing: "cedolini", identifier: "finance-salaries") {
            if bars.isEmpty { Text("Nessun cedolino nel periodo").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
            else {
                LOBarPicker(bars: bars, colors: [NativeDesign.financeGroups[0]], selected: $salarySelection, identifierPrefix: "finance-salary-")
                    .accessibilityIdentifier("finance-salary-history-chart")
                if let current { salaryDetail(current) }
            }
        }
    }
    private func salaryDetail(_ row: Record) -> some View {
        let total: Double = row.amount("base") + row.amount("additional")
        return HStack(alignment: .firstTextBaseline) {
            Text(CivilDate.monthTitle(row.text("month"))).font(.subheadline)
            if row.amount("additional") > 0 && !hidden {
                Text("aggiuntive " + row.amount("additional").euro).font(.footnote).foregroundStyle(NativeDesign.secondary)
            }
            Spacer(minLength: NativeDesign.Space.small)
            Text(hidden ? "••••" : total.euro).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
    private func wealthValue(_ row: Record) -> Double {
        for key in ["measured", "estimated", "wealth"] {
            if case .number(let value)? = row[key], value.isFinite { return value }
        }
        return 0
    }
}
