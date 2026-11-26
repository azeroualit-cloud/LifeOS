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
        NativeDesign.nutritionTitle // SALUTE-REDESIGN-2026-11-26: one green for all of Salute
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
    @State private var editingFood: NativeNutritionEntry?
    @State private var deleteAfterEdit: UUID?
    @State private var diaryNotice: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current

    @State private var period: NativeHealthTrendPeriod = .three
    @State private var editingGoals = false
    @State private var showingStats = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                // HEALTH-TREND-93-2026-11-21: day first, then the trend over months.
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    weekPicker
                    if demo { Text("Dati illustrativi").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                    caloriesCard
                    nutrients
                }
                diary
                // SALUTE-SINGLE-ENTRY-2026-11-26: one door per section (Obiettivi e statistiche, Cronologia).
                sectionsCard
                if nutrition.entries.contains(where: { !$0.confirmed || $0.deletionPending == true }) {
                    Text("Registrazioni LifeOS in sospeso: consultale nella cronologia.")
                        .font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
                if let message = health.nutrientMessage { Text(message).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                if health.loading { ProgressView().accessibilityLabel("Lettura Salute") }
                if let message = health.message { Text(message).font(.footnote).foregroundStyle(NativeDesign.secondary) }
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
            .navigationDestination(isPresented: $showingStats) { statsScreen }
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
            // REVIEW-95: no empty navigation bar above "Oggi"; the history button sits in the day row.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $addingWeight) { NativeAddWeightSheet(health: health) }
            .sheet(isPresented: $editingGoals) { NativeNutritionGoalsSheet(health: health) }
            .sheet(isPresented: $showingNutrition) { NativeFoodQuickAddSheet(initialDate: selectedDate).environmentObject(health) }
            // FOOD-LOG-EDIT-2026-11-25: quantity and time of a logged food, without deleting it.
            // «Elimina registrazione» asks for confirmation only after the sheet has gone.
            .sheet(item: $editingFood, onDismiss: { if let id = deleteAfterEdit { deleteAfterEdit = nil; deletingFood = id } }) { entry in
                NavigationStack { NativeFoodLogEditSheet(entry: entry) { deleteAfterEdit = entry.id } }.environmentObject(health)
            }
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

    /// Calories of the selected day (Fitia-like, user request 22/11/2026): centred value over
    /// the goal, an arc with the recommended range, then the three macros in centred columns.
    /// Built from small views so the type checker stays fast.
    private var caloriesCard: some View {
        NativeCard(density: .compact) {
            caloriesHeader
            caloriesMacros
        }
    }
    private var caloriesSpoken: String {
        let targets = health.goalTargets
        let calories = health.calories(on: selectedDate)
        let kcal: String = calories.map(whole) ?? "—"
        var text: String = "Calorie " + kcal
        if let targets {
            text += " di " + whole(targets.calories)
            if let calories {
                let remaining: Double = targets.calories - calories
                text += remaining >= 0 ? ", restano " + whole(remaining) : ", oltre di " + whole(-remaining)
            }
        } else {
            text += ", imposta un obiettivo"
        }
        return text + ". Apri obiettivi"
    }
    private var caloriesHeader: some View {
        let goal: Double? = health.goalTargets?.calories
        let calories: Double? = health.calories(on: selectedDate)
        let kcal: String = calories.map(whole) ?? "—"
        return Button { showingStats = true } label: {
            VStack(spacing: NativeDesign.Space.none) {
                Text("kcal").font(.footnote).foregroundStyle(NativeDesign.secondary)
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                    Text(kcal).font(.title.weight(.bold)).monospacedDigit()
                    if let goal {
                        Text("/ " + whole(goal)).font(.title.weight(.bold))
                            .foregroundStyle(NativeDesign.secondary).monospacedDigit()
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                NativeCalorieGauge(calories: calories, goal: goal)
            }
            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caloriesSpoken)
        .accessibilityIdentifier("health-calories-goals")
    }
    private var caloriesMacros: some View {
        let targets = health.goalTargets
        let values = health.nutrients(on: selectedDate)
        let centered: Bool = !typeSize.isAccessibilitySize
        let layout: AnyLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.small))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NativeDesign.Space.medium))
        return layout {
            macro("Proteine", values[.dietaryProtein], targets?.protein, NativeDesign.macroProtein, .dietaryProtein, centered)
            macro("Carboidrati", values[.dietaryCarbohydrates], targets?.carbohydrate, NativeDesign.nutritionTitle.opacity(0.75), .dietaryCarbohydrates, centered)
            macro("Grassi", values[.dietaryFatTotal], targets?.fat, NativeDesign.nutritionTitle.opacity(0.55), .dietaryFatTotal, centered)
        }
    }
    private func macro(_ title: String, _ value: Double?, _ goal: Double?, _ fallback: Color,
                       _ type: HKQuantityTypeIdentifier, _ centered: Bool) -> LOMacroValue {
        LOMacroValue(title: title, value: value, goal: goal, unit: "g", color: macroColor(value, goal, fallback),
                     identifier: "health-nutrient-" + type.rawValue, centered: centered)
    }

    /// Macro bar colour carries the meaning when there is a goal: green in range, amber under, orange over.
    private func macroColor(_ value: Double?, _ goal: Double?, _ fallback: Color) -> Color {
        NativeCalorieBand.macroColor(value, goal: goal, base: fallback, limit: fallback == NativeDesign.macroProtein ? NativeNutritionLimits.protein : NativeNutritionLimits.macro)
    }

    /// The two doors of Salute below the day (SALUTE-SINGLE-ENTRY-2026-11-26).
    private var sectionsCard: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Sezioni")
            LOListCard {
                sectionRow("Obiettivi e statistiche", detail: "peso e simulazione · TDEE · calorie · obiettivi", symbol: "chart.xyaxis.line",
                           identifier: "health-open-stats", isLast: false) { showingStats = true }
                sectionRow("Cronologia", detail: "tutti i giorni registrati", symbol: "list.bullet.rectangle",
                           identifier: "health-nutrition-history", isLast: true) { showingHistory = true }
            }
        }
    }
    private func sectionRow(_ title: String, detail: String, symbol: String, identifier: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LOListRow(isLast: isLast) {
                Label { VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(2)
                } } icon: { Image(systemName: symbol).foregroundStyle(NativeDesign.nutritionTitle) }
                Spacer(minLength: NativeDesign.Space.small)
                NativeDisclosureIndicator()
            }.contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    /// Obiettivi e statistiche: everything about goals, weight, simulation, TDEE and calories in one place.
    private var statsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                goalsCard
                trendSection
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
        }
        .background(NativeDesign.healthCanvas)
        // Same identifier as the Salute page: a pushed screen replaces it in the hierarchy, so UI tests keep one scroll.
        .accessibilityIdentifier("health-detail-scroll")
        .navigationTitle("Obiettivi e statistiche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
    private var goalsCard: some View {
        let targets = health.goalTargets
        let fibre = NativeHub95.shared.fibreGoal ?? NativeHub95.defaultFibre
        return NativeCard {
            LOCardHeader(title: "Obiettivi", systemImage: "target", section: .nutrition)
            if let targets {
                VStack(spacing: NativeDesign.Space.xs) {
                    goalRow("Calorie", whole(targets.calories) + " kcal")
                    goalRow("Proteine", whole(targets.protein) + " g")
                    goalRow("Carboidrati", whole(targets.carbohydrate) + " g")
                    goalRow("Grassi", whole(targets.fat) + " g")
                    goalRow("Fibre", whole(fibre) + " g")
                }
            } else {
                Text("Nessun obiettivo impostato").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
            Button("Modifica obiettivi") { editingGoals = true }
                .buttonStyle(LOGlassButtonStyle(fillsWidth: true))
                .accessibilityIdentifier("health-edit-goals")
        }
    }
    private func goalRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer(minLength: NativeDesign.Space.small)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }.accessibilityElement(children: .combine)
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
            Text("Andamento").font(.title.bold()).accessibilityAddTraits(.isHeader)
            LOSegmented(options: NativeHealthTrendPeriod.allCases.map { (title: $0.title, id: String($0.rawValue)) }, selection: Binding(
                get: { period.title }, set: { title in period = NativeHealthTrendPeriod.allCases.first { $0.title == title } ?? .three }),
                identifierPrefix: "health-period-")
            rowLayout {
                LOStatCard(title: "Peso", value: latest ?? "—", unit: "kg",
                    caption: summary.latestWeightDate.map { $0.formatted(.dateTime.day().month(.abbreviated)) }, color: NativeDesign.nutritionTitle,
                    identifier: "health-summary-weight", action: { openedMetric = .weight })
                LOStatCard(title: "TDEE", value: value(.tdee), unit: "kcal", caption: health.estimate.map { "ultimi \($0.days) giorni" },
                    color: NativeDesign.nutritionTitle, identifier: "health-summary-tdee", action: { openedMetric = .tdee })
            }
            rowLayout {
                LOStatCard(title: "Media calorie", value: summary.averageCalories.map(whole) ?? "—", unit: "kcal",
                    caption: period.title, color: NativeDesign.nutritionTitle, identifier: "health-summary-weeklyCalories")
                LOStatCard(title: "Media proteine", value: summary.averageProtein.map(whole) ?? "—", unit: "g",
                    caption: period.title, color: NativeDesign.macroProtein, identifier: "health-summary-weeklyProtein")
            }
            LOLinkCard(title: "Peso e simulazione", trailing: latest.map { $0 + " kg" },
                color: NativeDesign.nutritionTitle, identifier: "health-summary-simulation",
                accessibilityLabel: simulationLabel, action: { openedMetric = .simulation }) {
                NativeWeightTrendChart(days: health.days, forecast: forecast, start: start)
                HStack {
                    if let change { Text(change).font(.footnote).foregroundStyle(NativeDesign.secondary) }
                    Spacer()
                    if let expected { Text(expected).font(.footnote).foregroundStyle(NativeDesign.nutritionTitle) }
                }.monospacedDigit()
            }
            LOLinkCard(title: "Calorie per giorno", trailing: weekMean.map { "media " + whole($0) },
                color: NativeDesign.nutritionTitle, identifier: "health-summary-calories",
                accessibilityLabel: caloriesLabel, action: { openedMetric = .calories }) {
                NativeWeekCaloriesChart(week: week, calories: { health.calories(on: $0) }, goal: health.goalTargets?.calories, selected: selectedDate)
            }
        }
    }

    /// Fitia-like week (user request 22/11/2026): no card; the day as title with the week arrows;
    /// weekday letters with the selected one in a filled circle, the date, and a dot per day
    /// coloured by the calorie goal band (grey: nothing logged).
    private var weekPicker: some View {
        let calendar = NativeHealthWeek.calendar
        let today = calendar.startOfDay(for: .now)
        let days = NativeHealthWeek.days(containing: selectedDate)
        let goal = health.goalTargets?.calories
        let isToday = selectedDate == today
        let title = isToday ? "Oggi" : selectedDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).capitalized(with: Locale(identifier: "it_IT"))
        return VStack(spacing: NativeDesign.Space.xs) {
            HStack(spacing: NativeDesign.Space.xs) {
                Button { selectedDate = today } label: {
                    HStack(spacing: NativeDesign.Space.xs) {
                        Text(title).font(.title.bold()).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                        if !isToday {
                            Image(systemName: "arrow.uturn.backward").font(.footnote.weight(.semibold)).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NativePressStyle())
                .disabled(isToday)
                .accessibilityLabel(isToday ? "Oggi" : title + ", torna a oggi")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(isToday ? "health-selected-day" : "health-week-today")
                Spacer(minLength: NativeDesign.Space.none)
                NativeIconButton(symbol: "chevron.left", label: "Settimana precedente") { moveWeek(-1) }
                    .accessibilityIdentifier("health-week-previous")
                NativeIconButton(symbol: "chevron.right", label: "Settimana successiva") { moveWeek(1) }
                    .accessibilityIdentifier("health-week-next")
                    .disabled(days.contains(today))
            }
            HStack(spacing: NativeDesign.Space.xxs) {
                ForEach(days, id: \.self) { day in
                    let selection = day == selectedDate
                    let band = NativeCalorieBand.of(health.calories(on: day), goal: goal)
                    Button { selectedDate = day } label: {
                        VStack(spacing: NativeDesign.Space.xxs) {
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.footnote.weight(.semibold))
                                .foregroundStyle(selection ? Color(uiColor: .systemBackground) : NativeDesign.secondary)
                                .frame(width: NativeDesign.Layout.calendarDayNumber, height: NativeDesign.Layout.calendarDayNumber)
                                .background { if selection { Circle().fill(Color.primary) } }
                            Text(day.formatted(.dateTime.day())).font(.subheadline.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(day == today ? NativeDesign.nutritionTitle : Color.primary)
                                .lineLimit(1).minimumScaleFactor(0.55)
                            Circle().fill(day > today ? Color.clear : band.color)
                                .frame(width: NativeDesign.Space.small - 2, height: NativeDesign.Space.small - 2)
                        }
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NativePressStyle())
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
                LOCardHeader(title: "Micronutrienti", systemImage: "leaf.fill", section: .nutrition, showsChevron: true, trailing: "in evidenza")
                    .contentShape(Rectangle().inset(by: -NativeDesign.Space.medium)) // 44 pt touch without 44 pt of layout
            }
            .buttonStyle(NativePressStyle())
            .accessibilityLabel("Tutti i micronutrienti")
            .accessibilityIdentifier("health-micronutrients")
            // FIBRE-GOAL-2026-11-24: fibre against its goal, with a bar like the other nutrients.
            let fibreGoal = NativeHub95.shared.fibreGoal ?? NativeHub95.defaultFibre
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                HStack(spacing: NativeDesign.Space.small) {
                    Text("Fibre").font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    Text((fibre.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—") + " / " + fibreGoal.formatted(.number.precision(.fractionLength(0))) + " g")
                        .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
                ProgressView(value: min(1, (fibre ?? 0) / max(1, fibreGoal))).tint(NativeDesign.nutritionTitle).accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("health-nutrient-" + HKQuantityTypeIdentifier.dietaryFiber.rawValue)
            NativePinnedNutrients(entries: nutrition.entries, date: selectedDate)
        }
    }
    /// Liquid Glass actions above the tab bar: Peso left, Alimento right, as in the Dashboard.
    @ViewBuilder private var nutritionActions: some View {
        Button { addingWeight = true } label: {
            LOActionLabel(title: "Peso", systemImage: NativeHealthMetric.weight.symbol, section: .nutrition)
        }.buttonStyle(LOGlassButtonStyle(fillsWidth: true)).accessibilityLabel("Aggiungi peso").accessibilityIdentifier("health-add-weight")
        Button { showingNutrition = true } label: {
            LOActionLabel(title: "Alimento", systemImage: NativeHealthMetric.calories.symbol, section: .nutrition)
        }.buttonStyle(LOGlassButtonStyle(fillsWidth: true)).accessibilityLabel("Aggiungi alimento").accessibilityIdentifier("health-add-nutrition")
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
                // FOOD-QUICK-ADD-2026-11-23: copy yesterday's foods to this day in one tap.
                let yesterday = NativeNutritionHistory.foods(on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate, entries: nutrition.entries).filter { $0.deletionPending != true }
                if !yesterday.isEmpty {
                    Button { repeatFoods(yesterday) } label: {
                        LOListRow(isLast: rows.isEmpty) {
                            Label("Copia da ieri · " + String(yesterday.count) + (yesterday.count == 1 ? " alimento" : " alimenti"), systemImage: "arrow.uturn.forward")
                                .font(.subheadline).foregroundStyle(NativeDesign.nutritionTitle)
                            Spacer(minLength: 0)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(NativePressStyle())
                    .disabled(nutrition.busy)
                    .accessibilityIdentifier("health-diary-copy-yesterday")
                }
                ForEach(rows) { row in
                    let editable = row.localID.flatMap { id in row.deletionPending ? nil : nutrition.entries.first(where: { $0.id == id }) }
                    LOListRow(isLast: row.id == rows.last?.id) {
                        // FOOD-LOG-EDIT-2026-11-25: tapping the name or the kcal opens Modifica. A tap gesture (not a
                        // Button) keeps the texts visible to VoiceOver and to the UI tests that look them up.
                        HStack(spacing: NativeDesign.Space.small) {
                                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                    Text(row.name).font(.subheadline).lineLimit(2).foregroundStyle(.primary)
                                    Text(row.detail).font(.footnote).foregroundStyle(NativeDesign.secondary)
                                    if row.deletionPending {
                                        Text("Eliminazione da completare").font(.footnote).foregroundStyle(NativeDesign.overGoal)
                                    }
                                }
                                Spacer(minLength: NativeDesign.Space.small)
                                Text(row.calories.map { $0.formatted(.number.precision(.fractionLength(0))) + " kcal" } ?? "— kcal")
                                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
                        }
                        .frame(minHeight: NativeDesign.Layout.touchTarget).contentShape(Rectangle())
                        .onTapGesture { if let editable, !nutrition.busy { editingFood = editable } }
                        .accessibilityElement(children: .contain)
                        .accessibilityAction(named: Text("Modifica quantità e ora")) { if let editable, !nutrition.busy { editingFood = editable } }
                        .accessibilityIdentifier("health-diary-edit-" + (row.localID?.uuidString ?? row.id.uuidString))
                        if let localID = row.localID, !row.deletionPending, let entry = nutrition.entries.first(where: { $0.id == localID }) {
                            NativeIconButton(symbol: "arrow.uturn.forward", label: "Ripeti oggi " + row.name) { repeatFoods([entry], on: .now) }
                                .disabled(nutrition.busy)
                                .accessibilityIdentifier("health-diary-repeat-" + localID.uuidString)
                        }
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
            if let diaryNotice { Text(diaryNotice).font(.footnote).foregroundStyle(NativeDesign.secondary) }
            if let error = nutrition.error { Text(error).font(.footnote).foregroundStyle(NativeDesign.danger) }
        }
    }

    /// Saves copies one by one (the store accepts one write at a time) and refreshes Apple Health once.
    private func repeatFoods(_ entries: [NativeNutritionEntry], on day: Date? = nil) {
        let target = day ?? selectedDate
        Task {
            var saved = 0
            for entry in entries.sorted(by: { $0.date < $1.date }) { if await nutrition.save(entry.repeated(on: target)) { saved += 1 } }
            diaryNotice = saved == entries.count ? (saved == 1 ? "Alimento ripetuto." : String(saved) + " alimenti copiati.") : "Copiati " + String(saved) + " di " + String(entries.count) + ". Riprova per gli altri."
            await health.refresh()
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
            Text(title).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
            Text(metric.title).font(.footnote.weight(.semibold)).foregroundStyle(metric.color)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) { amountText; unitText }.fixedSize()
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { amountText; unitText }
            }
        }.padding(.horizontal, NativeDesign.Layout.compactCardInset).padding(.vertical, NativeDesign.Layout.cardInsetVertical)
            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, maxHeight: .infinity, alignment: .topLeading)
            .background(NativeDesign.healthSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.title + ", " + value + " " + metric.unit + ", " + contextLabel)
            .accessibilityHint(metric == .weeklyCalories || metric == .weeklyProtein ? "" : "Apre il dettaglio")
    }
    private var amountText: some View {
        Text(value).font(.title.weight(.bold)).foregroundStyle(.primary).monospacedDigit()
    }
    private var unitText: some View {
        Text(metric.unit).font(.footnote).foregroundStyle(.secondary)
    }
}
