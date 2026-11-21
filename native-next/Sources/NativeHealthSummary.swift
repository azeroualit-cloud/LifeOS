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
    @State private var showingMicronutrients = false
    @State private var showingHistory = false
    @State private var openedMetric: NativeHealthMetric?
    @State private var showingNutrition = false
    @State private var deletingFood: UUID?
    @State private var diaryNotice: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current

    @State private var period: NativeHealthTrendPeriod = .three
    @State private var editingGoals = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                // HEALTH-TREND-93-2026-11-21: day first, then the trend over months.
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    weekPicker
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day()).capitalized(with: Locale(identifier: "it_IT")))
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("health-selected-day")
                    if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(NativeDesign.secondary) }
                    caloriesCard
                    nutrients
                }
                diary
                trendSection
                if nutrition.entries.contains(where: { !$0.confirmed || $0.deletionPending == true }) {
                    Text("Registrazioni LifeOS in sospeso: consultale nella cronologia.")
                        .font(.caption).foregroundStyle(NativeDesign.secondary)
                }
                if let message = health.nutrientMessage { Text(message).font(.caption).foregroundStyle(NativeDesign.secondary) }
                if health.loading { ProgressView().accessibilityLabel("Lettura Salute") }
                if let message = health.message { Text(message).font(.caption).foregroundStyle(NativeDesign.secondary) }
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
        }
            .accessibilityIdentifier("health-detail-scroll")
            .task { await NativeNutritionUIFixture.prepareReview() }
            .refreshable { await health.refresh() }
            .loBottomActions { nutritionActions }
            .navigationDestination(isPresented: $showingMicronutrients) {
                NativeMicronutrientScreen(nutrition: nutrition, selectedDate: selectedDate)
            }
            .navigationDestination(isPresented: $showingHistory) { NativeNutritionScreen() }
            .navigationDestination(item: $openedMetric) { metric in
                switch metric {
                case .tdee: NativeTDEEScreen(health: health)
                case .simulation: NativeWeightSimulationScreen(health: health)
                default: NativeHealthMetricDetail(metric: metric, health: health, demo: demo)
                }
            }
            .background(NativeDesign.healthCanvas)
            .navigationTitle("Salute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // History in the navigation bar: always reachable, never under the bottom actions.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingHistory = true } label: {
                        Label("Cronologia", systemImage: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("Cronologia nutrizione")
                    .accessibilityIdentifier("health-nutrition-history")
                }
            }
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $editingGoals) { NativeNutritionGoalsSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NavigationStack { NativeNutritionQuickSheet(initialDate: selectedDate) }.environmentObject(health) }
            .confirmationDialog("Eliminare questa registrazione e i suoi campioni LifeOS da Apple Salute?", isPresented: Binding(get: { deletingFood != nil }, set: { if !$0 { deletingFood = nil } })) {
                Button("Elimina da LifeOS e Apple Salute", role: .destructive) {
                    if let id = deletingFood { removeFood(id) }
                    deletingFood = nil
                }
                Button("Annulla", role: .cancel) { deletingFood = nil }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await health.refresh() } }
            }

    }

    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }

    /// Calories of the selected day against the goal, split by macro (preview top card).
    private var caloriesCard: some View {
        let targets = health.goalTargets
        let values = health.nutrients(on: selectedDate)
        let protein = values[.dietaryProtein], carbohydrate = values[.dietaryCarbohydrates], fat = values[.dietaryFatTotal]
        let calories = health.calories(on: selectedDate)
        let kcal = calories.map(whole) ?? "—"
        let remaining: Double? = targets.flatMap { goal in calories.map { goal.calories - $0 } }
        let detail: String
        if let targets {
            if let remaining {
                detail = "/ " + whole(targets.calories) + (remaining >= 0 ? " · restano " : " · oltre di ") + whole(abs(remaining))
            } else { detail = "/ " + whole(targets.calories) }
        } else { detail = "Imposta un obiettivo" }
        let over = (remaining ?? 0) < 0
        let split = [LOSegment(id: "p", value: (protein ?? 0) * 4, color: NativeDesign.macroProtein),
                     LOSegment(id: "c", value: (carbohydrate ?? 0) * 4, color: NativeDesign.macroCarbohydrate),
                     LOSegment(id: "f", value: (fat ?? 0) * 9, color: NativeDesign.macroFat)]
        let splitTotal = split.map(\.value).reduce(0, +)
        let spokenSplit = "Calorie divise per macro: proteine " + whole((protein ?? 0) * 4) + ", carboidrati " + whole((carbohydrate ?? 0) * 4) + ", grassi " + whole((fat ?? 0) * 9)
        let macroLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.small))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NativeDesign.Space.medium))
        return NativeCard {
            Button { editingGoals = true } label: {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    HStack {
                        Text("Calorie").font(.footnote.weight(.semibold)).foregroundStyle(NativeDesign.nutritionTitle)
                        Spacer()
                        NativeDisclosureIndicator()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                        Text(kcal).font(.title2.weight(.bold)).monospacedDigit()
                        Text(detail).font(.footnote).foregroundStyle(over ? NativeDesign.overGoal : NativeDesign.secondary)
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(NativePressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calorie " + kcal + (targets.map { " di " + whole($0.calories) } ?? "") + ". Apri obiettivi")
            .accessibilityIdentifier("health-calories-goals")
            LOSplitBar(segments: split, scale: max(targets?.calories ?? 0, splitTotal, 1), accessibilityText: spokenSplit)
            macroLayout {
                LOMacroValue(title: "Proteine", value: protein, goal: targets?.protein, unit: "g", color: NativeDesign.macroProtein, identifier: "health-nutrient-" + HKQuantityTypeIdentifier.dietaryProtein.rawValue)
                LOMacroValue(title: "Carboidrati", value: carbohydrate, goal: targets?.carbohydrate, unit: "g", color: NativeDesign.macroCarbohydrate, identifier: "health-nutrient-" + HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue)
                LOMacroValue(title: "Grassi", value: fat, goal: targets?.fat, unit: "g", color: NativeDesign.macroFat, identifier: "health-nutrient-" + HKQuantityTypeIdentifier.dietaryFatTotal.rawValue)
            }
        }
    }

    /// Andamento: period, four values, weight with forecast, calories of the week.
    private var trendSection: some View {
        let protein = health.nutrientsByDay.compactMapValues { $0[.dietaryProtein] }
        let summary = NativeHealthTrendSummary(days: health.days, protein: protein, period: period)
        let start = period.start()
        let forecast = self.forecast
        let week = NativeHealthWeek.days(containing: selectedDate)
        let weekMean = NativeHealthMath.mean(week.compactMap { health.calories(on: $0) }.filter { $0 > 0 })
        // Not lazy: every value exists for VoiceOver and UI tests even below the fold.
        let rowLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.medium))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NativeDesign.Space.medium))
        let change: String? = summary.weightChange.map { ($0 >= 0 ? "+" : "−") + abs($0).formatted(.number.precision(.fractionLength(1))) + " kg in " + period.shortTitle }
        let expected: String? = forecast.last.map { "previsto " + $0.value.formatted(.number.precision(.fractionLength(1))) + " kg al " + $0.date.formatted(.dateTime.day().month(.abbreviated)) }
        let latest: String? = summary.latestWeight.map { $0.formatted(.number.precision(.fractionLength(1))) }
        let simulationLabel = ["Peso e simulazione", value(.simulation) + " kg previsti", change].compactMap { $0 }.joined(separator: ", ")
        let caloriesLabel = "Calorie per giorno, " + value(.calories) + " kcal il giorno selezionato" + (weekMean.map { ", media della settimana " + whole($0) } ?? "")
        return VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            Text("Andamento").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            LOSegmented(options: NativeHealthTrendPeriod.allCases.map { (title: $0.title, id: String($0.rawValue)) }, selection: Binding(
                get: { period.title }, set: { title in period = NativeHealthTrendPeriod.allCases.first { $0.title == title } ?? .three }),
                identifierPrefix: "health-period-")
            rowLayout {
                LOStatCard(title: "Peso", value: latest ?? "—", unit: "kg",
                    caption: summary.latestWeightDate.map { $0.formatted(.dateTime.day().month(.abbreviated)) }, color: NativeDesign.healthWeight,
                    identifier: "health-summary-weight", action: { openedMetric = .weight })
                LOStatCard(title: "TDEE", value: value(.tdee), unit: "kcal", caption: health.estimate.map { "ultimi \($0.days) giorni" },
                    color: NativeDesign.macroCarbohydrate, identifier: "health-summary-tdee", action: { openedMetric = .tdee })
            }
            rowLayout {
                LOStatCard(title: "Media calorie", value: summary.averageCalories.map(whole) ?? "—", unit: "kcal",
                    caption: period.title, color: NativeDesign.nutritionTitle, identifier: "health-summary-weeklyCalories")
                LOStatCard(title: "Media proteine", value: summary.averageProtein.map(whole) ?? "—", unit: "g",
                    caption: period.title, color: NativeDesign.macroProtein, identifier: "health-summary-weeklyProtein")
            }
            LOLinkCard(title: "Peso e simulazione", trailing: latest.map { $0 + " kg" },
                color: NativeDesign.healthWeight, identifier: "health-summary-simulation",
                accessibilityLabel: simulationLabel, action: { openedMetric = .simulation }) {
                NativeWeightTrendChart(days: health.days, forecast: forecast, start: start)
                HStack {
                    if let change { Text(change).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                    Spacer()
                    if let expected { Text(expected).font(.footnote).foregroundStyle(NativeDesign.estimate) }
                }.monospacedDigit()
            }
            LOLinkCard(title: "Calorie per giorno", trailing: weekMean.map { "media " + whole($0) },
                color: NativeDesign.nutritionTitle, identifier: "health-summary-calories",
                accessibilityLabel: caloriesLabel, action: { openedMetric = .calories }) {
                NativeWeekCaloriesChart(week: week, calories: { health.calories(on: $0) }, goal: health.goalTargets?.calories, selected: selectedDate)
            }
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
            if selectedDate != today {
                Button("Oggi") { selectedDate = today }
                    .buttonStyle(NativePressStyle())
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                    .accessibilityIdentifier("health-week-today")
            }
            HStack(spacing: NativeDesign.Space.xxs) {
                ForEach(days, id: \.self) { day in
                    let current = day == today
                    let selection = day == selectedDate
                    let accent = store.shift(CivilDate.day(day))?.color ?? NativeDesign.accent
                    Button { selectedDate = day } label: {
                        VStack(spacing: NativeDesign.Space.xxs) {
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2)
                            Text(day.formatted(.dateTime.day())).font(.subheadline.weight(.semibold)).monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
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
        }
    }

    private func moveWeek(_ offset: Int) {
        guard let next = NativeHealthWeek.moving(selectedDate, weeks: offset) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.selectionDuration)) { selectedDate = next }
    }

    /// "Micronutrienti · in evidenza": fibre plus the starred micronutrients (preview card).
    private var nutrients: some View {
        let fibre = health.nutrients(on: selectedDate)[.dietaryFiber]
        return NativeCard {
            // Programmatic push: closure links stop working next to navigationDestination(item:).
            Button { showingMicronutrients = true } label: {
                HStack {
                    Text("Micronutrienti · in evidenza").font(.footnote.weight(.semibold)).foregroundStyle(NativeDesign.nutritionTitle)
                    Spacer()
                    NativeDisclosureIndicator()
                }
                .frame(minHeight: NativeDesign.Layout.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(NativePressStyle())
            .accessibilityLabel("Tutti i micronutrienti")
            .accessibilityIdentifier("health-micronutrients")
            HStack(spacing: NativeDesign.Space.medium) {
                Text("Fibre").font(.subheadline)
                Spacer()
                Text(fibre.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " g" } ?? "—")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("health-nutrient-" + HKQuantityTypeIdentifier.dietaryFiber.rawValue)
            NativePinnedNutrients(entries: nutrition.entries, date: selectedDate)
        }
    }
    /// Liquid Glass actions above the tab bar (G06 icons, UI-80-01 visible text).
    @ViewBuilder private var nutritionActions: some View {
        Button { showingNutrition = true } label: {
            LOActionLabel(title: "Alimento", systemImage: NativeHealthMetric.calories.symbol, section: .nutrition)
        }.buttonStyle(LOGlassButtonStyle(fillsWidth: true)).accessibilityLabel("Aggiungi alimento").accessibilityIdentifier("health-add-nutrition")
        Button { addingWeight = true } label: {
            LOActionLabel(title: "Peso", systemImage: NativeHealthMetric.weight.symbol, section: .weight)
        }.buttonStyle(LOGlassButtonStyle(fillsWidth: true)).accessibilityLabel("Aggiungi peso").accessibilityIdentifier("health-add-weight")
    }
    /// DIARIO: rows in one grouped card, kcal on the right (preview list).
    private var diary: some View {
        let rows = diaryRows
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Diario")
            LOListCard {
                if rows.isEmpty {
                    LOListRow(isLast: true) {
                        Text("Nessun alimento registrato per questo giorno").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                    }
                }
                ForEach(rows) { row in
                    LOListRow(isLast: row.id == rows.last?.id) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(row.name).font(.body).lineLimit(2)
                            Text(row.detail).font(.footnote).foregroundStyle(NativeDesign.secondary)
                            if row.deletionPending {
                                Text("Eliminazione da completare").font(.footnote).foregroundStyle(NativeDesign.overGoal)
                            }
                        }
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(row.calories.map { $0.formatted(.number.precision(.fractionLength(0))) + " kcal" } ?? "— kcal")
                            .font(.body.weight(.semibold)).monospacedDigit()
                        if let localID = row.localID {
                            NativeIconButton(symbol: row.deletionPending ? "arrow.clockwise" : "trash", label: row.deletionPending ? "Riprova eliminazione di " + row.name : "Elimina " + row.name) {
                                if row.deletionPending { removeFood(localID) }
                                else { deletingFood = localID }
                            }
                            .disabled(nutrition.busy)
                            .accessibilityIdentifier("health-diary-delete-" + localID.uuidString)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("health-diary-entry-" + row.id.uuidString)
                }
            }
            if nutrition.busy { ProgressView("Aggiornamento diario") }
            if let diaryNotice { Text(diaryNotice).font(.caption).foregroundStyle(NativeDesign.secondary) }
            if let error = nutrition.error { Text(error).font(.caption).foregroundStyle(NativeDesign.danger) }
        }
    }

    private struct DiaryRow: Identifiable {
        let id: UUID
        let name: String
        let date: Date
        let source: String
        let calories: Double?
        var grams: Decimal? = nil
        var weighedWithBone = false
        var quantity: String? = nil
        var localID: UUID? = nil
        var deletionPending = false
        var detail: String {
            let time = date.formatted(.dateTime.hour().minute())
            let portion = grams.map { NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...1))) + (weighedWithBone ? " g con osso" : " g") }
            return [time, quantity ?? portion, source].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private var diaryRows: [DiaryRow] {
        let local = NativeNutritionHistory.foods(on: selectedDate, entries: nutrition.entries)
        let localIDs = Set(local.map(\.id))
        let imported = health.foodEntries(on: selectedDate).compactMap { sample -> DiaryRow? in
            if let id = sample.lifeOSID, localIDs.contains(id) { return nil }
            guard let name = sample.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            return DiaryRow(id: sample.id, name: name, date: sample.date,
                source: sample.lifeOSID == nil ? "Apple Salute" : "LifeOS", calories: sample.calories)
        }
        return (imported + local.map {
            DiaryRow(id: $0.id, name: $0.foodName ?? "Energia alimentare", date: $0.date,
                source: "LifeOS", calories: $0.nutritionNotDeclared == true ? nil : NSDecimalNumber(decimal: $0.calories).doubleValue, grams: $0.boneInWeightGrams ?? $0.portionGrams,
                weighedWithBone: $0.boneInWeightGrams != nil, quantity: $0.boneInWeightGrams == nil ? $0.quantityDescription : nil, localID: $0.id, deletionPending: $0.deletionPending == true)
        }).sorted { $0.date > $1.date }
    }

    private func removeFood(_ id: UUID) {
        diaryNotice = nil
        Task {
            if await nutrition.delete(id) {
                diaryNotice = "Registrazione eliminata da LifeOS e Apple Salute."
                await health.refresh()
            }
        }
    }

    private func context(_ metric: NativeHealthMetric) -> String {
        switch metric {
        case .tdee: return "14 giorni dall’ultima pesata"
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
            .accessibilityHint(metric == .weeklyCalories || metric == .weeklyProtein ? "" : "Apre il dettaglio")
    }
    private var amountText: some View {
        Text(value).font(.title2.weight(.bold)).foregroundStyle(.primary).monospacedDigit()
    }
    private var unitText: some View {
        Text(metric.unit).font(.caption).foregroundStyle(.secondary)
    }
}
