import SwiftUI
import Charts

enum NativeHealthMetric: String, CaseIterable, Identifiable {
    case tdee, weight, calories, simulation
    var id: String { rawValue }
    var title: String {
        switch self { case .tdee: return "TDEE"; case .weight: return "Peso"; case .calories: return "Calorie"; case .simulation: return "Simulazione" }
    }
    var symbol: String {
        switch self { case .tdee: return "flame.fill"; case .weight: return "figure.stand"; case .calories: return "fork.knife"; case .simulation: return "chart.xyaxis.line" }
    }
    var color: Color {
        switch self { case .tdee: return .pink; case .weight: return .blue; case .calories: return .orange; case .simulation: return .purple }
    }
    var unit: String { self == .weight || self == .simulation ? "kg" : "kcal" }
}

struct NativeHealthDetail: View {
    @ObservedObject var health: NativeHealthStore
    let demo: Bool
    @State private var addingWeight = false
    @State private var showingNutrition = false
    @State private var tdeeHistory: [HealthPoint] = []

    var body: some View {
        ScrollView {
            VStack(spacing: NativeDesign.Space.medium) {
                if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(.secondary) }
                ForEach(NativeHealthMetric.allCases) { metric in
                    NavigationLink {
                        NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
                    } label: {
                        NativeHealthSummaryRow(metric: metric, value: value(metric), points: points(metric))
                    }.buttonStyle(NativePressStyle()).accessibilityIdentifier("health-summary-" + metric.rawValue)
                }
                if health.loading { ProgressView().accessibilityLabel("Lettura Salute") }
                if let message = health.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
        }.background(NativeDesign.canvas).navigationTitle("Salute").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("health-detail-scroll")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: NativeDesign.Space.medium) {
                    Spacer()
                    NativeToolbarButton(symbol: "figure.stand", label: "Aggiungi peso") { addingWeight = true }
                        .accessibilityIdentifier("health-add-weight")
                    NativeToolbarButton(symbol: "carrot.fill", label: "Registrazioni macro") { showingNutrition = true }
                        .accessibilityIdentifier("health-add-nutrition")
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
            }
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionScreen().toolbar { DoneButton() } } }
            .refreshable { await health.refresh() }
            .onChange(of: health.days, initial: true) { _, days in
                let ordered = days.sorted { $0.date < $1.date }
                tdeeHistory = ordered.suffix(30).compactMap { day in
                    guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day.date),
                          let estimate = NativeHealthMath.estimate(ordered.filter { $0.date <= day.date }, now: tomorrow) else { return nil }
                    return HealthPoint(date: day.date, value: estimate.tdee)
                }
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
            return Array(NativeHealthMath.forecast(estimate, intake: estimate.averageIntake).prefix(57))
        }
    }
}

private struct NativeHealthSummaryRow: View {
    let metric: NativeHealthMetric
    let value: String
    let points: [HealthPoint]
    @ScaledMetric(relativeTo: .largeTitle) private var rowHeight = NativeDesign.Layout.healthSummaryRow
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .bottom, spacing: NativeDesign.Space.medium) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                Label(metric.title, systemImage: metric.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(metric.color)
                Spacer(minLength: NativeDesign.Space.small)
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.xs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs))
                layout {
                    Text(value).font(.largeTitle.weight(.bold)).foregroundStyle(.primary).monospacedDigit()
                    Text(metric.unit).font(.subheadline).foregroundStyle(.secondary)
                }
                if metric == .simulation { Text("Tra 8 settimane").font(.caption2).foregroundStyle(.secondary) }
                else if metric == .calories { Text("Oggi").font(.caption2).foregroundStyle(.secondary) }
                else if metric == .tdee { Text("Media storica stimata").font(.caption2).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !points.isEmpty && !typeSize.isAccessibilitySize {
                Chart(points) { point in
                    if metric == .calories {
                        BarMark(x: .value("Data", point.date), y: .value("Calorie", point.value))
                            .foregroundStyle(point.id == points.last?.id ? metric.color : Color.secondary.opacity(0.35))
                    } else {
                        PointMark(x: .value("Data", point.date), y: .value(metric.unit, point.value))
                            .symbolSize(metric == .simulation ? 8 : 16)
                            .foregroundStyle(point.id == points.last?.id ? metric.color : Color.secondary.opacity(0.45))
                    }
                }.chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
                    .chartYScale(domain: chartDomain)
                    .frame(width: NativeDesign.Layout.healthSummaryChartWidth, height: NativeDesign.Layout.healthSummaryChartHeight)
                    .accessibilityHidden(true)
            }
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(height: rowHeight, alignment: .leading)
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.title + ", " + value + " " + metric.unit + (metric == .simulation ? ", tra 8 settimane con introito medio recente" : ""))
            .accessibilityHint("Apre il dettaglio")
    }
    private var chartDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        if metric == .calories { return 0...max(1, values.max() ?? 1) }
        let low = values.min() ?? 0, high = values.max() ?? 1
        let padding = max((high - low) * 0.15, metric == .tdee ? 50 : 0.5)
        return (low - padding)...(high + padding)
    }
}
