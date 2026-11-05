import SwiftUI
import Charts
import UIKit
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
    @State private var tdeeHistory: [HealthPoint] = []
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
                if nutrition.entries.contains(where: { !$0.confirmed || $0.deletionPending == true }) {
                    Text("Registrazioni LifeOS in sospeso: consultale nella cronologia. I totali riportano solo i dati leggibili da Salute.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = health.nutrientMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                if health.loading { ProgressView().accessibilityLabel("Lettura Salute") }
                if let message = health.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.padding(.horizontal, NativeDesign.Layout.listInset).padding(.vertical, NativeDesign.Space.large)
        }.background(NativeDesign.healthCanvas).navigationTitle("Salute").navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("health-detail-scroll")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: NativeDesign.Space.medium) {
                    Spacer()
                    NativeToolbarButton(symbol: NativeHealthMetric.weight.symbol, label: "Aggiungi peso") { addingWeight = true }
                        .accessibilityIdentifier("health-add-weight")
                    NativeToolbarButton(symbol: NativeHealthMetric.calories.symbol, label: "Aggiungi nutrienti") { showingNutrition = true }
                        .accessibilityIdentifier("health-add-nutrition")
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
            }
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionQuickSheet() }.environmentObject(health) }
            .refreshable { await health.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await health.refresh() } }
            }
            .onChange(of: health.days, initial: true) { _, days in
                let ordered = days.sorted { $0.date < $1.date }
                tdeeHistory = ordered.suffix(30).compactMap { day in
                    guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day.date),
                          let estimate = NativeHealthMath.estimate(ordered.filter { $0.date <= day.date }, now: tomorrow) else { return nil }
                    return HealthPoint(date: day.date, value: estimate.tdee)
                }
            }
    }
    private func metricLink(_ metric: NativeHealthMetric) -> some View {
        NavigationLink {
            NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
        } label: {
            NativeHealthSummaryRow(metric: metric, value: value(metric), points: points(metric), contextLabel: context(metric))
        }.buttonStyle(NativePressStyle()).accessibilityIdentifier("health-summary-" + metric.rawValue)
            .frame(maxWidth: .infinity)
    }
    private var nutrients: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Nutrienti · oggi").font(.headline)
            Text("Apple Salute · tutte le app leggibili").font(.caption).foregroundStyle(.secondary)
            if typeSize.isAccessibilitySize {
                nutrientGrid(columns: 1)
            } else if typeSize >= .xxxLarge {
                nutrientGrid(columns: 2)
            } else {
                ViewThatFits(in: .horizontal) {
                    nutrientGrid(columns: 4).frame(minWidth: 280)
                    nutrientGrid(columns: 2)
                }
            }
            NavigationLink { NativeNutritionScreen() } label: {
                Label("Cronologia nutrizione", systemImage: "clock.arrow.circlepath")
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
            }.accessibilityIdentifier("health-nutrition-history")
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.Layout.healthSummaryRadius))
    }
    private func nutrientGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.small), count: columns), spacing: NativeDesign.Space.small) {
            nutrient("Proteine", .dietaryProtein)
            nutrient("Carboidrati", .dietaryCarbohydrates)
            nutrient("Grassi", .dietaryFatTotal)
            nutrient("Fibre", .dietaryFiber)
        }
    }

    private func nutrient(_ title: String, _ type: HKQuantityTypeIdentifier) -> some View {
        let failed = health.nutrientFailures.contains(type)
        let value = health.nutrientTotals[type].map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—"
        return VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value == "—" ? value : value + " g").font(.headline).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore).accessibilityLabel(title + ", " + (failed ? "lettura non riuscita" : (value == "—" ? "nessun dato leggibile" : value + " grammi")))
            .accessibilityIdentifier("health-nutrient-" + type.rawValue)
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
        case .simulation: number = points(metric).last?.value
        }
        return number?.formatted(.number.precision(.fractionLength(metric == .weight || metric == .simulation ? 1 : 0))) ?? "—"
    }
    private func points(_ metric: NativeHealthMetric) -> [HealthPoint] {
        switch metric {
        case .tdee: return tdeeHistory
        case .weight: return health.days.suffix(30).compactMap { day in day.weight.map { HealthPoint(date: day.date, value: $0) } }
        case .calories: return health.days.suffix(30).compactMap { day in day.calories.map { HealthPoint(date: day.date, value: $0) } }
        case .simulation:
            guard let estimate = health.estimate else { return [] }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let target = calendar.date(byAdding: .month, value: 1, to: today) else { return [] }
            return NativeHealthMath.forecast(estimate, intake: estimate.averageIntake, weeks: 6)
                .filter { $0.date >= today && $0.date <= target }
        }
    }
}

private struct NativeHealthSummaryRow: View {
    let metric: NativeHealthMetric
    let value: String
    let points: [HealthPoint]
    let contextLabel: String
    @ScaledMetric(relativeTo: .largeTitle) private var rowHeight = NativeDesign.Layout.healthSummaryRow

    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                Label { Text(metric.title) } icon: { NativeSymbol(symbol: metric.symbol) }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(metric.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                    Text(contextLabel).font(.caption2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: NativeDesign.Space.xs)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) { amountText; unitText }.fixedSize()
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { amountText; unitText }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !points.isEmpty { historyChart }

        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(minHeight: rowHeight, maxHeight: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.Layout.healthSummaryRadius))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.title + ", " + value + " " + metric.unit + ", " + contextLabel)
            .accessibilityHint("Apre il dettaglio")
    }
    private var amountText: some View {
        Text(value).font(.largeTitle.weight(.bold)).foregroundStyle(.primary).monospacedDigit()
    }
    private var unitText: some View {
        Text(metric.unit).font(.subheadline).foregroundStyle(.secondary)
    }
    private var historyChart: some View {
        Chart(points) { point in
            if metric == .calories {
                BarMark(x: .value("Data", point.date, unit: .day), y: .value("Calorie", point.value), width: .ratio(0.7))
                    .foregroundStyle(point.id == points.last?.id ? metric.color : Color.secondary.opacity(0.35))
            } else {
                PointMark(x: .value("Data", point.date), y: .value(metric.unit, point.value))
                    .symbolSize(metric == .simulation ? 8 : 16)
                    .foregroundStyle(point.id == points.last?.id ? metric.color : Color.secondary.opacity(0.45))
            }
        }.chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
            .chartYScale(domain: chartDomain)
            .frame(maxWidth: .infinity).frame(height: NativeDesign.Layout.healthSummaryChartHeight)
            .accessibilityHidden(true)
    }
    private var chartDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        if metric == .calories { return 0...max(1, values.max() ?? 1) }
        let low = values.min() ?? 0, high = values.max() ?? 1
        let padding = max((high - low) * 0.15, metric == .tdee ? 50 : 0.5)
        return (low - padding)...(high + padding)
    }
}
