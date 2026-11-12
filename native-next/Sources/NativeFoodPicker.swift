import SwiftUI

struct NativeGenericFood: Codable, Identifiable {
    let id: String
    let name: String
    let detail: String?
    let family: Family
    let boneInEdiblePercent: Int?
    let nutrientValues: [String: NativeNutrientAmount]?
    var cocktail: Cocktail? = nil

    struct Cocktail: Codable {
        let volumeML: Int
        let alcoholGrams: Decimal
        let source: String
    }

    enum Family: String, Codable, CaseIterable, Identifiable {
        case bakery, grain, egg, dairy, cheese, fat, legume, fruit, nut, poultry
        case meat, fish, meal, pantry, drink, sweet, vegetable, supplement

        var id: String { rawValue }
        var title: String {
            switch self {
            case .bakery: "Pane e forno"
            case .grain: "Cereali"
            case .egg: "Uova"
            case .dairy: "Latte e yogurt"
            case .cheese: "Formaggi"
            case .supplement: "Integratori"
            case .fat: "Oli e burri"
            case .legume: "Legumi"
            case .fruit: "Frutta"
            case .nut: "Frutta secca"
            case .poultry: "Pollame"
            case .meat: "Carne"
            case .fish: "Pesce"
            case .meal: "Piatti pronti"
            case .pantry: "Dispensa"
            case .drink: "Bevande"
            case .sweet: "Dolci"
            case .vegetable: "Verdure"
            }
        }
        var icon: String {
            switch self {
            case .bakery: "🍞"
            case .grain: "🌾"
            case .egg: "🥚"
            case .dairy: "🥛"
            case .cheese: "🧀"
            case .supplement: "💊"
            case .fat: "🫗"
            case .legume: "🫘"
            case .fruit: "🍎"
            case .nut: "🥜"
            case .poultry: "🍗"
            case .meat: "🥩"
            case .fish: "🐟"
            case .meal: "🍽️"
            case .pantry: "🫙"
            case .drink: "🥤"
            case .sweet: "🍫"
            case .vegetable: "🥦"
            }
        }
    }
    let aliases: [String]?
    let protein: Decimal
    let carbohydrate: Decimal
    let fat: Decimal
    let fibre: Decimal?
    let calories: Decimal
    var zeroEnergyLabelVerified: Bool? = nil
    var estimatedMacroBounds: [String: String]? = nil
    var dataNote: String? = nil
    var nutritionNotDeclared: Bool? = nil
    var measurementBasis: String? = nil
    var brand: String? = nil
    var sourceURL: String? = nil
    var barcode: String? = nil
    var supplementUnit: NativeSupplementUnit? = nil
    var defaultQuantity: Decimal? = nil

    var quantityUnit: NativeSupplementUnit { family == .supplement ? (supplementUnit ?? .legacyServing) : (measurementBasis == "ml" ? .millilitre : .gram) }
    var basisDivisor: Decimal { family == .supplement && quantityUnit != .gram ? 100 : 1 }
    var displayDetail: String? { brand.map { $0 + (id.hasPrefix("personal-") ? " · Personale" : "") } ?? detail }

    func portion(id: UUID, date: Date, grams: Decimal, weighedWithBone: Bool = false) -> NativeNutritionEntry? {
        if let cocktail {
            guard !weighedWithBone, grams > 0, grams <= 100,
                  var entry = NativeNutritionEntry.portion(id: id, date: date, protein: protein,
                      carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories, grams: grams * 100) else { return nil }
            entry.portionGrams = nil
            entry.cocktailServings = grams
            entry.alcoholGrams = cocktail.alcoholGrams * grams
            entry.foodName = name
            entry.foodID = self.id
            return entry
        }
        if family == .supplement && quantityUnit != .gram && grams > 100 { return nil }
        let edibleGrams: Decimal
        if weighedWithBone {
            guard let percent = boneInEdiblePercent, (1..<100).contains(percent) else { return nil }
            edibleGrams = grams * Decimal(percent) / 100
        } else {
            edibleGrams = grams
        }
        guard var entry = NativeNutritionEntry.portion(id: id, date: date, protein: protein,
            carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories, grams: edibleGrams, allowZeroLabelEnergy: zeroEnergyLabelVerified == true) else { return nil }
        entry.foodName = name
        entry.nutritionNotDeclared = nutritionNotDeclared
        entry.macroEstimateSource = estimatedMacroBounds.map { bounds in "Etichetta, limiti superiori: " + bounds.keys.sorted().map { $0 + " " + (bounds[$0] ?? "") }.joined(separator: "; ") }
        if family == .supplement {
            entry.portionGrams = quantityUnit == .gram ? grams : nil
            entry.supplementQuantity = grams
            entry.supplementUnit = quantityUnit.rawValue
        }
        if quantityUnit == .millilitre {
            entry.portionGrams = nil
            entry.portionMillilitres = grams
        }
        entry.foodID = self.id
        entry.boneInWeightGrams = weighedWithBone ? grams : nil
        entry.nutrientValues = nutrientValues?.mapValues {
            NativeNutrientAmount(amount: $0.amount * edibleGrams / 100, estimateSource: $0.estimateSource)
        }
        return entry
    }

    func personalCopy() -> Self {
        .init(id: "personal-" + UUID().uuidString, name: name, detail: "Personale", family: family,
              boneInEdiblePercent: boneInEdiblePercent, nutrientValues: nutrientValues, cocktail: cocktail,
              aliases: aliases, protein: protein, carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories,
              zeroEnergyLabelVerified: zeroEnergyLabelVerified, estimatedMacroBounds: estimatedMacroBounds, dataNote: dataNote, nutritionNotDeclared: nutritionNotDeclared, measurementBasis: measurementBasis, brand: brand, sourceURL: sourceURL, barcode: barcode, supplementUnit: supplementUnit, defaultQuantity: defaultQuantity)
    }

    // Anses. 2025. Ciqual French food composition table. Values per 100 g.
    static func matches(_ query: String, in foods: [Self]? = nil) -> [Self] {
        let foods = foods ?? catalog
        let words = searchWords(query)
        guard !words.isEmpty else { return Array(foods.prefix(24)) }

        return foods.enumerated().compactMap { index, food -> (food: Self, rank: Int, index: Int)? in
            let name = searchWords(food.name)
            let aliases = (food.aliases ?? []).map(searchWords)
            if words == name { return (food, 0, index) }
            if aliases.contains(words) { return (food, 1, index) }
            let fields = name + searchWords(food.displayDetail ?? "") + aliases.flatMap { $0 } + (food.cocktail == nil ? [] : ["cocktail"])
            guard words.allSatisfy({ word in fields.contains { $0.hasPrefix(word) } }) else { return nil }
            let rank = words.allSatisfy { word in name.contains { $0.hasPrefix(word) } } ? 2 : 3
            return (food, rank, index)
        }.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.map { $0.food }
    }

    private static func searchWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    static func ranked(_ foods: [Self], entries: [NativeNutritionEntry], now: Date = .now, calendar: Calendar = .current) -> [Self] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -29, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return foods }
        let byName = Dictionary(grouping: foods, by: { $0.name })
        var counts: [String: Int] = [:]
        for entry in entries where entry.confirmed && entry.deletionPending != true && entry.date >= start && entry.date < end {
            let names = entry.foodName.flatMap { byName[$0] }
            let legacyID = names?.count == 1 ? names?.first?.id : nil
            if let key = entry.foodID ?? legacyID { counts[key, default: 0] += 1 }
        }
        return foods.enumerated().sorted {
            let a = counts[$0.element.id, default: 0], b = counts[$1.element.id, default: 0]
            return a == b ? $0.offset < $1.offset : a > b
        }.map(\.element)
    }

    static let foods = loadCatalog("generic-foods")
    static let cocktails = loadCatalog("cocktails")
    static let catalog = foods + cocktails + supplements + brandedFoods + brandedSupplements
    static let brandedFoods = loadCatalog("branded-foods")
    static let brandedSupplements = loadCatalog("branded-supplements")
    static let supplements = loadCatalog("supplements")

    private static func loadCatalog(_ name: String) -> [Self] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return foods
    }
}

struct NativeFoodPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope: Scope = .all
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current
    @State private var creating = false
    @State private var editingFood: NativeGenericFood?
    @State private var copyingFood = false
    @State private var storageError = false
    @AppStorage("lifeos-personal-foods-v1") private var personalData = Data()

    private enum Scope: String, CaseIterable, Identifiable {
        case all = "Tutti", personal = "Personali"
        var id: Self { self }
    }

    private var personalFoods: [NativeGenericFood]? {
        personalData.isEmpty ? [] : try? JSONDecoder().decode([NativeGenericFood].self, from: personalData)
    }

    private var visibleFoods: [NativeGenericFood] {
        switch scope {
        case .all: NativeGenericFood.ranked(NativeGenericFood.catalog + (personalFoods ?? []), entries: nutrition.entries)
        case .personal: personalFoods ?? []
        }
    }
    let select: (NativeGenericFood) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        let matches = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? visibleFoods : NativeGenericFood.matches(query, in: visibleFoods)

        VStack(spacing: NativeDesign.Space.none) {
            HStack(spacing: NativeDesign.Space.small) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Cerca alimento", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("generic-food-search")
            }
            .padding(.horizontal, NativeDesign.Space.medium)
            .frame(minHeight: NativeDesign.Layout.touchTarget)
            .background(NativeDesign.nutritionInput, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .padding(.horizontal, NativeDesign.Layout.screenInset)

            Picker("Tipo di alimento", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.small)

            List {
                Button {
                    searchFocused = false
                    creating = true
                } label: {
                    Label("Crea alimento generico", systemImage: "plus.circle")
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                }
                .accessibilityIdentifier("generic-food-create")
                .listRowBackground(NativeDesign.nutritionInput)
                Section {
                    ForEach(matches) { food in
                        Button {
                            select(food)
                            dismiss()
                        } label: {
                            HStack(spacing: NativeDesign.Space.medium) {
                                Text(food.cocktail == nil ? food.family.icon : "🍸").font(.title3).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                                    Text(food.name)
                                    if let detail = food.displayDetail {
                                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    if let cocktail = food.cocktail {
                                        Text("≈ \(NSDecimalNumber(decimal: food.calories)) kcal · \(cocktail.volumeML) ml / bicchiere")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text(food.nutritionNotDeclared == true ? "Energia e macro non dichiarati" : "\(NSDecimalNumber(decimal: food.calories / food.basisDivisor).doubleValue.formatted(.number.precision(.fractionLength(0...1)))) kcal / \(food.quantityUnit.basisTitle)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }.frame(minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                            }
                        }.accessibilityIdentifier("generic-food-" + food.id)
                            .listRowBackground(NativeDesign.nutritionInput)
                            .swipeActions {
                                if personalFoods?.contains(where: { $0.id == food.id }) == true {
                                    Button("Modifica") { copyingFood = false; editingFood = food }.tint(.blue)
                                    Button("Elimina", role: .destructive) {
                                        if let foods = personalFoods { persist(foods.filter { $0.id != food.id }) }
                                    }
                                } else {
                                    Button("Personalizza") { copyingFood = true; editingFood = food }.tint(.blue)
                                }
                            }
                    }
                    if matches.isEmpty {
                        Text(scope == .personal && query.isEmpty ? "Nessun alimento personale" : "Nessun alimento trovato")
                            .foregroundStyle(.secondary)
                            .listRowBackground(NativeDesign.nutritionInput)
                    }
                } footer: {
                    if scope == .all {
                        Text("Alimenti generici · Anses Ciqual 2025 · Cocktail con valori stimati")
                    }
                }
            }
            .modifier(NativeListAppearance(background: NativeDesign.nutritionCanvas))
            .scrollDismissesKeyboard(.interactively)
        }
        .background(NativeDesign.nutritionCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { DoneButton() }
        .sheet(isPresented: $creating) {
            NavigationStack {
                NativePersonalFoodEditor { food in
                    guard let foods = personalFoods, persist(foods + [food]) else {
                        storageError = true
                        return
                    }
                    query = ""
                    scope = .personal
                    creating = false
                }
            }
        }
        .sheet(item: $editingFood) { original in
            NavigationStack {
                NativePersonalFoodEditor(original: original) { food in
                    guard let foods = personalFoods else { storageError = true; return }
                    var updated = foods
                    if copyingFood {
                        updated.append(food.personalCopy())
                    } else {
                        guard let index = foods.firstIndex(where: { $0.id == original.id }) else { storageError = true; return }
                        updated[index] = food
                    }
                    if persist(updated) { editingFood = nil; scope = .personal; query = "" }
                }
            }
        }
        .alert("Archivio alimenti personali non disponibile", isPresented: $storageError) {
            Button("OK", role: .cancel) {}
        }
    }

    @discardableResult private func persist(_ foods: [NativeGenericFood]) -> Bool {
        guard let data = try? JSONEncoder().encode(foods) else {
            storageError = true
            return false
        }
        personalData = data
        return true
    }
}
