import SwiftUI

struct NativeGenericFood: Codable, Identifiable {
    let id: String
    let name: String
    let detail: String?
    let family: Family
    let boneInEdiblePercent: Int?
    var nutrientValues: [String: NativeNutrientAmount]?
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
    /// Natural units for foods eaten by the piece (FOOD-CATALOG-92), e.g. an egg
    /// is about 50 g edible. Values stay per 100 g; a piece is just a gram preset.
    var pieces: [Piece]? = nil
    /// Branded products rarely declare micronutrients: the catalog points them
    /// at the closest generic food and the values are shown as estimates.
    var nutrientEstimateFrom: String? = nil
    struct Piece: Codable, Hashable, Identifiable {
        let name: String
        let grams: Decimal
        var id: String { name }
    }

    var isCommunitySourced: Bool {
        guard let sourceURL, let host = URL(string: sourceURL)?.host?.lowercased() else { return false }
        return host == "openfoodfacts.org" || host.hasSuffix(".openfoodfacts.org")
    }
    var quantityUnit: NativeSupplementUnit { family == .supplement ? (supplementUnit ?? .legacyServing) : (measurementBasis == "ml" ? .millilitre : .gram) }
    var basisDivisor: Decimal { family == .supplement && !quantityUnit.isMassOrVolume ? 100 : 1 }
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
        if family == .supplement && !quantityUnit.isMassOrVolume && grams > 100 { return nil }
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
              zeroEnergyLabelVerified: zeroEnergyLabelVerified, estimatedMacroBounds: estimatedMacroBounds, dataNote: dataNote, nutritionNotDeclared: nutritionNotDeclared, measurementBasis: measurementBasis, brand: brand, sourceURL: sourceURL, barcode: barcode, supplementUnit: supplementUnit, defaultQuantity: defaultQuantity, pieces: pieces, nutrientEstimateFrom: nutrientEstimateFrom)
    }

    // Cache public catalog tokenization; personal edits are indexed from their current values.
    private struct SearchDocument {
        let name: [String]
        let aliases: [[String]]
        let fields: [String]
        init(_ food: NativeGenericFood) {
            name = NativeGenericFood.searchWords(food.name)
            aliases = (food.aliases ?? []).map(NativeGenericFood.searchWords)
            fields = name + NativeGenericFood.searchWords(food.displayDetail ?? "") + aliases.flatMap { $0 } + (food.cocktail == nil ? [] : ["cocktail"])
        }

    }
    private static let searchIndex: [String: SearchDocument] = Dictionary(
        catalog.map { ($0.id, SearchDocument($0)) }, uniquingKeysWith: { first, _ in first })

    static func matches(_ query: String, in foods: [Self]? = nil) -> [Self] {
        let foods = foods ?? catalog
        let words = searchWords(query)
        guard !words.isEmpty else { return Array(foods.prefix(24)) }
        let barcodeQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return foods.enumerated().compactMap { index, food -> (food: Self, rank: Int, index: Int)? in
            if food.barcode == barcodeQuery { return (food, 0, index) }
            let document = food.id.hasPrefix("personal-") ? SearchDocument(food) : (searchIndex[food.id] ?? SearchDocument(food))
            if words == document.name { return (food, 1, index) }
            if document.aliases.contains(words) { return (food, 2, index) }
            guard words.allSatisfy({ word in document.fields.contains { $0.hasPrefix(word) } }) else { return nil }
            let nameMatch = words.allSatisfy { word in document.name.contains { $0.hasPrefix(word) } }
            let startsName = document.name.starts(with: words)
            return (food, startsName ? 3 : (nameMatch ? 4 : 5), index)
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
        // Without recent use every count ties and the original order is the result.
        guard !counts.isEmpty else { return foods }
        return foods.enumerated().sorted {
            let a = counts[$0.element.id, default: 0], b = counts[$1.element.id, default: 0]
            return a == b ? $0.offset < $1.offset : a > b
        }.map(\.element)
    }

    static let foods = loadCatalog("generic-foods")
    static let cocktails = loadCatalog("cocktails")
    /// No preset supplements (SUPPLEMENTS-PERSONAL-ONLY-92): the user adds his own.
    static let catalog = withEstimatedNutrients(foods + cocktails + brandedFoods + italianBrands + communityFoods).filter { $0.family != .supplement && NativeFoodCatalogPolicy.includes($0) }

    /// FOOD-CATALOG-92: fill undeclared micronutrients from the referenced generic
    /// food, marked as estimates so totals show the "stimato" state.
    static func withEstimatedNutrients(_ items: [Self]) -> [Self] {
        let generic = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return items.map { item in
            guard item.nutrientValues == nil, item.nutritionNotDeclared != true, let reference = item.nutrientEstimateFrom,
                  let source = generic[reference], let values = source.nutrientValues else { return item }
            // A dry product matched to a cooked generic (or the reverse) differs mostly
            // by water: follow the energy ratio when it is clearly different.
            var factor: Decimal = 1
            if item.calories > 0, source.calories > 0 {
                let ratio = item.calories / source.calories
                if ratio < 0.75 || ratio > 1.33 { factor = min(5, max(0.2, ratio)) }
            }
            var copy = item
            copy.nutrientValues = values.mapValues { NativeNutrientAmount(amount: $0.amount * factor, estimateSource: "stima:generico:" + reference) }
            return copy
        }
    }
    static let communityFoods = loadCatalog("open-food-facts-italy")
    static let italianBrands = loadCatalog("italian-brands")
    static let brandedFoods = loadCatalog("branded-foods")
    static let catalogFoods = catalog.filter { $0.family != .supplement }
    static let catalogSupplements: [NativeGenericFood] = []

    /// Decode the bundled catalog and its search index away from the main thread,
    /// so the first opening of the picker does not wait for the JSON resources.
    static func preload() async {
        await Task.detached(priority: .utility) { () -> Void in
            _ = NativeGenericFood.catalogFoods.count
            _ = NativeGenericFood.catalogSupplements.count
            _ = NativeGenericFood.searchIndex.count
        }.value
    }

    private static func loadCatalog(_ name: String) -> [Self] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return foods
    }
}

/// The ranked list for one scope, personal list, journal and day. Typing in the
/// search field reuses it instead of ranking the whole catalog for every letter.
private final class NativeFoodListCache {
    var scope: NativeFoodPicker.Scope?
    var personalData = Data()
    var entries: [NativeNutritionEntry] = []
    var day = Date.distantPast
    var foods: [NativeGenericFood] = []
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
    @State private var listCache = NativeFoodListCache()

    enum Scope: String, CaseIterable, Identifiable {
        case all = "Tutti", personal = "Personali", supplements = "Integratori"
        var id: Self { self }
    }

    private var personalFoods: [NativeGenericFood]? {
        personalData.isEmpty ? [] : try? JSONDecoder().decode([NativeGenericFood].self, from: personalData)
    }

    private func visibleFoods(_ personal: [NativeGenericFood]) -> [NativeGenericFood] {
        let day = Calendar.current.startOfDay(for: .now)
        if listCache.scope == scope, listCache.personalData == personalData, listCache.day == day, listCache.entries == nutrition.entries { return listCache.foods }
        let foods = rankedFoods(personal)
        listCache.scope = scope; listCache.personalData = personalData; listCache.day = day
        listCache.entries = nutrition.entries; listCache.foods = foods
        return foods
    }
    private func rankedFoods(_ personal: [NativeGenericFood]) -> [NativeGenericFood] {
        switch scope {
        case .all: NativeGenericFood.ranked(Self.items(in: .all, personal: personal), entries: nutrition.entries)
        case .supplements: NativeGenericFood.ranked(Self.items(in: .supplements, personal: personal), entries: nutrition.entries)
        case .personal: personal
        }
    }
    static func items(in scope: Scope, personal: [NativeGenericFood]) -> [NativeGenericFood] {
        switch scope {
        case .all: NativeGenericFood.catalogFoods + personal.filter { $0.family != .supplement }
        case .personal: personal
        case .supplements: NativeGenericFood.catalogSupplements + personal.filter { $0.family == .supplement }
        }
    }
    /// FOOD-QUICK-ADD-2026-11-23: grams typed first, the + on a result records that quantity at once.
    var quickQuantity: Binding<String>? = nil
    /// FOOD-QUICK-ADD (choice A): one field, «avena 63» — the name filters, the number is the quantity.
    var quickAdd: ((NativeGenericFood, Decimal?) -> Void)? = nil
    var onManual: (() -> Void)? = nil
    var confirmation: String? = nil
    /// Quick mode extra row (SUPPLEMENT-STACK-2026-11-23: the stacks).
    var accessory: AnyView? = nil
    let select: (NativeGenericFood) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        // Decode the personal list once per render, not once per row.
        let personal = personalFoods
        let personalIDs = Set((personal ?? []).map(\.id))
        let visible = visibleFoods(personal ?? [])
        let parsed = quickAdd == nil ? NativeQuickQuery(name: query, quantity: nil) : NativeQuickQuery.parse(query)
        let matches = parsed.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? visible : NativeGenericFood.matches(parsed.name, in: visible)

        VStack(spacing: NativeDesign.Space.none) {
            HStack(spacing: NativeDesign.Space.small) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField(quickAdd != nil ? "es. avena 63" : scope == .supplements ? "Cerca integratore o marca" : "Cerca alimento, marca o codice a barre", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier(quickAdd != nil ? "food-quick-search" : "generic-food-search")
                if quickAdd != nil, let grams = parsed.quantity {
                    Text(NSDecimalNumber(decimal: grams).stringValue + " g").font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(NativeDesign.nutritionTitle).accessibilityIdentifier("food-quick-quantity")
                }
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
            if let accessory { accessory }
            if let onManual {
                // Secondary but always visible: the macros typed one by one.
                HStack {
                    Spacer()
                    Button { searchFocused = false; onManual() } label: {
                        Label("Inserisci i macro a mano", systemImage: "square.and.pencil").font(.footnote)
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                    }
                    .accessibilityIdentifier("food-quick-manual")
                }
                .padding(.horizontal, NativeDesign.Layout.screenInset)
            }

            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(NativeDesign.nutritionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, NativeDesign.Layout.screenInset)
                    .accessibilityIdentifier("food-quick-added")
            }
            List {
                Button {
                    searchFocused = false
                    creating = true
                } label: {
                    Label(scope == .supplements ? "Crea integratore" : "Crea alimento personale", systemImage: "plus.circle")
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                }
                .accessibilityIdentifier(quickAdd != nil ? "food-quick-create" : "generic-food-create")
                .listRowBackground(NativeDesign.nutritionInput)
                Section {
                    ForEach(matches) { food in
                        HStack(spacing: NativeDesign.Space.small) {
                        Button {
                            select(food)
                            if quickAdd == nil { dismiss() }
                        } label: {
                            HStack(spacing: NativeDesign.Space.medium) {
                                Text(food.cocktail == nil ? food.family.icon : "🍸").font(.headline).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                                    Text(food.name)
                                    if let detail = food.displayDetail {
                                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    if food.isCommunitySourced {
                                        Text("Open Food Facts · dati collaborativi").font(.footnote).foregroundStyle(.secondary)
                                    }
                                    if let cocktail = food.cocktail {
                                        Text("≈ \(NSDecimalNumber(decimal: food.calories)) kcal · \(cocktail.volumeML) ml / bicchiere")
                                            .font(.footnote).foregroundStyle(.secondary)
                                    } else {
                                        Text((food.nutritionNotDeclared == true ? "Energia e macro non dichiarati" : "per \(food.quantityUnit.basisTitle)") + " · " + (personalIDs.contains(food.id) ? "Personale" : "Catalogo"))
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                }.frame(minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                                Spacer(minLength: NativeDesign.Space.small)
                                if food.cocktail == nil && food.nutritionNotDeclared != true {
                                    Text(NSDecimalNumber(decimal: food.calories / food.basisDivisor).doubleValue.formatted(.number.precision(.fractionLength(0))) + " kcal")
                                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                                }
                                if quickAdd == nil {
                                    Image(systemName: "plus.circle.fill").font(.headline).foregroundStyle(NativeDesign.nutritionTitle).accessibilityHidden(true)
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("generic-food-" + food.id)
                        if let quickAdd {
                            Button { quickAdd(food, parsed.quantity); query = ""; searchFocused = true } label: {
                                Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(NativeDesign.nutritionTitle)
                                    .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Aggiungi " + food.name)
                            .accessibilityIdentifier("generic-food-add-" + food.id)
                        }
                        }
                            .listRowBackground(NativeDesign.nutritionInput)
                            .swipeActions {
                                if personalIDs.contains(food.id) {
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
                }

            }
            .modifier(NativeListAppearance(background: NativeDesign.nutritionCanvas))
            .scrollDismissesKeyboard(.interactively)
        }
        .background(NativeDesign.nutritionCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { DoneButton() }
        // Build 93 "Aggiungi alimento": the search is ready to type as soon as the sheet opens.
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !creating && editingFood == nil { searchFocused = true }
        }
        .sheet(isPresented: $creating) {
            NavigationStack {
                NativePersonalFoodEditor(initialFamily: scope == .supplements ? .supplement : .meal) { food in
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
        let previous = personalFoods ?? []
        personalData = data
        NativeOnlineSync.shared.foodsChanged(old: previous, new: foods)
        return true
    }
}

/// «avena 63», «63 avena», «yogurt greco 150 g», «latte 200ml»: name and quantity in one field.
struct NativeQuickQuery: Equatable {
    var name: String
    var quantity: Decimal?
    static func parse(_ text: String) -> NativeQuickQuery {
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let units: Set<String> = ["g", "gr", "grammi", "grammo", "ml"]
        func number(_ word: String) -> Decimal? {
            var w = word.lowercased()
            for unit in ["grammi", "grammo", "gr", "ml", "g"] where w.hasSuffix(unit) && w.count > unit.count { w.removeLast(unit.count); break }
            guard w.range(of: "^[0-9]+([.,][0-9]+)?$", options: .regularExpression) != nil,
                  let value = Decimal(string: w.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")),
                  value > 0, value <= 9999 else { return nil }
            return value
        }
        if let last = words.last, units.contains(last.lowercased()), words.count >= 2, number(words[words.count - 2]) != nil { words.removeLast() }
        if let last = words.last, let value = number(last), words.count >= 2 { words.removeLast(); return .init(name: words.joined(separator: " "), quantity: value) }
        if let first = words.first, let value = number(first), words.count >= 2 { words.removeFirst(); return .init(name: words.joined(separator: " "), quantity: value) }
        return .init(name: text, quantity: nil)
    }
}
