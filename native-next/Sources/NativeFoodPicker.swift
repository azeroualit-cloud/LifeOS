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
        case meat, fish, meal, pantry, drink, sweet, vegetable

        var id: String { rawValue }
        var title: String {
            switch self {
            case .bakery: "Pane e forno"
            case .grain: "Cereali"
            case .egg: "Uova"
            case .dairy: "Latte e yogurt"
            case .cheese: "Formaggi"
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

    func portion(id: UUID, date: Date, grams: Decimal, weighedWithBone: Bool = false) -> NativeNutritionEntry? {
        if let cocktail {
            guard !weighedWithBone, grams > 0, grams <= 100,
                  var entry = NativeNutritionEntry.portion(id: id, date: date, protein: protein,
                      carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories, grams: grams * 100) else { return nil }
            entry.portionGrams = nil
            entry.cocktailServings = grams
            entry.alcoholGrams = cocktail.alcoholGrams * grams
            entry.foodName = name
            return entry
        }
        let edibleGrams: Decimal
        if weighedWithBone {
            guard let percent = boneInEdiblePercent, (1..<100).contains(percent) else { return nil }
            edibleGrams = grams * Decimal(percent) / 100
        } else {
            edibleGrams = grams
        }
        guard var entry = NativeNutritionEntry.portion(id: id, date: date, protein: protein,
            carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories, grams: edibleGrams) else { return nil }
        entry.foodName = name
        entry.boneInWeightGrams = weighedWithBone ? grams : nil
        entry.nutrientValues = nutrientValues?.mapValues {
            NativeNutrientAmount(amount: $0.amount * edibleGrams / 100, estimateSource: $0.estimateSource)
        }
        return entry
    }

    // Anses. 2025. Ciqual French food composition table. Values per 100 g.
    static func matches(_ query: String, in foods: [Self]? = nil) -> [Self] {
        let foods = foods ?? catalog
        let words = searchWords(query)
        guard !words.isEmpty else { return Array(foods.prefix(24)) }

        return foods.compactMap { food -> (food: Self, rank: Int)? in
            let name = searchWords(food.name)
            let aliases = (food.aliases ?? []).map(searchWords)
            if words == name { return (food, 0) }
            if aliases.contains(words) { return (food, 1) }
            let fields = name + searchWords(food.detail ?? "") + aliases.flatMap { $0 } + (food.cocktail == nil ? [] : ["cocktail"])
            guard words.allSatisfy({ word in fields.contains { $0.hasPrefix(word) } }) else { return nil }
            let rank = words.allSatisfy { word in name.contains { $0.hasPrefix(word) } } ? 2 : 3
            return (food, rank)
        }.sorted { $0.rank < $1.rank }.map { $0.food }
    }

    private static func searchWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    static let foods = loadCatalog("generic-foods")
    static let cocktails = loadCatalog("cocktails")
    static let catalog = foods + cocktails

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
    @State private var creating = false
    @State private var storageError = false
    @AppStorage("lifeos-personal-foods-v1") private var personalData = Data()

    private enum Scope: String, CaseIterable, Identifiable {
        case all = "Tutti", cocktails = "Cocktail", personal = "Personali"
        var id: Self { self }
    }

    private var personalFoods: [NativeGenericFood]? {
        personalData.isEmpty ? [] : try? JSONDecoder().decode([NativeGenericFood].self, from: personalData)
    }

    private var visibleFoods: [NativeGenericFood] {
        switch scope {
        case .all: (personalFoods ?? []) + NativeGenericFood.catalog
        case .cocktails: NativeGenericFood.cocktails
        case .personal: personalFoods ?? []
        }
    }
    let select: (NativeGenericFood) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        let matches = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && scope != .all
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
                if scope != .cocktails {
                    Button {
                        searchFocused = false
                        creating = true
                    } label: {
                        Label("Crea alimento generico", systemImage: "plus.circle")
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                    }
                    .accessibilityIdentifier("generic-food-create")
                    .listRowBackground(NativeDesign.nutritionInput)
                }
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
                                    if let detail = food.detail {
                                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    if let cocktail = food.cocktail {
                                        Text("≈ \(NSDecimalNumber(decimal: food.calories)) kcal · \(cocktail.volumeML) ml / bicchiere")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("\(NSDecimalNumber(decimal: food.calories)) kcal / 100 g")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }.frame(minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                            }
                        }.accessibilityIdentifier("generic-food-" + food.id)
                            .listRowBackground(NativeDesign.nutritionInput)
                            .swipeActions {
                                if scope == .personal {
                                    Button("Elimina", role: .destructive) {
                                        if let foods = personalFoods { persist(foods.filter { $0.id != food.id }) }
                                    }
                                }
                            }
                    }
                    if matches.isEmpty {
                        Text(scope == .personal && query.isEmpty ? "Nessun alimento personale" : "Nessun alimento trovato")
                            .foregroundStyle(.secondary)
                            .listRowBackground(NativeDesign.nutritionInput)
                    }
                } footer: {
                    if scope == .cocktails {
                        Text("Ricette di riferimento · quantità e gradazioni stimate")
                    } else if scope == .all {
                        Text("Alimenti generici · Anses Ciqual 2025")
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

private struct NativePersonalFoodEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var family: NativeGenericFood.Family = .meal
    @State private var energy = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var micronutrients: [NativeTrackedNutrient: String] = [:]
    let save: (NativeGenericFood) -> Void

    var body: some View {
        Form {
            Section("Alimento") {
                TextField("Nome", text: $name).accessibilityIdentifier("personal-food-name")
                Picker("Famiglia", selection: $family) {
                    ForEach(NativeGenericFood.Family.allCases) { family in
                        Text(family.icon + " " + family.title).tag(family)
                    }
                }
            }
            Section("Valori per 100 g") {
                amount("Calorie (kcal)", text: $energy).accessibilityIdentifier("personal-food-energy")
                amount("Proteine (g)", text: $protein).accessibilityIdentifier("personal-food-protein")
                amount("Carboidrati (g)", text: $carbs).accessibilityIdentifier("personal-food-carbs")
                amount("Grassi (g)", text: $fat).accessibilityIdentifier("personal-food-fat")
                amount("Fibre (g), facoltative", text: $fibre)
            }
            Section {
                DisclosureGroup("Micronutrienti e omega-3, facoltativi") {
                    ForEach(NativeTrackedNutrient.micronutrients + [.ala, .epa, .dha]) { nutrient in
                        amount(nutrient.title + " (" + nutrient.unit + ")", text: Binding(
                            get: { micronutrients[nutrient] ?? "" },
                            set: { micronutrients[nutrient] = $0 }
                        ))
                    }
                }
            } footer: {
                Text("I valori facoltativi vuoti restano non disponibili.")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(NativeDesign.nutritionCanvas)
        .navigationTitle("Nuovo alimento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") { if let food { save(food) } }
                    .disabled(food == nil)
                    .accessibilityIdentifier("personal-food-save")
            }
        }
    }

    private func amount(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text).keyboardType(.decimalPad)
    }

    private var food: NativeGenericFood? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120,
              let calories = NativeNutritionEntry.grams(energy), calories > 0, calories <= 1000,
              !protein.isEmpty, let protein = NativeNutritionEntry.grams(protein),
              !carbs.isEmpty, let carbs = NativeNutritionEntry.grams(carbs),
              !fat.isEmpty, let fat = NativeNutritionEntry.grams(fat),
              protein <= 100, carbs <= 100, fat <= 100,
              let fibreValue = NativeNutritionEntry.grams(fibre), fibreValue <= 100 else { return nil }
        var nutrients: [String: NativeNutrientAmount] = [:]
        for (nutrient, raw) in micronutrients where !raw.isEmpty {
            guard let value = NativeNutritionEntry.grams(raw), value <= 100_000_000 else { return nil }
            let key = nutrient == .folate ? "folateMass" : nutrient.rawValue
            nutrients[key] = .init(amount: value, estimateSource: nil)
        }
        return .init(id: "personal-" + UUID().uuidString, name: title, detail: "Personale", family: family,
                     boneInEdiblePercent: nil, nutrientValues: nutrients.isEmpty ? nil : nutrients,
                     aliases: nil, protein: protein, carbohydrate: carbs, fat: fat,
                     fibre: fibre.isEmpty ? nil : fibreValue, calories: calories)
    }
}
