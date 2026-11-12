import SwiftUI

struct NativePersonalFoodEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = "personal-" + UUID().uuidString
    @State private var name = ""
    @State private var brand = ""
    @State private var caffeine = ""
    @State private var nutritionNotDeclared = false
    @State private var unit: NativeSupplementUnit = .capsule
    @State private var family: NativeGenericFood.Family = .meal
    @State private var energy = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var micronutrients: [NativeTrackedNutrient: String] = [:]
    let original: NativeGenericFood?
    let save: (NativeGenericFood) -> Void

    init(original: NativeGenericFood? = nil, save: @escaping (NativeGenericFood) -> Void) {
        self.original = original
        self.save = save
        guard let original else { return }
        _identifier = State(initialValue: original.id)
        _name = State(initialValue: original.name)
        _brand = State(initialValue: original.brand ?? "")
        _nutritionNotDeclared = State(initialValue: original.nutritionNotDeclared == true)
        _family = State(initialValue: original.family)
        _unit = State(initialValue: original.quantityUnit)
        let divisor = original.basisDivisor
        func text(_ value: Decimal) -> String { NSDecimalNumber(decimal: value / divisor).stringValue }
        _energy = State(initialValue: text(original.calories))
        _protein = State(initialValue: text(original.protein))
        _carbs = State(initialValue: text(original.carbohydrate))
        _fat = State(initialValue: text(original.fat))
        _fibre = State(initialValue: original.fibre.map(text) ?? "")
        var values: [NativeTrackedNutrient: String] = [:]
        for nutrient in NativeTrackedNutrient.micronutrients + [.ala, .epa, .dha] {
            let key = nutrient == .folate ? "folateMass" : nutrient.rawValue
            if let amount = original.nutrientValues?[key]?.amount { values[nutrient] = text(amount) }
        }
        _micronutrients = State(initialValue: values)
        _caffeine = State(initialValue: original.nutrientValues?["caffeine"].map { text($0.amount) } ?? "")
    }

    var body: some View {
        Form {
            Section("Alimento") {
                TextField("Nome", text: $name).accessibilityIdentifier("personal-food-name")
                TextField("Marca, facoltativa", text: $brand).accessibilityIdentifier("personal-food-brand")
                Picker("Famiglia", selection: $family) {
                    ForEach(NativeGenericFood.Family.allCases) { family in
                        Text(family.icon + " " + family.title).tag(family)
                    }
                }
                .accessibilityIdentifier("personal-food-family")
            }
            Section {
                Toggle("Energia e macro non dichiarati", isOn: $nutritionNotDeclared)
            }
            if family == .supplement {
                Section("Formato integratore") {
                    Picker("Unità", selection: $unit) {
                        ForEach(unit == .legacyServing ? NativeSupplementUnit.editable + [.legacyServing] : NativeSupplementUnit.editable) { value in
                            Text(value.title).tag(value)
                        }
                    }.accessibilityIdentifier("personal-food-unit")
                    if unit == .legacyServing {
                        Text("Questa voce precedente conserva i valori per dose. Scegli capsule, compresse o grammi e verifica i valori prima di salvare.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section(family == .supplement ? "Valori per " + unit.basisTitle : "Valori per " + (original?.cocktail != nil ? "bicchiere" : original?.measurementBasis == "ml" ? "100 ml" : "100 g")) {
                if nutritionNotDeclared {
                    Text("Energia e macro non disponibili: non verranno inviati ad Apple Salute.").font(.caption).foregroundStyle(.secondary)
                } else {
                amount("Calorie (kcal)", text: $energy).accessibilityIdentifier("personal-food-energy")
                amount("Proteine (g)", text: $protein).accessibilityIdentifier("personal-food-protein")
                amount("Carboidrati (g)", text: $carbs).accessibilityIdentifier("personal-food-carbs")
                amount("Grassi (g)", text: $fat).accessibilityIdentifier("personal-food-fat")
                amount("Fibre (g), facoltative", text: $fibre)
                }
                if family == .supplement { amount("Caffeina (mg), facoltativa", text: $caffeine) }
            }
            if let note = original?.dataNote {
                Section { Text(note).font(.caption).foregroundStyle(.secondary) }
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
        .onChange(of: family) { _, value in
            if value == .supplement && unit == .millilitre { unit = .capsule }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(NativeDesign.nutritionCanvas)
        .navigationTitle(original == nil ? "Nuovo alimento" : "Modifica alimento")
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
        LabeledContent(label) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(label)
        }
    }

    private var food: NativeGenericFood? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unknown = nutritionNotDeclared
        guard !title.isEmpty, title.count <= 120, brand.count <= 120,
              let calories = NativeNutritionEntry.grams(energy), calories >= 0, calories <= 1000,
              (unknown || !protein.isEmpty), let protein = NativeNutritionEntry.grams(protein),
              (unknown || !carbs.isEmpty), let carbs = NativeNutritionEntry.grams(carbs),
              (unknown || !fat.isEmpty), let fat = NativeNutritionEntry.grams(fat),
              protein <= 100, carbs <= 100, fat <= 100,
              let fibreValue = NativeNutritionEntry.grams(fibre), fibreValue <= 100 else { return nil }
        guard unknown || calories > 0 || (protein == 0 && carbs == 0 && fat == 0 && fibreValue == 0) else { return nil }
        let editableKeys = Set((NativeTrackedNutrient.micronutrients + [.ala, .epa, .dha]).map { $0 == .folate ? "folateMass" : $0.rawValue })
        var nutrients = (original?.nutrientValues ?? [:]).filter { !editableKeys.contains($0.key) }
        let factor: Decimal = family == .supplement && unit != .gram ? 100 : 1
        if family == .supplement { nutrients.removeValue(forKey: "caffeine") }
        if family == .supplement, !caffeine.isEmpty {
            guard let value = NativeNutritionEntry.grams(caffeine), value <= 10000 else { return nil }
            nutrients["caffeine"] = .init(amount: value * factor, estimateSource: nil)
        }
        for (nutrient, raw) in micronutrients where !raw.isEmpty {
            guard let value = NativeNutritionEntry.grams(raw), value <= 100_000_000 else { return nil }
            let key = nutrient == .folate ? "folateMass" : nutrient.rawValue
            let amount = value * factor
            let previous = original?.nutrientValues?[key]
            nutrients[key] = .init(amount: amount, estimateSource: previous?.amount == amount ? previous?.estimateSource : nil)
        }
        var bounds = original?.estimatedMacroBounds
        if let original {
            let values: [(String, Decimal, Decimal)] = [("calories", calories * factor, original.calories),
                ("protein", protein * factor, original.protein), ("carbohydrate", carbs * factor, original.carbohydrate),
                ("fat", fat * factor, original.fat), ("fibre", fibreValue * factor, original.fibre ?? 0)]
            for (key, value, previous) in values where value != previous { bounds?.removeValue(forKey: key) }
        }
        return .init(id: identifier, name: title, detail: "Personale", family: family,
                     boneInEdiblePercent: original?.family == family ? original?.boneInEdiblePercent : nil, nutrientValues: nutrients.isEmpty ? nil : nutrients,
                     cocktail: original?.family == family ? original?.cocktail : nil, aliases: original?.aliases, protein: protein * factor, carbohydrate: carbs * factor, fat: fat * factor,
                     fibre: fibre.isEmpty ? nil : fibreValue * factor, calories: calories * factor,
                     estimatedMacroBounds: bounds?.isEmpty == false ? bounds : nil, dataNote: original?.dataNote, nutritionNotDeclared: nutritionNotDeclared ? true : nil,
                     measurementBasis: original?.measurementBasis,
                     brand: brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
                     sourceURL: original?.sourceURL, barcode: original?.barcode,
                     supplementUnit: family == .supplement ? unit : nil,
                     defaultQuantity: original?.family == family && (family != .supplement || original?.quantityUnit == unit) ? original?.defaultQuantity : nil)
    }
}
