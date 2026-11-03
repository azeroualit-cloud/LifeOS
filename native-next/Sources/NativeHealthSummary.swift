import SwiftUI
import Charts
import UIKit

enum NativeHealthMetric: String, CaseIterable, Identifiable {
    case tdee, weight, calories, simulation
    var id: String { rawValue }
    var title: String {
        switch self { case .tdee: return "TDEE"; case .weight: return "Peso"; case .calories: return "Calorie"; case .simulation: return "Simulazione" }
    }
    var symbol: String {
        switch self {
        case .tdee: return "flame.fill"
        case .weight: return "figure"
        case .calories: return Self.nutritionSymbol
        case .simulation: return "chart.xyaxis.line"
        }
    }
    private static let nutritionSymbol = UIImage(systemName: "apple.slice") == nil ? "fork.knife" : "apple.slice"
    var color: Color {
        switch self { case .tdee: return .pink; case .weight: return .blue; case .calories: return .orange; case .simulation: return .purple }
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

    var body: some View {
        ScrollView {
            VStack(spacing: NativeDesign.Space.medium) {
                if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(.secondary) }
                NativeHealthSummaryRowsLayout {
                    ForEach(NativeHealthMetric.allCases) { metric in
                        NavigationLink {
                            NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
                        } label: {
                            NativeHealthSummaryRow(metric: metric, value: value(metric), points: points(metric))
                        }.buttonStyle(NativePressStyle()).accessibilityIdentifier("health-summary-" + metric.rawValue)
                    }
                }
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
                    NativeToolbarButton(symbol: NativeHealthMetric.calories.symbol, label: "Registrazioni macro") { showingNutrition = true }
                        .accessibilityIdentifier("health-add-nutrition")
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
            }
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionScreen().toolbar { DoneButton() } } }
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
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            let header = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.xs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small))
            header {
                Label(metric.title, systemImage: metric.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(metric.color)
                    .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { Spacer(minLength: NativeDesign.Space.xs) }
                HStack(spacing: NativeDesign.Space.xs) {
                    Text(contextLabel).font(.caption2)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(alignment: .bottom, spacing: NativeDesign.Space.medium) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                        amountText; unitText
                    }.fixedSize()
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        amountText; unitText
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !points.isEmpty && !typeSize.isAccessibilitySize { historyChart }
            }
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(minHeight: rowHeight, maxHeight: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius))
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
    private var contextLabel: String {
        switch metric {
        case .tdee: return "Stima storica"
        case .weight: return "Ultima pesata"
        case .calories: return "Oggi"
        case .simulation: return "8 settimane"
        }
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
            .frame(width: NativeDesign.Layout.healthSummaryChartWidth, height: NativeDesign.Layout.healthSummaryChartHeight)
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

/// Measures actual content before equalizing rows, including accessibility fonts.
/// Fixed scaled heights can clip labels and units when their font curves differ.
private struct NativeHealthSummaryRowsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let height = subviews.map { $0.sizeThatFits(.init(width: width, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height * CGFloat(subviews.count) + NativeDesign.Space.medium * CGFloat(max(0, subviews.count - 1)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let spacing = NativeDesign.Space.medium
        let height = (bounds.height - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(index) * (height + spacing)),
                anchor: .topLeading, proposal: .init(width: bounds.width, height: height))
        }
    }
}
