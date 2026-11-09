import SwiftUI

struct NativeNutrientAmount: Codable, Equatable {
    let amount: Decimal
    let estimateSource: String?
}

enum NativeTrackedNutrient: String, CaseIterable, Identifiable {
    case vitaminC, zinc, vitaminA, vitaminD, vitaminE, vitaminK, vitaminK1, vitaminK2
    case vitaminB1, vitaminB2, vitaminB3, vitaminB5, vitaminB6, folate, vitaminB12
    case calcium, chloride, copper, iron, iodine, magnesium, manganese
    case phosphorus, potassium, selenium, sodium
    case ala, epaDha, epa, dha

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vitaminC: "Vitamina C"
        case .zinc: "Zinco"
        case .vitaminA: "Vitamina A"
        case .vitaminD: "Vitamina D"
        case .vitaminE: "Vitamina E"
        case .vitaminK: "Vitamina K"
        case .vitaminK1: "Vitamina K1"
        case .vitaminK2: "Vitamina K2"
        case .vitaminB1: "Vitamina B1"
        case .vitaminB2: "Vitamina B2"
        case .vitaminB3: "Vitamina B3"
        case .vitaminB5: "Vitamina B5"
        case .vitaminB6: "Vitamina B6"
        case .folate: "Folati"
        case .vitaminB12: "Vitamina B12"
        case .calcium: "Calcio"
        case .chloride: "Cloruro"
        case .copper: "Rame"
        case .iron: "Ferro"
        case .iodine: "Iodio"
        case .magnesium: "Magnesio"
        case .manganese: "Manganese"
        case .phosphorus: "Fosforo"
        case .potassium: "Potassio"
        case .selenium: "Selenio"
        case .sodium: "Sodio"
        case .ala: "ALA"
        case .epaDha: "Omega-3 (EPA + DHA)"
        case .epa: "EPA"
        case .dha: "DHA"
        }
    }
    var unit: String {
        switch self {
        case .vitaminA, .vitaminD, .vitaminK, .vitaminK1, .vitaminK2, .folate, .vitaminB12, .iodine, .selenium: "µg"
        default: "mg"
        }
    }
    // SINU LARN V, adult men 18–64. EFSA for potassium and EPA + DHA.
    // The B1 reference uses the LARN 0.4 mg/1000 kcal at a 2500 kcal baseline.
    var dailyReference: Decimal {
        switch self {
        case .vitaminC: 105
        case .zinc: 12
        case .vitaminA: 750
        case .vitaminD: 15
        case .vitaminE: 13
        case .vitaminK, .vitaminK1, .vitaminK2: 135
        case .vitaminB1: 1
        case .vitaminB2: 1.6
        case .vitaminB3: 18
        case .vitaminB5: 5
        case .vitaminB6: 1.6
        case .folate: 330
        case .vitaminB12: 4
        case .calcium: 950
        case .chloride: 2300
        case .copper: 1.4
        case .iron: 10
        case .iodine: 150
        case .magnesium: 350
        case .manganese: 2.5
        case .phosphorus: 550
        case .potassium: 3500
        case .selenium: 55
        case .sodium: 1500
        case .ala: 1250 // EFSA 0.5% energy, at 2250 kcal / 9 kcal per gram.
        case .epaDha, .epa, .dha: 250
        }
    }

    // LARN average requirements are below the displayed references. A flag
    // describes recorded intake, never predicts that a symptom will occur.
    var lowIntakeRule: (threshold: Decimal, function: String)? {
        switch self {
        case .vitaminC: (75, "Produzione di collagene")
        case .zinc: (10, "Funzione immunitaria")
        case .iron: (7, "Trasporto dell’ossigeno")
        case .calcium: (750, "Mineralizzazione delle ossa")
        case .vitaminB2: (1.3, "Produzione di energia")
        case .vitaminB6: (1.4, "Metabolismo delle proteine")
        default: nil
        }
    }

    static let priorities: [Self] = [.vitaminC, .zinc]
    static let omega: [Self] = [.epaDha, .ala, .epa, .dha]
    // The grouped vitamin K row is for tracking; personal food entry retains K1/K2.
    static let micronutrients = allCases.filter { !omega.contains($0) && $0 != .vitaminK }
    static let tracked = allCases.filter { ![.vitaminK1, .vitaminK2, .epa, .dha].contains($0) }

    func value(in entry: NativeNutritionEntry) -> (amount: Decimal, estimated: Bool)? {
        if self == .epaDha || self == .vitaminK {
            let first: Self = self == .epaDha ? .epa : .vitaminK1
            let second: Self = self == .epaDha ? .dha : .vitaminK2
            guard let a = first.value(in: entry), let b = second.value(in: entry) else { return nil }
            return (a.amount + b.amount, a.estimated || b.estimated)
        }
        let value = entry.nutrientValues?[rawValue] ?? (self == .folate ? entry.nutrientValues?["folateMass"] : nil)
        guard let value else { return nil }
        return (value.amount, value.estimateSource != nil)
    }
}

struct NativeNutrientPeriod {
    let amount: Decimal?
    let daysWithValues: Int
    let daysWithEntries: Int
    let partial: Bool
    let estimated: Bool

    static func recordedDays(_ entries: [NativeNutritionEntry], count: Int, now: Date = .now) -> [[NativeNutritionEntry]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let confirmed = entries.filter { $0.confirmed && $0.deletionPending != true }
        let grouped = Dictionary(grouping: confirmed) { calendar.startOfDay(for: $0.date) }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .map { grouped[$0] ?? [] }
    }

    func progress(toward reference: Decimal) -> Double {
        guard let amount, reference > 0 else { return 0 }
        return NSDecimalNumber(decimal: min(amount / reference, 1)).doubleValue
    }

    func lowIntakeWarning(for nutrient: NativeTrackedNutrient) -> String? {
        guard daysWithValues == 7, !partial, !estimated, let amount,
              let rule = nutrient.lowIntakeRule, amount < rule.threshold else { return nil }
        return rule.function
    }

    init(_ nutrient: NativeTrackedNutrient, days: [[NativeNutritionEntry]]) {
        let values = days.map { $0.compactMap { nutrient.value(in: $0) } }
        let known = values.flatMap { $0 }
        daysWithValues = values.filter { !$0.isEmpty }.count
        daysWithEntries = days.filter { !$0.isEmpty }.count
        partial = zip(days, values).contains { $0.0.count != $0.1.count }
        estimated = known.contains { $0.estimated }
        amount = daysWithValues == 0 ? nil : known.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(daysWithValues)
    }
}

struct NativeNutrientOrdering {
    static let storageKey = "lifeos-nutrient-favorites"
    static let defaultFavorites = "vitaminC,zinc"
    static let orderKey = "lifeos-nutrient-order"

    static func keys(_ value: String) -> [NativeTrackedNutrient] {
        var seen = Set<NativeTrackedNutrient>()
        return value.split(separator: ",").compactMap { NativeTrackedNutrient(rawValue: String($0)) }
            .map { [.vitaminK1, .vitaminK2].contains($0) ? .vitaminK : $0 }
            .filter { NativeTrackedNutrient.tracked.contains($0) && seen.insert($0).inserted }
    }

    static func remaining(favorites: [NativeTrackedNutrient], order: String) -> [NativeTrackedNutrient] {
        let sorted = keys(order)
        return (sorted + NativeTrackedNutrient.tracked.filter { !sorted.contains($0) }).filter { !favorites.contains($0) }
    }

    static func encode(_ nutrients: [NativeTrackedNutrient]) -> String {
        nutrients.map(\.rawValue).joined(separator: ",")
    }
}

struct NativeNutrientProgress: View {
    let nutrient: NativeTrackedNutrient
    let period: NativeNutrientPeriod
    var caption: String? = nil
    var warning = false

    var body: some View {
        let target = nutrient.dailyReference
        let format = Decimal.FormatStyle().precision(.fractionLength(0...2))
        let current = period.amount.map { (period.estimated ? "≈" : "") + $0.formatted(format) } ?? "—"
        let value = "\(current) / \(target.formatted(format)) \(nutrient.unit)"
        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: NativeDesign.Space.small) {
                    Text(caption ?? nutrient.title).fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Text(value).monospacedDigit().foregroundStyle(.secondary)
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(caption ?? nutrient.title).fontWeight(.semibold)
                    Text(value).monospacedDigit().foregroundStyle(.secondary)
                }
            }.font(.caption)
            ProgressView(value: period.progress(toward: target))
                .tint(warning ? NativeDesign.financialRed : NativeDesign.nutritionTitle)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? nutrient.title)
        .accessibilityValue(value)
    }
}

struct NativePinnedNutrients: View {
    @AppStorage(NativeNutrientOrdering.storageKey) private var favorites = NativeNutrientOrdering.defaultFavorites
    let entries: [NativeNutritionEntry]
    var date = Date()

    var body: some View {
        let days = NativeNutrientPeriod.recordedDays(entries, count: 1, now: date)
        ForEach(NativeNutrientOrdering.keys(favorites)) { nutrient in
            NativeNutrientProgress(nutrient: nutrient, period: .init(nutrient, days: days))
                .accessibilityIdentifier("health-progress-" + nutrient.rawValue)
        }
    }
}

struct NativeMicronutrientScreen: View {
    @ObservedObject var nutrition: NativeNutritionStore
    var selectedDate = Date()
    @AppStorage(NativeNutrientOrdering.storageKey) private var favorites = NativeNutrientOrdering.defaultFavorites
    @AppStorage(NativeNutrientOrdering.orderKey) private var order = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        let pinned = NativeNutrientOrdering.keys(favorites)
        let others = NativeNutrientOrdering.remaining(favorites: pinned, order: order)
        let days = NativeHealthWeek.days(containing: selectedDate)
        let last = days.last ?? selectedDate
        let weekHasEnded = last < Calendar.current.startOfDay(for: .now)
        let weekly = NativeNutrientPeriod.recordedDays(nutrition.entries, count: 7, now: last)
        let daily = NativeNutrientPeriod.recordedDays(nutrition.entries, count: 1, now: selectedDate)
        List {
            Section("In evidenza") {
                if pinned.isEmpty { Text("Usa la stella per aggiungere un nutriente.").font(.caption) }
                ForEach(pinned) { row($0, pinned: true, daily: daily, weekly: weekly, weekHasEnded: weekHasEnded) }
                    .onMove { offsets, destination in
                        var updated = pinned
                        updated.move(fromOffsets: offsets, toOffset: destination)
                        favorites = NativeNutrientOrdering.encode(updated)
                    }
            }
            Section {
                ForEach(others) { row($0, pinned: false, daily: daily, weekly: weekly, weekHasEnded: weekHasEnded) }
                    .onMove { offsets, destination in
                        var updated = others
                        updated.move(fromOffsets: offsets, toOffset: destination)
                        order = NativeNutrientOrdering.encode(updated)
                    }
            } header: {
                Text("Micronutrienti")
            } footer: {
                Text("Riferimenti per uomini adulti. Le medie usano i giorni con dati. Vitamina B1 e ALA usano basi energetiche di 2500 e 2250 kcal rispettivamente.")
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(NativeDesign.canvas)
        .environment(\.defaultMinListRowHeight, NativeDesign.Layout.touchTarget)
        .navigationTitle("Micronutrienti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "Fine" : "Riordina") {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }.accessibilityIdentifier("micronutrient-reorder")
            }
        }
    }

    private func row(_ nutrient: NativeTrackedNutrient, pinned: Bool, daily: [[NativeNutritionEntry]], weekly: [[NativeNutritionEntry]], weekHasEnded: Bool) -> some View {
        let day = NativeNutrientPeriod(nutrient, days: daily)
        let week = NativeNutrientPeriod(nutrient, days: weekly)
        let warning = weekHasEnded ? week.lowIntakeWarning(for: nutrient) : nil
        return VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            HStack {
                Text(nutrient.title).font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    var current = NativeNutrientOrdering.keys(favorites)
                    if pinned { current.removeAll { $0 == nutrient } }
                    else { current.append(nutrient) }
                    favorites = NativeNutrientOrdering.encode(current)
                } label: {
                    Image(systemName: pinned ? "star.fill" : "star")
                        .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                }
                .buttonStyle(.borderless)
                .disabled(editMode.isEditing)
                .accessibilityLabel(pinned ? "Rimuovi \(nutrient.title) dai preferiti" : "Metti \(nutrient.title) in evidenza")
                .accessibilityIdentifier("micronutrient-star-" + nutrient.rawValue)
            }
            NativeNutrientProgress(nutrient: nutrient, period: day, caption: "Giorno")
            NativeNutrientProgress(nutrient: nutrient, period: week, caption: "Media sett.", warning: warning != nil)
            if let warning {
                Text("Apporto registrato basso · \(warning)").font(.caption2).foregroundStyle(NativeDesign.financialRed)
            }
            Text("\(week.daysWithValues)/7 giorni con dati" + (week.partial ? " · parziali" : "") + (week.estimated ? " · con stime" : ""))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: NativeDesign.Space.xxs, leading: NativeDesign.Space.medium, bottom: NativeDesign.Space.xs, trailing: NativeDesign.Space.small))
        .accessibilityIdentifier("micronutrient-" + nutrient.rawValue)
    }
}
