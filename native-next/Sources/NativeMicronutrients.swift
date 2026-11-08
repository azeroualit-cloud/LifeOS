import SwiftUI

struct NativeNutrientAmount: Codable, Equatable {
    let amount: Decimal
    let estimateSource: String?
}

enum NativeTrackedNutrient: String, CaseIterable, Identifiable {
    case vitaminC, zinc, vitaminA, vitaminD, vitaminE, vitaminK1, vitaminK2
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
        case .epaDha: "EPA + DHA"
        case .epa: "EPA"
        case .dha: "DHA"
        }
    }
    var unit: String {
        switch self {
        case .vitaminA, .vitaminD, .vitaminK1, .vitaminK2, .folate, .vitaminB12, .iodine, .selenium: "µg"
        default: "mg"
        }
    }
    static let priorities: [Self] = [.vitaminC, .zinc]
    static let omega: [Self] = [.epaDha, .ala, .epa, .dha]
    static let micronutrients = allCases.filter { !omega.contains($0) }

    func value(in entry: NativeNutritionEntry) -> (amount: Decimal, estimated: Bool)? {
        if self == .epaDha {
            guard let epa = Self.epa.value(in: entry), let dha = Self.dha.value(in: entry) else { return nil }
            return (epa.amount + dha.amount, epa.estimated || dha.estimated)
        }
        guard let value = entry.nutrientValues?[rawValue] else { return nil }
        return (value.amount, value.estimateSource != nil)
    }
}

enum NativeNutrientProfile: String, CaseIterable, Identifiable {
    case unset, adultMale, adultFemale, olderMale, olderFemale

    var id: String { rawValue }
    var title: String {
        switch self {
        case .unset: "Non impostato"
        case .adultMale: "Uomo, 18–64 anni"
        case .adultFemale: "Donna, 18–64 anni"
        case .olderMale: "Uomo, 65+ anni"
        case .olderFemale: "Donna, 65+ anni"
        }
    }

    // SINU LARN, fifth revision, adult PRI for vitamin C and zinc.
    func reference(for nutrient: NativeTrackedNutrient) -> Decimal? {
        guard self != .unset else { return nil }
        switch nutrient {
        case .vitaminC: return self == .adultMale || self == .olderMale ? 105 : 85
        case .zinc: return self == .adultMale || self == .olderMale ? 12 : 9
        case .epaDha: return 250 // EFSA adult adequate intake.
        default: return nil
        }
    }
}

struct NativeNutrientPeriod {
    let amount: Decimal?
    let daysWithValues: Int
    let daysWithEntries: Int
    let partial: Bool
    let estimated: Bool

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

struct NativeMicronutrientScreen: View {
    @ObservedObject var nutrition: NativeNutritionStore
    @AppStorage("lifeos-nutrient-reference-profile") private var profile = NativeNutrientProfile.unset
    @AppStorage("lifeos-nutrient-favorites") private var favorites = "vitaminC,zinc"

    private var favoriteNutrients: [NativeTrackedNutrient] {
        let keys = Set(favorites.split(separator: ",").map(String.init))
        return NativeTrackedNutrient.micronutrients.filter { keys.contains($0.rawValue) }
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = nutrition.entries.filter { $0.confirmed && $0.deletionPending != true }
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.map { grouped[$0] ?? [] }

        List {
            Section("In evidenza") {
                if favoriteNutrients.isEmpty {
                    Text("Scegli i preferiti in Tutti i micronutrienti.").foregroundStyle(.secondary)
                }
                ForEach(favoriteNutrients) { nutrient in
                    nutrientRow(nutrient, days: days)
                }
            }
            Section {
                NavigationLink("Tutti i micronutrienti") {
                    List {
                        ForEach(NativeTrackedNutrient.micronutrients) { nutrient in
                            nutrientRow(nutrient, days: days)
                        }
                    }
                    .modifier(NativeListAppearance())
                    .navigationTitle("Tutti i micronutrienti")
                    .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Omega‑3") {
                    List {
                        ForEach(NativeTrackedNutrient.omega) { nutrient in
                            nutrientRow(nutrient, days: days, canFavorite: false)
                        }
                        Link("Riferimenti EFSA", destination: URL(string: "https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values")!)
                    }
                    .modifier(NativeListAppearance())
                    .navigationTitle("Omega‑3")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } footer: {
                Text("I valori derivano dagli alimenti del catalogo registrati in LifeOS. I giorni senza valori restano fuori dalla media.")
            }
            Section {
                Picker("Profilo adulto", selection: $profile) {
                    ForEach(NativeNutrientProfile.allCases) { Text($0.title).tag($0) }
                }
                Link("Riferimenti LARN", destination: URL(string: "https://sinu.it/wp-content/uploads/2025/07/Tabelle-riassuntive_online.pdf")!)
            } footer: {
                Text("Riferimenti di popolazione. La quantità registrata resta visibile anche quando li raggiungi.")
            }
        }
        .modifier(NativeListAppearance())
        .navigationTitle("Micronutrienti")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nutrientRow(_ nutrient: NativeTrackedNutrient, days: [[NativeNutritionEntry]], canFavorite: Bool = true) -> some View {
        let today = NativeNutrientPeriod(nutrient, days: Array(days.prefix(1)))
        let week = NativeNutrientPeriod(nutrient, days: days)
        let reference = profile.reference(for: nutrient)
        let isFavorite = favoriteNutrients.contains(nutrient)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            HStack {
                Text(nutrient.title).font(.headline)
                Spacer(minLength: NativeDesign.Space.small)
                if canFavorite {
                    Button {
                        var keys = Set(favoriteNutrients.map(\.rawValue))
                        if isFavorite { keys.remove(nutrient.rawValue) } else { keys.insert(nutrient.rawValue) }
                        favorites = keys.sorted().joined(separator: ",")
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(isFavorite ? "Rimuovi \(nutrient.title) dai preferiti" : "Aggiungi \(nutrient.title) ai preferiti")
                }
            }
            Text("Oggi: \(formatted(today.amount, unit: nutrient.unit))")
            if let reference, let value = today.amount {
                ProgressView(value: NSDecimalNumber(decimal: min(value / reference, 1)).doubleValue)
                    .tint(NativeDesign.nutritionTitle)
                    .accessibilityLabel("Progresso di oggi")
                if value >= reference {
                    Text(today.estimated ? "Raggiunto secondo la stima" : "Raggiunto")
                        .font(.caption.weight(.semibold))
                }
            }
            if let reference {
                Text("Riferimento: \(formatted(reference, unit: nutrient.unit)) al giorno").font(.caption)
            }
            Text("Media 7 giorni: \(formatted(week.amount, unit: nutrient.unit))")
                .font(.subheadline)
            Text("\(week.daysWithValues) di 7 giorni con valori · \(week.daysWithEntries) registrati")
                .font(.caption).foregroundStyle(.secondary)
            if week.partial {
                Text("Dati parziali").font(.caption).foregroundStyle(.secondary)
            }
            if week.estimated {
                Text("Include valori stimati").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, NativeDesign.Space.xs)
        .accessibilityIdentifier("micronutrient-" + nutrient.rawValue)
    }

    private func formatted(_ amount: Decimal?, unit: String) -> String {
        guard let amount else { return "Non disponibile" }
        return amount.formatted(.number.precision(.fractionLength(0...3))) + " " + unit
    }
}
