import SwiftUI
import Charts

struct NativeBudgetAllocation: View {
    let summary: Record
    var compact = false
    var body: some View {
        let budget = NativeBudgetSegments(summary)
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            if !compact {
                Divider()
                HStack { Text("Stipendio medio"); Spacer(); Text(budget.salary.euro).monospacedDigit() }.font(.caption).foregroundStyle(NativeDesign.secondary)
            }
            GeometryReader { proxy in
                HStack(spacing: NativeDesign.Space.xxs) {
                    Rectangle().fill(NativeDesign.financialRed).frame(width: max(0, proxy.size.width - 4) * max(0, budget.spent) / budget.scale)
                    Rectangle().fill(NativeDesign.accent.opacity(0.65)).frame(width: max(0, proxy.size.width - 4) * max(0, budget.reserved) / budget.scale)
                    Rectangle().fill(NativeDesign.financialGreen).frame(width: max(0, proxy.size.width - 4) * max(0, budget.remaining) / budget.scale)
                }.clipShape(RoundedRectangle(cornerRadius: NativeDesign.progressRadius))
            }.frame(height: compact ? 5 : 9).accessibilityLabel("Ripartizione dello stipendio")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: NativeDesign.Space.medium) { segment("Spesi", budget.spent, NativeDesign.financialRed); segment("Accantonati", budget.reserved, NativeDesign.accent.opacity(0.65)); segment("Disponibili", budget.remaining, NativeDesign.financialGreen) }
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) { segment("Spesi", budget.spent, NativeDesign.financialRed); segment("Accantonati", budget.reserved, NativeDesign.accent.opacity(0.65)); segment("Disponibili", budget.remaining, NativeDesign.financialGreen) }
            }
            if budget.remaining < 0 { Label("Sforamento " + (-budget.remaining).euro, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(NativeDesign.financialRed) }
            if abs(budget.adjustment) > 0.02 { Text("Ripartizione da aggiornare: i dati non sono ancora riconciliati.").font(.caption2).foregroundStyle(NativeDesign.secondary) }
            if budget.spent < 0 { Text("Le spese nette includono rimborsi e storni.").font(.caption2).foregroundStyle(NativeDesign.secondary) }
        }
    }
    private func segment(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            HStack(spacing: NativeDesign.Space.xs) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).foregroundStyle(NativeDesign.secondary).fixedSize()
            }.font(.caption2)
            Text(value.euro).font(.caption.weight(.medium)).monospacedDigit().fixedSize()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct NativeForecastCard: View {
    @EnvironmentObject var store: NativeStore
    @AppStorage("native-hide-money") private var hidden = false
    @State private var explain = false
    var body: some View {
        let model = NativeWealthForecast(finance: store.finance, plan: store.finance.record("forecastPlan").isEmpty ? store.state.plan : store.finance.record("forecastPlan"))
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            HStack {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { Text("Previsione patrimonio").font(NativeDesign.heading); Text("6 mesi precedenti · 6 mesi successivi").font(.caption2).foregroundStyle(NativeDesign.secondary) }
                Spacer(minLength: 0)
                NativeIconButton(symbol: "info.circle", label: "Come funziona la previsione") { explain = true }
            }
            if hidden { Text("Importi nascosti").font(.caption).foregroundStyle(NativeDesign.secondary).frame(height: 150) }
            else if model.prediction.isEmpty {
                Text(store.analysisBusy ? "Aggiorno lo storico…" : "Servono almeno 4 mesi completi osservati sui 6 precedenti. Disponibili: \(model.samples).").font(.caption).foregroundStyle(NativeDesign.secondary).frame(minHeight: 80)
            } else {
                Chart {
                    ForEach(model.prediction) { point in
                        AreaMark(x: .value("Data", CivilDate.date(point.day)), yStart: .value("Limite inferiore", point.lower), yEnd: .value("Limite superiore", point.upper)).foregroundStyle(NativeDesign.accent.opacity(0.12))
                    }
                    ForEach(Array(model.prediction.enumerated()), id: \.offset) { index, point in
                        if index > 0 {
                            let previous = model.prediction[index - 1]
                            let color = point.value < previous.value ? NativeDesign.financialRed : NativeDesign.financialGreen
                            LineMark(x: .value("Data", CivilDate.date(previous.day)), y: .value("Stima", previous.value), series: .value("Serie", "stima-\(index)")).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            LineMark(x: .value("Data", CivilDate.date(point.day)), y: .value("Stima", point.value), series: .value("Serie", "stima-\(index)")).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                    }
                    ForEach(Array(model.history.enumerated()), id: \.offset) { index, point in
                        if index > 0 {
                            let previous = model.history[index - 1]
                            let color = point.value < previous.value ? NativeDesign.financialRed : NativeDesign.financialGreen
                            LineMark(x: .value("Data", CivilDate.date(previous.day)), y: .value("Saldo", previous.value), series: .value("Serie", "storico-\(index)")).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
                            LineMark(x: .value("Data", CivilDate.date(point.day)), y: .value("Saldo", point.value), series: .value("Serie", "storico-\(index)")).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    RuleMark(x: .value("Oggi", CivilDate.date(CivilDate.day()))).foregroundStyle(Color.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [3])).annotation(position: .top) { Text("Oggi").font(.caption2).foregroundStyle(NativeDesign.secondary) }
                }.chartLegend(.hidden).chartXAxis { AxisMarks(values: .stride(by: .month, count: 2)) { value in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                    .chartYAxis { AxisMarks(position: .trailing) { value in AxisGridLine(); AxisValueLabel { if let n = value.as(Double.self) { Text(n.formatted(.number.notation(.compactName)) + " €").font(.caption2) } } } }
                    .frame(height: 170).accessibilityIdentifier("wealth-forecast-chart")
                HStack { Label("Storico", systemImage: "line.diagonal"); Label("Stima", systemImage: "ellipsis"); Text("Fascia 80%*") }.font(.caption2).foregroundStyle(NativeDesign.secondary)
                HStack(spacing: NativeDesign.Space.medium) {
                    Label("Crescita", systemImage: "arrow.up.right").foregroundStyle(NativeDesign.financialGreen)
                    Label("Calo", systemImage: "arrow.down.right").foregroundStyle(NativeDesign.financialRed)
                }.font(.caption2)
                if let last = model.prediction.last { Text("Fra 6 mesi: " + last.lower.euro + " – " + last.upper.euro).font(.caption.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true) }
                Text("*Scenario indicativo sul conto principale, non garantito.").font(.caption2).foregroundStyle(NativeDesign.secondary)
                if model.samples < 6 { Text("Storico parziale: \(model.samples) mesi su 6.").font(.caption2).foregroundStyle(NativeDesign.warning) }
            }
        }.sheet(isPresented: $explain) {
            NavigationStack {
                List {
                    Section("Metodo") {
                        Text("Usa fino a sei mesi completi di flussi effettivi del conto principale. I pagamenti Extra collegati sono separati prima di stimare il flusso ordinario; i valori anomali sono limitati con mediana e deviazione assoluta mediana.")
                        Text("La fascia comprende il centro dell’80% di 2.000 simulazioni dei flussi mensili osservati. Con pochi mesi è indicativa: non misura tutti i rischi futuri e non presume stagionalità.")
                    }
                    Section("Spese Extra") {
                        Text("Gli accantonamenti non diminuiscono il patrimonio. Sono sottratti soltanto i pagamenti futuri pianificati sul conto principale, al termine del periodo di accantonamento; le quote già pagate non sono sottratte di nuovo. Le scadenze arretrate non saldate sono considerate nel primo intervallo.")
                        LabeledContent("Pagamenti noti nei prossimi 6 mesi", value: hidden ? "••••" : model.knownExtra.euro)
                        Text("Nuovi acquisti non pianificati, variazioni di stipendio e date effettive di pagamento possono cambiare il risultato. I pagamenti Extra non collegati restano nei flussi storici.")
                    }
                }.modifier(NativeListAppearance()).navigationTitle("Previsione").navigationBarTitleDisplayMode(.inline).toolbar { DoneButton() }
            }
        }
    }
}

