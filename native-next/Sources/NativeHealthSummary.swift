import SwiftUI
import HealthKit

enum NativeHealthMetric: String, CaseIterable, Identifiable {
    case tdee, simulation, weight, calories
    var id: String { rawValue }
    var title: String {
        switch self { case .tdee: return "TDEE"; case .weight: return "Peso"; case .calories: return "Calorie"; case .simulation: return "Peso previsto" }
    }
    var symbol: String {
        switch self {
        case .tdee: return "flame.fill"
        case .weight: return "figure"
        case .calories: return Self.nutritionSymbol
        case .simulation: return "chart.xyaxis.line"
        }
    }
    private static let nutritionSymbol = "lifeos.nutrition.apple"
    var color: Color {
        switch self { case .tdee: return .orange; case .weight: return NativeDesign.healthWeight; case .calories: return .green; case .simulation: return .blue }
    }
    var unit: String {
        switch self { case .weight, .simulation: return "kg"; case .tdee: return "kcal/giorno"; case .calories: return "kcal" }
    }
}

struct NativeHealthDetail: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var health: NativeHealthStore
    let demo: Bool
    @State private var addingWeight = false
    @State private var showingNutrition = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current

    var body: some View {
        ScrollView {
            VStack(spacing: NativeDesign.Space.medium) {
                if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(.secondary) }
                if typeSize.isAccessibilitySize {
                    VStack(spacing: NativeDesign.Space.medium) {
                        ForEach(NativeHealthMetric.allCases) { metricLink($0) }
                    }
                } else {
                    VStack(spacing: NativeDesign.Space.medium) {
                        HStack(alignment: .top, spacing: NativeDesign.Space.medium) { metricLink(.tdee); metricLink(.simulation) }
                        HStack(alignment: .top, spacing: NativeDesign.Space.medium) { metricLink(.weight); metricLink(.calories) }
                    }
                }
                nutrients
                diary
                if nutrition.entries.contains(where: { !$0.confirmed || $0.deletionPending == true }) {
                    Text("Registrazioni LifeOS in sospeso: consultale nella cronologia. I totali riportano solo i dati leggibili da Salute.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = health.nutrientMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                if health.loading { ProgressView().accessibilityLabel("Lettura Salute") }
                if let message = health.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.padding(.horizontal, NativeDesign.Layout.listInset).padding(.vertical, NativeDesign.Space.large)
        }.background(NativeDesign.healthCanvas).navigationTitle("Salute").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("health-detail-scroll")
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionQuickSheet() }.environmentObject(health) }
            .refreshable { await health.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await health.refresh() } }
            }

    }
    private func metricLink(_ metric: NativeHealthMetric) -> some View {
        NavigationLink {
            NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
        } label: {
            NativeHealthSummaryRow(metric: metric, value: value(metric), contextLabel: context(metric))
        }.buttonStyle(NativePressStyle()).accessibilityIdentifier("health-summary-" + metric.rawValue)
            .frame(maxWidth: .infinity)
    }
    private var nutrients: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Nutrienti").font(.headline).foregroundStyle(NativeDesign.nutritionTitle)
            NativeNutrientValues(health: health, includesFibre: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: NativeDesign.Space.small) { nutritionActions }.fixedSize(horizontal: true, vertical: false)
                VStack(spacing: NativeDesign.Space.small) { nutritionActions }
            }.frame(maxWidth: .infinity)
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.Layout.healthSummaryRadius))
    }
    @ViewBuilder private var nutritionActions: some View {
        Button { addingWeight = true } label: {
            Label { Text("Aggiungi peso") } icon: { NativeSymbol(symbol: NativeHealthMetric.weight.symbol) }
                .font(.subheadline.weight(.semibold))
        }.buttonStyle(NativeGlassButtonStyle()).accessibilityIdentifier("health-add-weight")
        Button { showingNutrition = true } label: {
            Label { Text("Aggiungi alimento") } icon: { NativeSymbol(symbol: NativeHealthMetric.calories.symbol) }
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(NativeGlassButtonStyle()).accessibilityIdentifier("health-add-nutrition")
    }
    private var diary: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack {
                Text("Diario").font(.headline)
                Spacer(minLength: NativeDesign.Space.small)
                NavigationLink { NativeNutritionScreen() } label: {
                    Text("Cronologia").frame(minHeight: NativeDesign.Layout.touchTarget)
                }
                .accessibilityLabel("Cronologia nutrizione")
                .accessibilityIdentifier("health-nutrition-history")
            }
            let rows = diaryRows
            if rows.isEmpty {
                Text("Nessuna registrazione disponibile").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                Divider()
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        Text(row.name).font(.subheadline.weight(.semibold))
                        Text(row.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: NativeDesign.Space.small)
                    Text("\(row.calories, format: .number.precision(.fractionLength(0))) kcal")
                        .font(.subheadline).monospacedDigit()
                }
            }
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.Layout.healthSummaryRadius))
    }

    private struct DiaryRow: Identifiable {
        let id: UUID
        let name: String
        let date: Date
        let source: String
        let calories: Double
        var grams: Decimal? = nil
        var detail: String {
            let time = date.formatted(.dateTime.hour().minute())
            let portion = grams.map { NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...1))) + " g" }
            return [time, portion, source].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private var diaryRows: [DiaryRow] {
        let local = nutrition.entries.filter {
            $0.confirmed && $0.deletionPending != true && Calendar.current.isDateInToday($0.date)
        }
        let localIDs = Set(local.map(\.id))
        let imported = health.todayFoodEntries.compactMap { sample -> DiaryRow? in
            if let id = sample.lifeOSID, localIDs.contains(id) { return nil }
            return DiaryRow(id: sample.id, name: sample.name ?? "Energia alimentare", date: sample.date,
                source: sample.lifeOSID == nil ? "Apple Salute" : "LifeOS", calories: sample.calories)
        }
        return (imported + local.map {
            DiaryRow(id: $0.id, name: $0.foodName ?? "Energia alimentare", date: $0.date,
                source: "LifeOS", calories: NSDecimalNumber(decimal: $0.calories).doubleValue, grams: $0.portionGrams)
        }).sorted { $0.date > $1.date }
    }

    private func context(_ metric: NativeHealthMetric) -> String {
        switch metric {
        case .tdee: return "Stima storica"
        case .weight: return health.days.last(where: { $0.weight != nil })?.date.formatted(date: .abbreviated, time: .omitted) ?? "Ultima pesata"
        case .calories: return "Oggi"
        case .simulation:
            return Calendar.current.date(byAdding: .month, value: 1, to: Date())?.formatted(date: .abbreviated, time: .omitted) ?? "Tra un mese"
        }
    }
    private func value(_ metric: NativeHealthMetric) -> String {
        let number: Double?
        switch metric {
        case .tdee: number = health.estimate.map { ($0.tdee / 50).rounded() * 50 }
        case .weight: number = health.days.last(where: { $0.weight != nil })?.weight
        case .calories: number = health.days.first(where: { Calendar.current.isDateInToday($0.date) })?.calories
        case .simulation: number = forecast.last?.value
        }
        return number?.formatted(.number.precision(.fractionLength(metric == .weight || metric == .simulation ? 1 : 0))) ?? "—"
    }
    private var forecast: [HealthPoint] {
        guard let estimate = health.estimate else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let target = calendar.date(byAdding: .month, value: 1, to: today) else { return [] }
        return NativeHealthMath.forecast(estimate, intake: estimate.averageIntake, weeks: 6)
            .filter { $0.date >= today && $0.date <= target }
    }
}

struct NativeNutrientValues: View {
    @ObservedObject var health: NativeHealthStore
    let includesFibre: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let count = includesFibre ? 4 : 3
        let columns = typeSize.isAccessibilitySize ? 1 : typeSize >= .xxxLarge ? 2 : count
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.xs), count: columns),
                  alignment: .leading, spacing: NativeDesign.Space.small) {
            nutrient("Proteine", .dietaryProtein)
            nutrient("Carboidrati", .dietaryCarbohydrates)
            nutrient("Grassi", .dietaryFatTotal)
            if includesFibre { nutrient("Fibre", .dietaryFiber) }
        }
    }

    private func nutrient(_ title: String, _ type: HKQuantityTypeIdentifier) -> some View {
        let failed = health.nutrientFailures.contains(type)
        let value = health.nutrientTotals[type].map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—"
        return VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value == "—" ? value : value + " g").font(.subheadline.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title + ", " + (failed ? "lettura non riuscita" : (value == "—" ? "nessun dato leggibile" : value + " grammi")))
            .accessibilityIdentifier("health-nutrient-" + type.rawValue)
    }
}

private struct NativeHealthSummaryRow: View {
    let metric: NativeHealthMetric
    let value: String
    let contextLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(metric.title).font(.caption.weight(.semibold)).foregroundStyle(metric.color)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) { amountText; unitText }.fixedSize()
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { amountText; unitText }
            }
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, maxHeight: .infinity, alignment: .topLeading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.title + ", " + value + " " + metric.unit + ", " + contextLabel)
            .accessibilityHint("Apre il dettaglio")
    }
    private var amountText: some View {
        Text(value).font(.title2.weight(.bold)).foregroundStyle(.primary).monospacedDigit()
    }
    private var unitText: some View {
        Text(metric.unit).font(.caption).foregroundStyle(.secondary)
    }
}
