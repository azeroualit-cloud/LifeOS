import SwiftUI

/// Build 93 Analisi data (BUILD93-PREVIEW-FINAL-2026-11-21). Everything comes from the
/// finance snapshot the server already sends: `yearly`, `forecastHistory`, `planning`,
/// `lifetime.salaryHistory` and the month's movements. Nothing is invented.
struct NativeMonthFlow: Equatable {
    let month: String
    let income: Double
    let spent: Double
    var saved: Double { income - spent }
}

enum NativeFinanceAnalysis93 {
    /// Complete months with data before `month` (the norm starts from the first month with
    /// records, July for the current data set).
    static func flows(_ finance: Record, before month: String) -> [NativeMonthFlow] {
        finance.records("yearly")
            .filter { $0.text("month") < month && ($0.flag("hasRecords") || $0.amount("spent") > 0 || $0.amount("income") > 0) }
            .sorted { $0.text("month") < $1.text("month") }
            .map { NativeMonthFlow(month: $0.text("month"), income: $0.amount("income"), spent: $0.amount("spent")) }
    }
    /// The usual monthly spending: mean of the complete months.
    static func norm(_ flows: [NativeMonthFlow]) -> Double? {
        guard !flows.isEmpty else { return nil }
        return flows.reduce(0) { $0 + $1.spent } / Double(flows.count)
    }
    /// Relative difference from the norm over the last `months` complete months.
    static func pace(_ flows: [NativeMonthFlow], months: Int) -> Double? {
        guard let norm = norm(flows), norm > 0, flows.count >= months, months > 0 else { return nil }
        let recent = flows.suffix(months).reduce(0) { $0 + $1.spent } / Double(months)
        return recent / norm - 1
    }
    static func percent(_ value: Double) -> String {
        let p = Int((value * 100).rounded())
        return (p > 0 ? "+" : p < 0 ? "−" : "") + String(abs(p)) + "%"
    }
    /// Average monthly surplus of the observed months (positive = the fund grows with the salary).
    static func surplus(_ finance: Record) -> Double? {
        let rows = finance.records("forecastHistory").filter { $0.flag("observed") }
        guard !rows.isEmpty else { return nil }
        return rows.reduce(0) { $0 + $1.amount("ordinaryNet") } / Double(rows.count)
    }
    static func fund(_ finance: Record) -> Double? {
        let planning = finance.record("planning")
        guard case .number(let value)? = planning["now"], value.isFinite else { return nil }
        return value
    }
    /// Months the fund lasts without salary at `monthly` € a month.
    static func runway(fund: Double, monthly: Double) -> Double? {
        guard monthly > 0, fund > 0 else { return nil }
        return fund / monthly
    }
    /// Spending per day of the selected month from its movements (outflows only).
    static func daily(_ transactions: [Record], month: String) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for row in transactions where row.text("date").hasPrefix(month) && row.amount("amount") < 0 && row.text("type") != "Entrata" {
            if let day = Int(row.text("date").dropFirst(8).prefix(2)) { result[day, default: 0] += -row.amount("amount") }
        }
        return result
    }
    /// Short Italian month label ("lug").
    static func shortMonth(_ month: String) -> String {
        let names = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
        guard let index = Int(month.suffix(2)), (1...12).contains(index) else { return month }
        return names[index - 1]
    }
}

/// Tappable vertical bars (one or two series) used by Entrate e uscite and Stipendi.
struct LOBarPicker: View {
    struct Bar: Identifiable { let id: String; let label: String; let values: [Double]; let accessibility: String }
    let bars: [Bar]
    let colors: [Color]
    @Binding var selected: String?
    var identifierPrefix: String
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 144

    var body: some View {
        let top = max(bars.flatMap(\.values).max() ?? 1, 0.01)
        HStack(alignment: .bottom, spacing: NativeDesign.Space.small) {
            ForEach(bars) { bar in
                let on = selected == bar.id || (selected == nil && bar.id == bars.last?.id)
                Button { selected = bar.id } label: {
                    VStack(spacing: NativeDesign.Space.xs) {
                        HStack(alignment: .bottom, spacing: NativeDesign.Space.xxs) {
                            ForEach(Array(bar.values.enumerated()), id: \.offset) { index, value in
                                RoundedRectangle(cornerRadius: NativeDesign.Space.xs, style: .continuous)
                                    .fill(colors[min(index, colors.count - 1)].opacity(on ? 1 : 0.55))
                                    .frame(height: max(NativeDesign.Space.xxs, height * CGFloat(max(0, value) / top)))
                            }
                        }
                        .frame(height: height, alignment: .bottom)
                        Text(bar.label).font(.caption2).foregroundStyle(on ? Color.primary : NativeDesign.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(bar.accessibility)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier(identifierPrefix + bar.id)
            }
        }
    }
}

/// Section card with a title and a short right label (preview "Ritmo · da luglio").
struct LOAnalysisCard<Content: View>: View {
    let title: String
    var trailing = ""
    var identifier: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline).foregroundStyle(NativeDesign.financeTitle).accessibilityAddTraits(.isHeader)
                Spacer(minLength: NativeDesign.Space.small)
                if !trailing.isEmpty { Text(trailing).font(.footnote).foregroundStyle(NativeDesign.secondary) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NativeDesign.Layout.compactCardInset)
        .loCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// Ritmo: the usual monthly spending and the last month / last three months against it.
struct NativeRhythmCard: View {
    let flows: [NativeMonthFlow]
    let hidden: Bool
    var body: some View {
        LOAnalysisCard(title: "Ritmo", trailing: flows.first.map { "da " + monthName($0.month) } ?? "", identifier: "finance-rhythm") {
            if let norm = NativeFinanceAnalysis93.norm(flows) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                    Text(hidden ? "•••• €" : norm.euro).font(.title.bold()).monospacedDigit()
                    Text("la tua norma al mese").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                }
                paceRow("Ultimo mese", NativeFinanceAnalysis93.pace(flows, months: 1))
                paceRow("Ultimi 3 mesi", NativeFinanceAnalysis93.pace(flows, months: 3))
            } else {
                Text("Nessun mese completo").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
        }
    }
    private func monthName(_ month: String) -> String {
        ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"][max(0, min(11, (Int(month.suffix(2)) ?? 1) - 1))]
    }
    @ViewBuilder private func paceRow(_ title: String, _ value: Double?) -> some View {
        if let value {
            HStack(spacing: NativeDesign.Space.medium) {
                Text(title).font(.subheadline).foregroundStyle(NativeDesign.secondary).frame(maxWidth: .infinity, alignment: .leading)
                GeometryReader { proxy in
                    let half = proxy.size.width / 2
                    let width = min(half, half * CGFloat(min(1, abs(value) / 0.3)))
                    ZStack(alignment: .leading) {
                        Capsule().fill(NativeDesign.barTrack)
                        Capsule().fill(value > 0 ? NativeDesign.overGoal : NativeDesign.financialGreen)
                            .frame(width: max(NativeDesign.Space.xs, width))
                            .offset(x: value > 0 ? half : half - width)
                        Rectangle().fill(NativeDesign.secondary).frame(width: 1).offset(x: half)
                    }
                }
                .frame(width: NativeDesign.Layout.categoryWidth, height: NativeDesign.Space.small)
                Text(NativeFinanceAnalysis93.percent(value)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .frame(minWidth: NativeDesign.Layout.touchTarget, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title + ", " + NativeFinanceAnalysis93.percent(value) + " rispetto alla norma")
        }
    }
}

/// Quanto dura il fondo: with salary (average surplus) and without (months at a chosen spending).
struct NativeFundRunwayCard: View {
    let fund: Double?
    let surplus: Double?
    let norm: Double?
    let hidden: Bool
    @AppStorage("native-fund-monthly-93") private var monthly: Double = 0
    private var spending: Double { monthly > 0 ? monthly : max(50, ((norm ?? 1000) / 50).rounded() * 50) }

    var body: some View {
        LOAnalysisCard(title: "Quanto dura il fondo", trailing: fund.map { "fondo " + (hidden ? "••••" : $0.euro) } ?? "", identifier: "finance-fund") {
            if let fund {
                HStack(alignment: .top, spacing: NativeDesign.Space.medium) {
                    tile("Con stipendio", value: (surplus ?? 0) >= 0 ? "Stabile" : "In calo",
                         detail: surplus.map { (hidden ? "••••" : abs($0).euro) + ($0 >= 0 ? " di eccedenza al mese" : " in meno al mese") } ?? "")
                    tile("Senza stipendio", value: NativeFinanceAnalysis93.runway(fund: fund, monthly: spending).map { $0.formatted(.number.precision(.fractionLength(1))) + " mesi" } ?? "—",
                         detail: "a " + spending.formatted(.number.precision(.fractionLength(0))) + " € al mese")
                }
                LOStepperRow(title: "Spesa al mese senza stipendio",
                             value: spending.formatted(.number.precision(.fractionLength(0))) + " €",
                             decrement: spending > 50 ? { monthly = max(50, spending - 50) } : nil,
                             increment: spending < 5000 ? { monthly = min(5000, spending + 50) } : nil,
                             identifier: "finance-fund-monthly")
            } else {
                Text("Fondo non disponibile").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            }
        }
    }
    private func tile(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(NativeDesign.secondary)
            Text(value).font(.title3.bold()).monospacedDigit()
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(NativeDesign.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NativeDesign.Space.medium)
        .loTileSurface()
        .accessibilityElement(children: .combine)
    }
}

/// Spese per categoria: bars per category, tap for the monthly average.
struct NativeCategoryBars93: View {
    let rows: [Record]
    let months: Int
    let hidden: Bool
    @State private var selected: String?
    var body: some View {
        let sorted = rows.filter { $0.amount("amount") > 0 }.sorted { $0.amount("amount") > $1.amount("amount") }
        let top = max(sorted.first?.amount("amount") ?? 1, 0.01)
        let current = sorted.first { $0.text("name") == selected } ?? sorted.first
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            ForEach(Array(sorted.prefix(8).enumerated()), id: \.offset) { index, row in
                let name = row.text("name"), value = row.amount("amount"), on = current?.text("name") == name
                Button { selected = name } label: {
                    HStack(spacing: NativeDesign.Space.small) {
                        HStack(spacing: NativeDesign.Space.xs) {
                            Circle().fill(NativeDesign.financeBudget[min(index, 3)]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                            Text(name).font(.subheadline).lineLimit(1)
                        }
                        .frame(width: NativeDesign.Layout.categoryWidth * 1.2, alignment: .leading)
                        LOProgressBar(value: value, total: top, color: NativeDesign.financeBudget[min(index, 3)].opacity(on ? 1 : 0.6))
                        Text(hidden ? "••••" : value.euro).font(.subheadline.weight(on ? .semibold : .regular)).monospacedDigit()
                    }
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name + (hidden ? "" : ", " + value.euro))
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("finance-category-" + name)
            }
            if let current, months > 0 {
                HStack {
                    Text(current.text("name") + " · media al mese").font(.subheadline).foregroundStyle(NativeDesign.secondary)
                    Spacer()
                    Text(hidden ? "••••" : (current.amount("amount") / Double(months)).euro).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("finance-category-average")
            }
        }
    }
}

/// Giorno per giorno: calendar of the month, tap a day for what was spent.
struct NativeDailySpendCard: View {
    let month: String
    let daily: [Int: Double]
    let hidden: Bool
    @State private var selected: Int?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.xs), count: 7)
    var body: some View {
        let date = CivilDate.date(month + "-01")
        let count = CivilDate.calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let weekday = CivilDate.calendar.component(.weekday, from: date)
        let offset = (weekday + 5) % 7
        let top = max(daily.values.max() ?? 1, 0.01)
        let spentDays = daily.values.filter { $0 > 0 }
        let average = spentDays.isEmpty ? 0 : spentDays.reduce(0, +) / Double(count)
        let day = selected ?? (String(CivilDate.day().prefix(7)) == month ? Int(CivilDate.day().suffix(2)) ?? 1 : 1)
        LOAnalysisCard(title: "Giorno per giorno", trailing: CivilDate.monthTitle(month).lowercased(), identifier: "finance-daily") {
            LazyVGrid(columns: columns, spacing: NativeDesign.Space.xs) {
                ForEach(["L", "M", "M", "G", "V", "S", "D"].indices, id: \.self) { index in
                    Text(["L", "M", "M", "G", "V", "S", "D"][index]).font(.caption2).foregroundStyle(NativeDesign.secondary).accessibilityHidden(true)
                }
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: NativeDesign.Layout.touchTarget) }
                ForEach(1...count, id: \.self) { number in
                    let value = daily[number] ?? 0
                    Button { selected = number } label: {
                        Text(String(number)).font(.footnote.weight(number == day ? .bold : .regular)).monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
                            .background(RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous)
                                .fill(value > 0 ? NativeDesign.financeBudget[0].opacity(0.18 + 0.62 * value / top) : NativeDesign.barTrack.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous)
                                .strokeBorder(number == day ? Color.primary : .clear, lineWidth: NativeDesign.Layout.selectionLine))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(number) + (hidden ? "" : ", " + value.euro))
                    .accessibilityAddTraits(number == day ? .isSelected : [])
                }
            }
            HStack {
                Text("Il " + String(day) + " del mese").font(.subheadline)
                Spacer()
                Text(hidden ? "••••" : (daily[day] ?? 0).euro).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("finance-daily-selected")
            if !hidden { Text("in media " + average.euro + " al giorno nel mese").font(.caption).foregroundStyle(NativeDesign.secondary) }
        }
    }
}
