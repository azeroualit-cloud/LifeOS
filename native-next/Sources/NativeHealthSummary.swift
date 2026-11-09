import SwiftUI
import HealthKit

enum NativeHealthWeek {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func days(containing date: Date) -> [Date] {
        let calendar = calendar
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func moving(_ date: Date, weeks: Int, now: Date = .now) -> Date? {
        let calendar = calendar
        let today = calendar.startOfDay(for: now)
        guard let next = calendar.date(byAdding: .day, value: weeks * 7, to: date),
              let monday = days(containing: next).first, monday <= today else { return nil }
        return min(next, today)
    }
}

enum NativeHealthMetric: String, CaseIterable, Identifiable {
    case tdee, simulation, weight, calories, weeklyCalories, weeklyProtein
    var id: String { rawValue }
    var title: String {
        switch self { case .tdee: return "TDEE"; case .weight: return "Peso"; case .calories: return "Calorie"; case .simulation: return "Peso previsto"; case .weeklyCalories: return "Media calorie"; case .weeklyProtein: return "Media proteine" }
    }
    var symbol: String {
        switch self {
        case .tdee: return "flame.fill"
        case .weight: return "figure"
        case .calories: return Self.nutritionSymbol
        case .simulation, .weeklyCalories, .weeklyProtein: return "chart.xyaxis.line"
        }
    }
    private static let nutritionSymbol = "lifeos.nutrition.apple"
    var color: Color {
        switch self { case .tdee: return .orange; case .weight: return NativeDesign.healthWeight; case .calories: return .green; case .simulation: return .blue; case .weeklyCalories: return .green; case .weeklyProtein: return NativeDesign.nutritionTitle }
    }
    var unit: String {
        switch self { case .weight, .simulation: return "kg"; case .tdee: return "kcal/giorno"; case .calories: return "kcal"; case .weeklyCalories: return "kcal/giorno"; case .weeklyProtein: return "g/giorno" }
    }
}

struct NativeHealthDetail: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var health: NativeHealthStore
    @EnvironmentObject private var store: NativeStore
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    let demo: Bool
    @State private var addingWeight = false
    @State private var showingNutrition = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current

    var body: some View {
        ScrollView {
            VStack(spacing: NativeDesign.Space.medium) {
                weekPicker
                if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(.secondary) }
                if typeSize.isAccessibilitySize {
                    VStack(spacing: NativeDesign.Space.medium) {
                        ForEach(NativeHealthMetric.allCases) { metricLink($0) }
                    }
                } else {
                    VStack(spacing: NativeDesign.Space.medium) {
                        HStack(alignment: .top, spacing: NativeDesign.Space.medium) { metricLink(.tdee); metricLink(.simulation) }
                        HStack(alignment: .top, spacing: NativeDesign.Space.medium) { metricLink(.weight); metricLink(.calories) }
                        HStack(alignment: .top, spacing: NativeDesign.Space.medium) { metricLink(.weeklyCalories); metricLink(.weeklyProtein) }
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
        }
            .accessibilityIdentifier("health-detail-scroll")
            .task { await NativeNutritionUIFixture.prepareReview() }
            .refreshable { await health.refresh() }
            .safeAreaInset(edge: .bottom, spacing: NativeDesign.Space.none) {
                nutritionActionBar
            }
            .background(NativeDesign.healthCanvas)
            .navigationTitle("Salute")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionQuickSheet(initialDate: selectedDate) }.environmentObject(health) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await health.refresh() } }
            }

    }
    @ViewBuilder private func metricLink(_ metric: NativeHealthMetric) -> some View {
        let row = NativeHealthSummaryRow(metric: metric, value: value(metric), contextLabel: context(metric))
        if metric == .weeklyCalories || metric == .weeklyProtein {
            row.accessibilityIdentifier("health-summary-" + metric.rawValue)
        } else {
            NavigationLink {
                NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
            } label: { row }
                .buttonStyle(NativePressStyle()).accessibilityIdentifier("health-summary-" + metric.rawValue)
                .frame(maxWidth: .infinity)
        }
    }

    private var weekPicker: some View {
        let calendar = NativeHealthWeek.calendar
        let today = calendar.startOfDay(for: .now)
        let days = NativeHealthWeek.days(containing: selectedDate)
        return NativeCard(density: .compact) {
            HStack {
                NativeIconButton(symbol: "chevron.left", label: "Settimana precedente") { moveWeek(-1) }
                    .accessibilityIdentifier("health-week-previous")
                Spacer()
                Text(days.first.map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? "")
                    + Text(" – ")
                    + Text(days.last.map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? "")
                Spacer()
                NativeIconButton(symbol: "chevron.right", label: "Settimana successiva") { moveWeek(1) }
                    .accessibilityIdentifier("health-week-next")
                    .disabled(days.contains(today))
            }.font(.subheadline.weight(.semibold))
            HStack(spacing: NativeDesign.Space.xxs) {
                ForEach(days, id: \.self) { day in
                    let current = day == today
                    let selection = day == selectedDate
                    let accent = store.shift(CivilDate.day(day))?.color ?? NativeDesign.accent
                    Button { selectedDate = day } label: {
                        VStack(spacing: NativeDesign.Space.xxs) {
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2)
                            Text(day.formatted(.dateTime.day())).font(.subheadline.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(current ? (store.shift(CivilDate.day(day)) == nil ? NativeDesign.onAccent : Color.black) : .primary)
                                .frame(width: NativeDesign.Layout.calendarDayNumber, height: NativeDesign.Layout.calendarDayNumber)
                                .background(current ? accent : .clear, in: Circle())
                                .overlay(Circle().strokeBorder(selection && !current ? NativeDesign.accent : .clear))
                        }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
                            .contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle())
                        .disabled(day > today)
                        .opacity(day > today ? 0.45 : 1)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityIdentifier("health-date-" + CivilDate.day(day))
                        .accessibilityAddTraits(selection ? .isSelected : [])
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                let movement = value.translation
                guard abs(movement.width) > abs(movement.height) * 1.3 else { return }
                moveWeek(movement.width < 0 ? 1 : -1)
            })
        }.accessibilityIdentifier("health-week-picker")
    }

    private func moveWeek(_ offset: Int) {
        guard let next = NativeHealthWeek.moving(selectedDate, weeks: offset) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.selectionDuration)) { selectedDate = next }
    }

    private var nutrients: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Nutrienti").font(.headline).foregroundStyle(NativeDesign.nutritionTitle)
            NativeNutrientValues(health: health, includesFibre: true, date: selectedDate)
            Divider().padding(.vertical, NativeDesign.Space.xs)
            NativePinnedNutrients(entries: nutrition.entries, date: selectedDate)
            NavigationLink {
                NativeMicronutrientScreen(nutrition: nutrition, selectedDate: selectedDate)
            } label: {
                HStack {
                    Text("Micronutrienti").font(.subheadline.weight(.semibold))
                    Spacer()
                    NativeDisclosureIndicator()
                }
                .frame(minHeight: NativeDesign.Layout.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(NativePressStyle())
            .accessibilityIdentifier("health-micronutrients")
        }.padding(NativeDesign.Layout.compactCardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
    }
    private var nutritionActionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NativeDesign.Space.small) { nutritionActions }
                .fixedSize(horizontal: true, vertical: false)
            VStack(spacing: NativeDesign.Space.small) { nutritionActions }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NativeDesign.Layout.listInset)
        .padding(.vertical, NativeDesign.Space.small)
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
        }
            .padding(.horizontal, NativeDesign.Layout.compactCardInset)
            .padding(.bottom, NativeDesign.Layout.compactCardInset)
            .padding(.top, NativeDesign.Space.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
    }

    private struct DiaryRow: Identifiable {
        let id: UUID
        let name: String
        let date: Date
        let source: String
        let calories: Double
        var grams: Decimal? = nil
        var weighedWithBone = false
        var detail: String {
            let time = date.formatted(.dateTime.hour().minute())
            let portion = grams.map { NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...1))) + (weighedWithBone ? " g con osso" : " g") }
            return [time, portion, source].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private var diaryRows: [DiaryRow] {
        let local = nutrition.entries.filter {
            $0.confirmed && $0.deletionPending != true && Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
        let localIDs = Set(local.map(\.id))
        let imported = health.foodEntries(on: selectedDate).compactMap { sample -> DiaryRow? in
            if let id = sample.lifeOSID, localIDs.contains(id) { return nil }
            return DiaryRow(id: sample.id, name: sample.name ?? "Energia alimentare", date: sample.date,
                source: sample.lifeOSID == nil ? "Apple Salute" : "LifeOS", calories: sample.calories)
        }
        return (imported + local.map {
            DiaryRow(id: $0.id, name: $0.foodName ?? "Energia alimentare", date: $0.date,
                source: "LifeOS", calories: NSDecimalNumber(decimal: $0.calories).doubleValue, grams: $0.boneInWeightGrams ?? $0.portionGrams,
                weighedWithBone: $0.boneInWeightGrams != nil)
        }).sorted { $0.date > $1.date }
    }

    private func context(_ metric: NativeHealthMetric) -> String {
        switch metric {
        case .tdee: return "Ultimi 14 giorni"
        case .weight: return health.days.last(where: { $0.weight != nil })?.date.formatted(date: .abbreviated, time: .omitted) ?? "Ultima pesata"
        case .calories: return selectedDate.formatted(date: .abbreviated, time: .omitted)
        case .weeklyCalories, .weeklyProtein: return "Settimana selezionata"
        case .simulation:
            return Calendar.current.date(byAdding: .month, value: 1, to: Date())?.formatted(date: .abbreviated, time: .omitted) ?? "Tra un mese"
        }
    }
    private func value(_ metric: NativeHealthMetric) -> String {
        let number: Double?
        switch metric {
        case .tdee: number = health.estimate.map { ($0.tdee / 50).rounded() * 50 }
        case .weight: number = health.days.last(where: { $0.weight != nil })?.weight
        case .calories: number = health.calories(on: selectedDate)
        case .weeklyCalories:
            number = NativeHealthMath.mean(NativeHealthWeek.days(containing: selectedDate).compactMap { health.calories(on: $0) })
        case .weeklyProtein:
            number = NativeHealthMath.mean(NativeHealthWeek.days(containing: selectedDate).compactMap { health.nutrients(on: $0)[.dietaryProtein] })
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
    var date = Date()
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
        let value = health.nutrients(on: date)[type].map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—"
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
