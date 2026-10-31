import SwiftUI
import Charts

struct NativeHealthCard: View {
    @ObservedObject var health: NativeHealthStore
    let demo: Bool
    @State private var addingWeight = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var latest: HealthDay? { health.days.last { $0.weight != nil } }
    var body: some View {
        // Calculate the historical fit once for this render, not once per metric/mark.
        let estimate = health.estimate
        let chart = NativeHealthDashboardData(days: health.days, estimate: nil)
        NativeCard {
            HStack(spacing: NativeDesign.Space.small) {
                NavigationLink { NativeHealthDetail(health: health, demo: demo) } label: {
                    HStack(spacing: NativeDesign.Space.small) {
                        Label("Peso e calorie", systemImage: "figure.arms.open")
                            .font(NativeDesign.heading).foregroundStyle(NativeDesign.secondary)
                        Spacer(minLength: NativeDesign.Space.small)
                        if health.loading { ProgressView().controlSize(.small) }
                        NativeDisclosureIndicator()
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-health-heading-link")
                NativeIconButton(symbol: "plus", label: "Aggiungi peso") { addingWeight = true }
                    .accessibilityIdentifier("home-health-add-weight")
            }
            NavigationLink { NativeHealthDetail(health: health, demo: demo) } label: {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.large)) : AnyLayout(HStackLayout(alignment: .center, spacing: NativeDesign.Space.large))
                layout {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.medium) { metrics(estimate) }
                        .fixedSize(horizontal: true, vertical: false)
                    if !chart.days.isEmpty {
                        NativeHealthDashboardChart(data: chart).frame(maxWidth: .infinity)
                    } else { Spacer(minLength: 0) }
                }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.healthOverviewChart, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(NativePressStyle()).accessibilityIdentifier("home-health-detail")
                .accessibilityLabel(accessibilitySummary(estimate))
                .accessibilityHint("Apre grafici, simulazione e impostazioni Apple Health")
        }.sheet(isPresented: $addingWeight) {
            NativeAddWeightSheet(health: health)
        }
    }
    @ViewBuilder private func metrics(_ estimate: HealthEstimate?) -> some View {
        metric(estimate.map { (($0.tdee / 50).rounded() * 50).formatted(.number.precision(.fractionLength(0))) } ?? "—", unit: "kcal/giorno")
        metric(latest?.weight.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", unit: "kg")
    }
    private func metric(_ value: String, unit: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.xs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs))
        return layout {
            Text(value).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(NativeDesign.healthAccent)
            Text(unit).font(.caption).foregroundStyle(NativeDesign.secondary)
        }
    }
    private func accessibilitySummary(_ estimate: HealthEstimate?) -> String {
        var text = "Peso e calorie. Ultimo peso " + (latest?.weight.map { $0.formatted(.number.precision(.fractionLength(1))) + " kg" } ?? "non disponibile")
        if let estimate { text += ". TDEE medio storico stimato " + ((estimate.tdee / 50).rounded() * 50).formatted(.number.precision(.fractionLength(0))) + " kcal al giorno" }
        text += ". Anteprima peso e calorie dell’ultimo mese. Dettagli e previsioni nella scheda."
        if demo { text += " Dati illustrativi." }
        return text
    }
}

/// An axis-free historical preview. Forecasts and full scales belong to the detail screen.
private struct NativeHealthDashboardChart: View {
    let data: NativeHealthDashboardData
    var body: some View {
        Chart {
            ForEach(data.days.filter { ($0.calories ?? 0) > 0 && ($0.calories?.isFinite ?? false) }) { day in
                BarMark(x: .value("Data", day.date, unit: .day),
                        yStart: .value("Base", data.weightDomain.lowerBound),
                        yEnd: .value("Calorie", data.plottedCalories(day.calories!)))
                    .foregroundStyle(CivilDate.day(day.date) == CivilDate.day(data.today) ? NativeDesign.healthAccent : NativeDesign.healthGray)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: NativeDesign.Layout.healthBarRadius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: NativeDesign.Layout.healthBarRadius))
            }
            ForEach(data.days.filter { ($0.weight ?? 0) > 0 && ($0.weight?.isFinite ?? false) }) { day in
                PointMark(x: .value("Data", day.date), y: .value("Peso", day.weight!))
                    .foregroundStyle(NativeDesign.healthGray).symbolSize(6)
            }
            ForEach(data.trend) { point in
                LineMark(x: .value("Data", point.date), y: .value("Peso", point.value))
                    .foregroundStyle(NativeDesign.healthGray)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }.chartXScale(domain: data.start...Calendar.current.date(byAdding: .day, value: 1, to: data.today)!).chartYScale(domain: data.weightDomain)
            .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
            .frame(height: NativeDesign.Layout.healthOverviewChart)
            .accessibilityHidden(true)
    }
}

struct NativeAddWeightSheet: View {
    @ObservedObject var health: NativeHealthStore
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var date = Date()
    @State private var saving = false
    @State private var error: String?
    @State private var submitted = false
    private let requestID: UUID?
    init(health: NativeHealthStore, transfer: NativeWeightTransfer? = nil) {
        self.health = health; requestID = transfer?.id
        _weightText = State(initialValue: transfer.map { String($0.kilograms) } ?? "")
        _date = State(initialValue: transfer?.date ?? Date())
    }
    @FocusState private var editing: Bool
    private var weight: Double? {
        guard let value = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0, value <= 500 else { return nil }
        return value
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Peso", text: $weightText).keyboardType(.decimalPad).focused($editing)
                            .accessibilityLabel("Peso in chilogrammi").accessibilityIdentifier("health-new-weight")
                        Text("kg").foregroundStyle(NativeDesign.secondary)
                    }
                    DatePicker("Data", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("health-weight-date")
                } footer: {
                    Text("La pesata viene salvata in Apple Health. Se registri più pesate nello stesso giorno, nel grafico compare la più recente.")
                }.disabled(saving || (requestID != nil && submitted))
                if let error { Section { Text(error).foregroundStyle(NativeDesign.warning) } }
            }.modifier(NativeListAppearance()).navigationTitle("Aggiungi peso").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { dismiss() }.disabled(saving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            guard let weight, !saving else { return }
                            saving = true; submitted = true; error = nil; editing = false
                            Task {
                                do { try await health.saveWeight(weight, at: date, requestID: requestID); dismiss() }
                                catch { self.error = error.localizedDescription; saving = false }
                            }
                        } label: {
                            if saving { ProgressView() } else { Text("Salva") }
                        }.disabled(weight == nil || saving || health.loading).accessibilityIdentifier("health-save-weight")
                    }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } }
                }
                .interactiveDismissDisabled(saving)
                .task { editing = true }
        }
    }
}

private enum NativeHealthPeriod: String, CaseIterable, Identifiable {
    case week = "Settimana", month = "Mese", quarter = "3 mesi"
    var id: String { rawValue }
    func start(relativeTo date: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)!
        case .month: return calendar.date(byAdding: .month, value: -1, to: today)!
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: today)!
        }
    }
    var axisDays: Int { self == .week ? 2 : (self == .month ? 7 : 28) }
}

private struct NativeHealthWeightChart: View {
    let days: [HealthDay]
    var forecast: [HealthPoint] = []
    @State private var period: NativeHealthPeriod = .month
    private var start: Date { period.start(relativeTo: Date()) }
    private var end: Date { max(forecast.last?.date ?? Date(), Date()) }
    private var visibleDays: [HealthDay] { days.filter { $0.date >= start && $0.weight != nil } }
    private var trend: [HealthPoint] { NativeHealthMath.trend(days).filter { $0.date >= start } }
    private var domain: ClosedRange<Double> {
        let values = visibleDays.compactMap(\.weight) + forecast.map(\.value)
        return ((values.min() ?? 70) - 1)...((values.max() ?? 80) + 1)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            if forecast.isEmpty {
                Picker("Periodo peso", selection: $period) {
                    ForEach(NativeHealthPeriod.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("health-weight-period")
            }
            if visibleDays.isEmpty && forecast.isEmpty {
                Text("Nessuna pesata nel periodo selezionato").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                Chart {
                    ForEach(visibleDays) { day in
                        PointMark(x: .value("Data", day.date), y: .value("Peso", day.weight!))
                            .foregroundStyle(Color.secondary.opacity(0.45)).symbolSize(12)
                    }
                    ForEach(trend) { point in
                        LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Tendenza"))
                            .foregroundStyle(Color.blue)
                    }
                    ForEach(forecast) { point in
                        LineMark(x: .value("Data", point.date), y: .value("Peso", point.value), series: .value("Serie", "Previsione"))
                            .foregroundStyle(Color.blue).lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                    if !forecast.isEmpty {
                        RuleMark(x: .value("Oggi", Date())).foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }.chartXScale(domain: start...end).chartYScale(domain: domain)
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: forecast.isEmpty ? period.axisDays : 28)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                    .frame(height: 190)
                    .accessibilityLabel("Peso in chilogrammi: pesate e tendenza" + (forecast.isEmpty ? "" : ", previsione tratteggiata"))
                Text(forecast.isEmpty ? "kg · Punti: pesate · Linea: tendenza" : "kg · Linea: tendenza · Tratteggio: previsione")
                    .font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        }
    }
}

private struct NativeHealthCaloriesChart: View {
    let days: [HealthDay]
    @State private var period: NativeHealthPeriod = .month
    private var start: Date { period.start(relativeTo: Date()) }
    private var visibleDays: [HealthDay] { days.filter { $0.date >= start && $0.calories != nil } }
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            Picker("Periodo calorie", selection: $period) {
                ForEach(NativeHealthPeriod.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("health-calories-period")
            if visibleDays.isEmpty {
                Text("Nessuna caloria registrata nel periodo selezionato").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                Chart(visibleDays) { day in
                    BarMark(x: .value("Data", day.date, unit: .day), y: .value("Calorie", day.calories!))
                        .foregroundStyle(Color.orange.opacity(0.7))
                }.chartXScale(domain: start...Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)
                    .chartYScale(domain: 0...max(3000, (visibleDays.compactMap(\.calories).max() ?? 0) * 1.1))
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: period.axisDays)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                    .frame(height: 190)
                    .accessibilityLabel("Calorie assunte per giorno nel periodo selezionato")
                let average = visibleDays.compactMap(\.calories).reduce(0, +) / Double(visibleDays.count)
                Text("Media registrata: " + average.formatted(.number.precision(.fractionLength(0))) + " kcal/giorno · \(visibleDays.count) giorni registrati")
                    .font(.caption).foregroundStyle(NativeDesign.secondary)
                Text("I giorni mancanti non sono zero. Oggi può essere incompleto.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        }
    }
}

struct NativeHealthDetail: View {
    @ObservedObject var health: NativeHealthStore
    let demo: Bool
    @State private var intakeText = ""
    @FocusState private var editing: Bool
    private var intake: Double? {
        guard let value = Double(intakeText.replacingOccurrences(of: ",", with: ".")), value.isFinite, (800...6000).contains(value) else { return nil }
        return value
    }
    private var forecast: [HealthPoint] {
        guard let estimate = health.estimate, let intake else { return [] }
        return NativeHealthMath.forecast(estimate, intake: intake)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                if demo { Text("Dati illustrativi").font(.caption).foregroundStyle(NativeDesign.secondary) }
                tdeeSection
                NativeCard {
                    Text("Peso").font(NativeDesign.heading)
                    NativeHealthWeightChart(days: health.days)
                }
                NativeCard {
                    Text("Calorie assunte").font(NativeDesign.heading)
                    NativeHealthCaloriesChart(days: health.days)
                }
                scenarioSection
                connectionSections
                methodSection
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
        }.background(NativeDesign.canvas).navigationTitle("Peso e calorie").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("health-detail-scroll")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } } }
            .task { if intakeText.isEmpty, let value = health.estimate?.averageIntake { intakeText = String(Int(value.rounded())) } }
    }
    @ViewBuilder private var tdeeSection: some View {
        if let estimate = health.estimate {
            NativeCard {
                Text("TDEE medio dallo storico").font(NativeDesign.heading)
                Text(((estimate.tdee / 50).rounded() * 50).formatted(.number.precision(.fractionLength(0))) + " kcal/giorno").font(NativeDesign.value).monospacedDigit()
                if let first = estimate.firstDate {
                    Text(first.formatted(date: .abbreviated, time: .omitted) + " – " + estimate.lastDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(NativeDesign.secondary)
                }
                LabeledContent("Pesate utilizzate", value: String(estimate.weighIns))
                LabeledContent("Giorni con calorie", value: "\(estimate.loggedDays) / \(estimate.days)")
                LabeledContent("Introito medio nello storico", value: estimate.calibrationIntake.formatted(.number.precision(.fractionLength(0))) + " kcal/giorno")
                if estimate.imputedDays > 0 {
                    Text("\(estimate.imputedDays) giorni mancanti sono stimati dalla media dei giorni registrati. Se ciascuno fosse più alto o basso di 500 kcal, il risultato cambierebbe di circa ±" + estimate.missingDaySensitivity.formatted(.number.precision(.fractionLength(0))) + " kcal/giorno. È una sensibilità all’ipotesi, non un intervallo di confidenza.").font(.caption).foregroundStyle(NativeDesign.warning)
                }
                Text("Media storica stimata, non misura del metabolismo attuale. L’attività può essere cambiata nel periodo.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        } else {
            NativeCard {
                Text("TDEE stimato").font(NativeDesign.heading)
                Text("Dati insufficienti").font(.headline)
                Text("Servono almeno 28 giorni, 10 pesate recenti e calorie registrate in almeno il 90% dei giorni.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        }
    }

    @ViewBuilder private var scenarioSection: some View {
        if let estimate = health.estimate {
            NativeCard {
                Text("Simulazione").font(NativeDesign.heading)
                HStack {
                    TextField("kcal/giorno", text: $intakeText).keyboardType(.decimalPad).focused($editing)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Calorie dello scenario").accessibilityIdentifier("health-intake")
                    Text("kcal/giorno").font(.subheadline)
                }
                Button("Usa media recente: " + estimate.averageIntake.formatted(.number.precision(.fractionLength(0))) + " kcal") {
                    intakeText = String(Int(estimate.averageIntake.rounded())); editing = false
                }.frame(minHeight: NativeDesign.Layout.touchTarget)
                if forecast.isEmpty { Text("Inserisci un valore fra 800 e 6.000 kcal/giorno. Questo intervallo è tecnico, non una raccomandazione alimentare.").font(.caption).foregroundStyle(NativeDesign.secondary) }
                else {
                    NativeHealthWeightChart(days: health.days, forecast: forecast)
                    ForEach([4, 8], id: \.self) { week in
                        if let point = forecast.dropFirst(week * 7).first {
                            LabeledContent("Tra \(week) settimane dalla stima", value: point.value.formatted(.number.precision(.fractionLength(1))) + " kg")
                        }
                    }
                }
                Text("Scenario indicativo con attività invariata. Parte dal peso di tendenza dell’ultima giornata completa, non dall’ultima oscillazione della bilancia.")
                    .font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        } else {
            NativeCard {
                Text("Simulazione").font(NativeDesign.heading)
                Text("Disponibile quando ci sono dati sufficienti per stimare il TDEE.").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
        }
    }

    @ViewBuilder private var connectionSections: some View {
        if !health.localDays.isEmpty {
            NativeCard {
                DisclosureGroup("Misurazioni salvate in Life OS") {
                    Text("Conservate sul dispositivo. Nel grafico, i dati Apple Health hanno precedenza sullo stesso giorno. Questi valori non vengono copiati automaticamente in Salute.")
                        .font(.caption).foregroundStyle(NativeDesign.secondary)
                    ForEach(health.localDays) { day in
                        LabeledContent(day.date.formatted(date: .abbreviated, time: .omitted), value: [day.weight.map { $0.formatted() + " kg" }, day.calories.map { $0.formatted() + " kcal" }].compactMap { $0 }.joined(separator: " · "))
                    }
                }
            }
        }
        if !demo {
            NativeCard {
                Button { Task { await health.connect() } } label: {
                    Label("Collega o gestisci Apple Health", systemImage: "heart")
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                }.disabled(health.loading).accessibilityIdentifier("health-connect")
                if health.loading { ProgressView() }
                if let message = health.message { Text(message).font(.caption).foregroundStyle(NativeDesign.secondary) }
            }
        }
        if !health.sources.isEmpty {
            NativeCard {
                Text("Fonte delle calorie").font(NativeDesign.heading)
                Picker("App alimentare", selection: $health.selectedSource) {
                    ForEach(health.sources, id: \.self) { source in Text(health.sourceNames[source] ?? source).tag(source) }
                }.pickerStyle(.menu).onChange(of: health.selectedSource) { _, _ in health.rebuild() }
                Text("Usiamo una sola app per evitare doppioni. Verifica che contenga tutte le calorie assunte; una giornata registrata solo in parte altera la stima.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        }
    }

    @ViewBuilder private var methodSection: some View {
        Text("Life OS " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") + " · build " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
            .font(.caption2).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("health-build-version")
        DisclosureGroup("Metodo e limiti") {
            Text("La calibrazione usa i 30 giorni precedenti l’ultima pesata antecedente a oggi e confronta calorie cumulative e pesate originali dello stesso periodo. La mediana delle pendenze su intervalli lunghi riduce l’influenza di singole pesate anomale; la mediana mobile di 7 giorni è usata solo per disegnare il trend. Le variazioni di peso richiedono ancora una conversione energetica approssimata, 7.700 kcal/kg: acqua, glicogeno e tessuti non sono separabili esattamente da questi dati. I giorni calorici mancanti, al massimo il 10%, sono stimati dalla media e indicati esplicitamente; giorni registrati solo in parte non sono riconoscibili automaticamente. Non è una misura diretta del TDEE attuale né il modello NIH completo. La previsione mantiene il modello dinamico approssimato e presume attività futura simile a quella che il TDEE storico rappresenta. Nessuna fascia di confidenza non calibrata. I dati Salute restano in memoria sul dispositivo e non vengono inviati al server.")
                .font(.footnote).foregroundStyle(NativeDesign.secondary)
            Link("Studio di riferimento", destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC3880593/")!)
        }
    }

}
