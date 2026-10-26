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
        List {
            categories
            Section { NativeForecastCard() }
            wealth
            salary
        }.modifier(NativeListAppearance())
            .task(id: requestKey) { await loadCategories() }
            .onChange(of: store.finance) { _, _ in
                if !categoryLoading { updateCurrentMonth() }
            }
            .navigationTitle("Analisi").navigationBarTitleDisplayMode(.inline)
    }
    private var categories: some View {
        Section("Spese per categoria") {
            Picker("Periodo categorie", selection: $categoryRange) {
                Text("3 mesi").tag(3); Text("6 mesi").tag(6); Text("12 mesi").tag(12)
            }.pickerStyle(.segmented).accessibilityIdentifier("category-period")
            if let first = months.first, let last = months.last {
                Text(CivilDate.monthTitle(first) + " – " + CivilDate.monthTitle(last)).font(.caption).foregroundStyle(NativeDesign.secondary)
            }
            if categoryLoading || loadedKey != requestKey { ProgressView("Categorie: \(categoryLoadedMonths) di \(months.count) mesi…") }
            else if let categoryError { NativeInlineMessage(text: categoryError) }
            else if categoryRows.isEmpty { Text("Nessuna spesa nel periodo").foregroundStyle(NativeDesign.secondary) }
            else { NativeCategoryChart(rows: categoryRows) }
            if store.isDemo { Text("Dati demo · movimenti simulati disponibili.").font(.caption).foregroundStyle(NativeDesign.secondary) }
            if store.server != nil {
                Button(categoryError == nil ? "Aggiorna categorie" : "Riprova") {
                    // A failed month must not force successful months to be downloaded again.
                    if categoryError == nil { categoryCache.clear() }
                    retry &+= 1
                }.disabled(categoryLoading || loadedKey != requestKey)
            }
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
            Section("Patrimonio") {
                Text("12 mesi fino a " + CivilDate.monthTitle(store.financeMonth)).font(.caption).foregroundStyle(NativeDesign.secondary)
                if rows.isEmpty { Text("Storico del patrimonio non disponibile per il periodo.").foregroundStyle(NativeDesign.secondary) }
                else { Chart {
                    ForEach(rows.enumerated().map { IndexedRecord(index: $0.offset, value: $0.element) }) { item in
                        let value = wealthValue(item.value)
                        if item.index > 0 {
                            let previous = rows[item.index - 1]
                            let previousValue = wealthValue(previous)
                            let color = value < previousValue ? NativeDesign.financialRed : NativeDesign.financialGreen
                            LineMark(x: .value("Mese", previous.text("month")), y: .value("Euro", previousValue), series: .value("Tratto", item.index)).foregroundStyle(color)
                            LineMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", value), series: .value("Tratto", item.index)).foregroundStyle(color)
                        }
                        PointMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", value)).foregroundStyle(item.index > 0 && value < wealthValue(rows[item.index - 1]) ? NativeDesign.financialRed : NativeDesign.financialGreen)
                    }
                }.chartXAxis {
                    AxisMarks(values: NativeFinanceMonthAxis.ticks(rows.map { $0.text("month") })) { value in
                        AxisValueLabel {
                            if let month = value.as(String.self) { Text(NativeFinanceMonthAxis.label(month)).font(.caption2).multilineTextAlignment(.center).fixedSize() }
                        }
                    }
                }.frame(height: 220).accessibilityIdentifier("finance-wealth-history-chart") }
                Text("Misure e stime storiche provengono dal Worker. Prima della prima rilevazione il saldo può non essere ricostruibile.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
    }
    @ViewBuilder private var salary: some View {
        let rows = selected(lifetime.records("salaryHistory"))
            Section("Stipendi per competenza") {
                Text("12 mesi fino a " + CivilDate.monthTitle(store.financeMonth)).font(.caption).foregroundStyle(NativeDesign.secondary)
                if rows.isEmpty { Text("Nessun cedolino disponibile nel periodo.").foregroundStyle(NativeDesign.secondary) }
                else { Chart {
                    ForEach(rows.enumerated().map { IndexedRecord(index: $0.offset, value: $0.element) }) { item in
                        BarMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", item.value.amount("base"))).foregroundStyle(by: .value("Voce", "Base"))
                        BarMark(x: .value("Mese", item.value.text("month")), y: .value("Euro", item.value.amount("additional"))).foregroundStyle(by: .value("Voce", "Aggiuntive"))
                    }
                }.chartForegroundStyleScale(["Base": NativeDesign.financialGreen, "Aggiuntive": NativeDesign.financialGreen.opacity(0.55)])
                    .chartXAxis {
                        AxisMarks(values: NativeFinanceMonthAxis.ticks(rows.map { $0.text("month") })) { value in
                            AxisValueLabel {
                                if let month = value.as(String.self) { Text(NativeFinanceMonthAxis.label(month)).font(.caption2).multilineTextAlignment(.center).fixedSize() }
                            }
                        }
                    }.frame(height: 220).accessibilityIdentifier("finance-salary-history-chart") }
                Text("La competenza del cedolino è distinta dalla data di accredito.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
    }
    private func wealthValue(_ row: Record) -> Double {
        for key in ["measured", "estimated", "wealth"] {
            if case .number(let value)? = row[key], value.isFinite { return value }
        }
        return 0
    }
}
