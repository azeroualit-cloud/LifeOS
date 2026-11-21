import SwiftUI
import Charts

/// "TDEE: calcolo e criteri" of the build 93 preview. The criteria change the TDEE
/// used everywhere (goals, simulation, Salute) and are kept on this iPhone.
struct NativeTDEEScreen: View {
    @ObservedObject var health: NativeHealthStore
    @ObservedObject private var preferences = NativeHealthPreferences.shared

    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }

    var body: some View {
        let estimate = health.estimate
        let criteria = preferences.criteria
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    Text(estimate.map { whole(($0.tdee / 10).rounded() * 10) } ?? "Dati insufficienti")
                        .font(.largeTitle.bold()).monospacedDigit()
                        .accessibilityIdentifier("tdee-value")
                    Text("kcal al giorno · ultimi \(criteria.days) giorni").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                }
                .accessibilityElement(children: .combine)
                if let estimate { explanation(estimate, criteria: criteria) }
                criteriaSection(criteria)
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.large)
        }
        .background(NativeDesign.canvas)
        .navigationTitle("TDEE")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("health-detail-scroll")
    }

    private func explanation(_ estimate: HealthEstimate, criteria: NativeTDEECriteria) -> some View {
        // Shown so the rows add up: the adjustment is TDEE minus the mean intake.
        let adjustment = estimate.tdee - estimate.calibrationIntake
        let change = estimate.weightChange
        let missing = estimate.days > 0 ? Double(estimate.imputedDays) / Double(estimate.days) * 100 : 0
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Come esce questo numero")
            LOListCard {
                LOListRow {
                    Text("Media calorie mangiate")
                    Spacer()
                    Text(whole(estimate.calibrationIntake) + " kcal").monospacedDigit()
                }
                LOListRow {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                        Text("Variazione di peso " + (change >= 0 ? "+" : "−") + abs(change).formatted(.number.precision(.fractionLength(1))) + " kg")
                        Text("× " + whole(criteria.energyPerKG) + " kcal per kg ÷ \(estimate.days) giorni").font(.footnote).foregroundStyle(NativeDesign.secondary)
                    }
                    Spacer()
                    Text((adjustment >= 0 ? "+" : "−") + whole(abs(adjustment)) + " kcal").monospacedDigit()
                }
                LOListRow(isLast: true) {
                    Text("TDEE").font(.headline)
                    Spacer()
                    Text(whole(estimate.tdee) + " kcal").font(.headline).monospacedDigit()
                }
            }
            Text(estimate.imputedDays > 0
                 ? "Giorni senza calorie: " + whole(missing) + "%, stimati dalla media."
                 : "Nessun giorno mancante nella finestra.")
                .font(.footnote).foregroundStyle(estimate.imputedDays > 0 ? NativeDesign.warning : NativeDesign.secondary)
                .padding(.horizontal, NativeDesign.Space.large)
                .accessibilityIdentifier("tdee-missing-note")
        }
    }

    private func criteriaSection(_ criteria: NativeTDEECriteria) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Criteri")
            NativeCard {
                LOStepperRow(title: "Finestra", value: "\(criteria.days) giorni",
                    decrement: criteria.days > NativeTDEECriteria.dayRange.lowerBound ? { preferences.criteria.days -= NativeTDEECriteria.dayStep } : nil,
                    increment: criteria.days < NativeTDEECriteria.dayRange.upperBound ? { preferences.criteria.days += NativeTDEECriteria.dayStep } : nil,
                    identifier: "tdee-window")
                Divider()
                LOStepperRow(title: "kcal per kg", value: whole(criteria.energyPerKG),
                    decrement: criteria.energyPerKG > NativeTDEECriteria.energyRange.lowerBound ? { preferences.criteria.energyPerKG -= NativeTDEECriteria.energyStep } : nil,
                    increment: criteria.energyPerKG < NativeTDEECriteria.energyRange.upperBound ? { preferences.criteria.energyPerKG += NativeTDEECriteria.energyStep } : nil,
                    identifier: "tdee-energy")
                Divider()
                LOStepperRow(title: "Giorni mancanti al massimo", value: "\(criteria.maxMissingPercent)%",
                    decrement: criteria.maxMissingPercent > NativeTDEECriteria.missingRange.lowerBound ? { preferences.criteria.maxMissingPercent -= NativeTDEECriteria.missingStep } : nil,
                    increment: criteria.maxMissingPercent < NativeTDEECriteria.missingRange.upperBound ? { preferences.criteria.maxMissingPercent += NativeTDEECriteria.missingStep } : nil,
                    identifier: "tdee-missing")
                Divider()
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    Text("Pendenza del peso").font(.body)
                    LOSegmented(options: [("Mediana", "median"), ("Regressione", "regression")], selection: Binding(
                        get: { criteria.slope == .median ? "Mediana" : "Regressione" },
                        set: { preferences.criteria.slope = $0 == "Mediana" ? .median : .regression }), identifierPrefix: "tdee-slope-")
                }
            }
            Button("Ripristina predefiniti") { preferences.criteria = .standard }
                .buttonStyle(LOGlassButtonStyle(fillsWidth: true))
                .disabled(criteria == .standard)
                .accessibilityIdentifier("tdee-reset")
        }
    }
}

/// "Simulazione peso" of the build 93 preview: real trend or calories, horizon, target.
struct NativeWeightSimulationScreen: View {
    @ObservedObject var health: NativeHealthStore
    @State private var mode: NativeWeightSimulation.Mode = .trend
    @State private var trendWeeks = 4
    @State private var horizon = 4
    @State private var intakeText = ""
    @AppStorage("native-weight-target-93") private var target = 0.0
    @FocusState private var editingIntake: Bool

    private var intake: Double? {
        guard let value = Double(intakeText.replacingOccurrences(of: ",", with: ".")), value.isFinite, (800...6000).contains(value) else { return nil }
        return value
    }
    private var latest: Double? { health.days.last { ($0.weight ?? 0) > 0 }?.weight }
    private var startWeight: Double? { health.estimate?.startWeight ?? NativeHealthMath.trend(health.days).last?.value }
    private var forecast: [HealthPoint] {
        switch mode {
        case .trend: return NativeWeightSimulation.trendForecast(health.days, weeks: trendWeeks, horizon: horizon)
        case .calories:
            guard let estimate = health.estimate, let intake else { return [] }
            return NativeHealthMath.forecast(estimate, intake: intake, weeks: horizon)
        }
    }
    private func kg(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func perWeekText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign: String = value >= 0 ? "+" : "−"
        return sign + kg(abs(value)) + " kg"
    }

    var body: some View {
        let forecast = self.forecast
        let today = Calendar.current.startOfDay(for: .now)
        let chartStart = Calendar.current.date(byAdding: .month, value: -3, to: today) ?? today
        let perWeek: Double? = {
            guard let first = forecast.first, let last = forecast.last, last.date > first.date else { return nil }
            let days = Double(Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
            return (last.value - first.value) / days * 7
        }()
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                    Text(latest.map(kg) ?? "—").font(.largeTitle.bold()).monospacedDigit()
                    Text("kg oggi").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                }
                .accessibilityElement(children: .combine)
                NativeCard {
                    chart(forecast: forecast, start: chartStart)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(perWeekText(perWeek)).font(.headline).monospacedDigit()
                            Text("a settimana").font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: NativeDesign.Space.xxs) {
                            Text(forecast.last.map { kg($0.value) + " kg" } ?? "—").font(.headline).monospacedDigit().foregroundStyle(NativeDesign.estimate)
                            Text(forecast.last.map { $0.date.formatted(.dateTime.day().month(.abbreviated)) } ?? "").font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("simulation-result")
                }
                controls
                targetSection
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.large)
        }
        .background(NativeDesign.canvas)
        .navigationTitle("Simulazione peso")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("health-detail-scroll")
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editingIntake = false } } }
        .task {
            if intakeText.isEmpty, let value = health.estimate?.averageIntake { intakeText = String(Int(value.rounded())) }
            if target <= 0, let latest { target = ((latest - 1) * 2).rounded() / 2 }
        }
    }

    private func chart(forecast: [HealthPoint], start: Date) -> some View {
        let today = Calendar.current.startOfDay(for: .now)
        let weighed = health.days.filter { $0.date >= start && ($0.weight ?? 0) > 0 }
        let trend = NativeHealthMath.trend(health.days.filter { $0.date <= .now }).filter { $0.date >= start }
        let values = weighed.compactMap(\.weight) + trend.map(\.value) + forecast.map(\.value) + (target > 0 ? [target] : [])
        let domain = ((values.min() ?? 70) - 0.4)...((values.max() ?? 80) + 0.4)
        let baseStart = Calendar.current.date(byAdding: .day, value: -trendWeeks * 7, to: today) ?? today
        return Chart {
            if mode == .trend {
                RectangleMark(xStart: .value("Base", baseStart), xEnd: .value("Oggi", today))
                    .foregroundStyle(NativeDesign.healthWeight.opacity(0.10))
            }
            ForEach(weighed) { day in
                PointMark(x: .value("Data", day.date), y: .value("Peso", day.weight!))
                    .foregroundStyle(NativeDesign.healthWeight.opacity(day.date >= baseStart || mode == .calories ? 0.8 : 0.35)).symbolSize(14)
            }
            ForEach(trend) { point in
                LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Tendenza"))
                    .foregroundStyle(NativeDesign.healthWeight).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            ForEach(forecast) { point in
                LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Previsione"))
                    .foregroundStyle(NativeDesign.estimate).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
            }
            if target > 0 {
                RuleMark(y: .value("Obiettivo", target)).foregroundStyle(Color.primary.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            RuleMark(x: .value("Oggi", today)).foregroundStyle(NativeDesign.secondary.opacity(0.5))
        }
        .chartXScale(domain: start...max(forecast.last?.date ?? today, today))
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        .chartLegend(.hidden)
        .frame(height: NativeDesign.Layout.healthChartHeight)
        .accessibilityLabel("Pesate, tendenza scelta e previsione")
        .accessibilityIdentifier("health-forecast-chart")
    }

    private var controls: some View {
        NativeCard {
            LOSegmented(options: [("Trend reale", "trend"), ("Calorie", "calories")], selection: Binding(
                get: { mode == .trend ? "Trend reale" : "Calorie" },
                set: { mode = $0 == "Trend reale" ? .trend : .calories; editingIntake = false }), identifierPrefix: "simulation-mode-")
            if mode == .trend {
                LOStepperRow(title: "Trend delle ultime", value: "\(trendWeeks) settimane",
                    decrement: trendWeeks > 2 ? { trendWeeks -= 1 } : nil, increment: trendWeeks < 12 ? { trendWeeks += 1 } : nil,
                    identifier: "simulation-trend-weeks")
            } else {
                HStack(spacing: NativeDesign.Space.small) {
                    Text("Se mangio").font(.body)
                    Spacer()
                    stepButton("minus", "Meno calorie") { adjustIntake(-100) }
                    TextField("kcal", text: $intakeText).keyboardType(.numberPad).focused($editingIntake)
                        .multilineTextAlignment(.center).monospacedDigit().font(.body.weight(.semibold))
                        .frame(width: NativeDesign.Layout.categoryWidth, height: NativeDesign.Layout.touchTarget)
                        .accessibilityLabel("Calorie dello scenario").accessibilityIdentifier("health-intake")
                    stepButton("plus", "Più calorie") { adjustIntake(100) }
                }
                .frame(minHeight: NativeDesign.Layout.rowHeight)
                if health.estimate == nil {
                    Text("Serve un TDEE per simulare con le calorie.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
            }
            Divider()
            LOStepperRow(title: "Mostra fino a", value: "\(horizon) settimane",
                decrement: horizon > 1 ? { horizon -= 1 } : nil, increment: horizon < 26 ? { horizon += 1 } : nil,
                identifier: "simulation-horizon")
        }
    }

    private var intakeNeeded: Double? {
        guard let estimate = health.estimate, let start = startWeight, target > 0 else { return nil }
        return NativeWeightSimulation.intakeNeeded(tdee: estimate.tdee, from: start, to: target, weeks: horizon, energyPerKG: estimate.energyPerKG)
    }
    private var needDetail: String? {
        guard let need = intakeNeeded, let tdee = health.estimate?.tdee else { return nil }
        let delta: Double = need - tdee
        let sign: String = delta >= 0 ? "+" : "−"
        return "al giorno · TDEE " + whole(tdee) + " · " + sign + whole(abs(delta)) + " rispetto al TDEE"
    }
    private func lowerTarget() { target = ((target - 0.5) * 2).rounded() / 2 }
    private func raiseTarget() { target = ((target + 0.5) * 2).rounded() / 2 }

    private var targetSection: some View {
        let need: Double? = intakeNeeded
        let targetText: String = target > 0 ? kg(target) + " kg" : "—"
        let needText: String = need.map { whole($0) + " kcal" } ?? "—"
        let low: Bool = (need ?? 2000) < 1600
        let decrement: (() -> Void)? = target > 30 ? lowerTarget : nil
        let increment: (() -> Void)? = target < 300 ? raiseTarget : nil
        return NativeCard {
            LOStepperRow(title: "Obiettivo", value: targetText, decrement: decrement, increment: increment, identifier: "simulation-target")
            Divider()
            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                Text("Per arrivarci in \(horizon) settimane").font(.footnote).foregroundStyle(NativeDesign.secondary)
                Text(needText).font(.title2.bold()).monospacedDigit()
                    .foregroundStyle(low ? NativeDesign.overGoal : Color.primary)
                if let detail = needDetail {
                    Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("simulation-need")
        }
    }

    private func adjustIntake(_ delta: Double) {
        let base = intake ?? health.estimate?.averageIntake ?? 2000
        intakeText = String(Int(min(max(base + delta, 800), 6000).rounded()))
    }

    private func stepButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                .contentShape(Circle())
                .modifier(NativeGlass())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityLabel(label)
    }
}
