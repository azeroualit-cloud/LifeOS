import SwiftUI

/// FOOD-LOG-EDIT-2026-11-25 («per evitare di eliminare un cibo e rimetterlo solo perché ho sbagliato qualche grammo»):
/// a logged food keeps its id and changes quantity and time; every stored amount scales by the same factor.
struct NativeLoggedQuantity: Equatable {
    let value: Decimal
    let unit: String
    let title: String
    let steps: [Decimal]
    let maximum: Decimal
}

extension NativeNutritionEntry {
    /// The quantity the user typed when logging, in the unit shown in the diary.
    var loggedQuantity: NativeLoggedQuantity? {
        if let grams = boneInWeightGrams, grams > 0 { return .init(value: grams, unit: "g con osso", title: "Peso con osso", steps: [10, 1], maximum: 9999) }
        if let quantity = supplementQuantity, quantity > 0 {
            let unit = supplementUnit.flatMap(NativeSupplementUnit.init(rawValue:))
            if let unit, unit.isMassOrVolume {
                return .init(value: quantity, unit: unit == .millilitre ? "ml" : "g", title: "Quantità", steps: [10, 1], maximum: 9999)
            }
            return .init(value: quantity, unit: unit?.quantityTitle.lowercased() ?? "dosi", title: unit?.quantityTitle ?? "Dosi", steps: [1], maximum: 99)
        }
        if let servings = cocktailServings, servings > 0 { return .init(value: servings, unit: "bicchieri", title: "Bicchieri", steps: [1, Decimal(string: "0.5")!], maximum: 100) }
        if let ml = portionMillilitres, ml > 0 { return .init(value: ml, unit: "ml", title: "Quantità", steps: [10, 1], maximum: 9999) }
        if let grams = portionGrams, grams > 0 { return .init(value: grams, unit: "g", title: "Quantità", steps: [10, 1], maximum: 9999) }
        return nil
    }

    /// Same entry (same id) with a new quantity and time. Returns nil for an invalid quantity.
    func edited(quantity: Decimal?, date: Date) -> NativeNutritionEntry? {
        var copy = self
        copy.date = date
        guard let quantity, let current = loggedQuantity, quantity != current.value else { return copy }
        guard !quantity.isNaN, quantity > 0, quantity <= current.maximum else { return nil }
        // Multiply first, divide last, then round: 180 g → 150 g must give 150, not 149.999… (start 5).
        func exact(_ value: Decimal) -> Decimal {
            var raw = value * quantity / current.value, rounded = Decimal()
            NSDecimalRound(&rounded, &raw, 4, .plain)
            return rounded
        }
        func scale(_ value: Decimal?) -> Decimal? { value.map(exact) }
        copy.protein = exact(protein)
        copy.carbohydrate = exact(carbohydrate)
        copy.fat = exact(fat)
        copy.fibre = scale(fibre)
        copy.labelCalories = scale(labelCalories)
        copy.portionGrams = scale(portionGrams)
        copy.portionMillilitres = scale(portionMillilitres)
        copy.boneInWeightGrams = scale(boneInWeightGrams)
        copy.supplementQuantity = scale(supplementQuantity)
        copy.cocktailServings = scale(cocktailServings)
        copy.alcoholGrams = scale(alcoholGrams)
        copy.nutrientValues = nutrientValues?.mapValues { NativeNutrientAmount(amount: exact($0.amount), estimateSource: $0.estimateSource) }
        // The quantity the user typed is stored as typed.
        if (boneInWeightGrams ?? 0) > 0 { copy.boneInWeightGrams = quantity }
        else if (supplementQuantity ?? 0) > 0 { copy.supplementQuantity = quantity }
        else if (cocktailServings ?? 0) > 0 { copy.cocktailServings = quantity }
        else if (portionMillilitres ?? 0) > 0 { copy.portionMillilitres = quantity }
        else { copy.portionGrams = quantity }
        return copy
    }
}

struct NativeFoodLogEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var health: NativeHealthStore
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current
    let original: NativeNutritionEntry
    var onDelete: () -> Void = {}
    @State private var text: String
    @State private var date: Date
    @FocusState private var focused: Bool

    init(entry: NativeNutritionEntry, onDelete: @escaping () -> Void = {}) {
        original = entry
        self.onDelete = onDelete
        _text = State(initialValue: entry.loggedQuantity.map { Self.format($0.value) } ?? "")
        _date = State(initialValue: entry.date)
    }

    private var quantity: NativeLoggedQuantity? { original.loggedQuantity }
    private var typed: Decimal? { NativeNutritionEntry.grams(text) }
    private var draft: NativeNutritionEntry? {
        guard quantity != nil else { return original.edited(quantity: nil, date: date) }
        // The untouched field keeps the exact stored amount (the text is rounded to one decimal).
        if text == quantity.map({ Self.format($0.value) }) { return original.edited(quantity: nil, date: date) }
        guard let typed else { return nil }
        return original.edited(quantity: typed, date: date)
    }
    private var changed: Bool { draft.map { $0 != original } ?? false }

    var body: some View {
        Form {
            if let quantity {
                Section(quantity.title) {
                    HStack {
                        TextField(quantity.title, text: $text)
                            .keyboardType(.decimalPad).focused($focused)
                            .font(.title.weight(.semibold)).monospacedDigit()
                            .accessibilityIdentifier("food-edit-quantity")
                        Text(quantity.unit).foregroundStyle(NativeDesign.secondary)
                    }
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(quantity.steps.flatMap { [-$0] } + quantity.steps.reversed(), id: \.self) { step in
                            Button(step > 0 ? "+" + Self.format(step) : "−" + Self.format(-step)) { nudge(step, maximum: quantity.maximum) }
                                .buttonStyle(LOGlassButtonStyle(fillsWidth: true))
                                .accessibilityIdentifier("food-edit-step-" + (step > 0 ? "plus-" : "minus-") + Self.format(step > 0 ? step : -step))
                        }
                    }
                    if draft == nil { Text("Inserisci una quantità valida.").font(.footnote).foregroundStyle(NativeDesign.danger) }
                }
            }
            Section {
                DatePicker("Ora", selection: $date, displayedComponents: .hourAndMinute).accessibilityIdentifier("food-edit-time")
            }
            if original.nutritionNotDeclared != true, let draft {
                Section {
                    HStack(spacing: NativeDesign.Space.small) {
                        value("kcal", draft.calories, original.calories, digits: 0)
                        value("prot g", draft.protein, original.protein)
                        value("carb g", draft.carbohydrate, original.carbohydrate)
                        value("grassi g", draft.fat, original.fat)
                    }
                    Text("Valori ricalcolati in proporzione, micronutrienti compresi. Il salvataggio aggiorna LifeOS, Apple Salute e il sito.")
                        .font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
            }
            if let error = nutrition.error { Section { Text(error).font(.footnote).foregroundStyle(NativeDesign.danger) } }
            Section {
                Button("Elimina registrazione", role: .destructive) { onDelete(); dismiss() }
                    .frame(maxWidth: .infinity).accessibilityIdentifier("food-edit-delete")
            }
        }
        .navigationTitle(original.foodName ?? "Alimento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.accessibilityIdentifier("food-edit-cancel") }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") { save() }.bold()
                    .disabled(!changed || nutrition.busy)
                    .accessibilityIdentifier("food-edit-save")
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { focused = false } }
        }
        .interactiveDismissDisabled(nutrition.busy)
    }

    private func value(_ label: String, _ now: Decimal, _ before: Decimal, digits: Int = 1) -> some View {
        VStack(spacing: NativeDesign.Space.xxs) {
            Text(Self.number(now, digits)).font(.headline).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(NativeDesign.secondary)
            if now != before { Text(Self.number(before, digits)).font(.caption2).strikethrough().foregroundStyle(NativeDesign.secondary) }
        }.frame(maxWidth: .infinity)
    }

    private func nudge(_ step: Decimal, maximum: Decimal) {
        let next = (typed ?? quantity?.value ?? 0) + step
        guard next > 0, next <= maximum else { return }
        text = Self.format(next)
    }

    private func save() {
        guard let draft, changed else { return }
        focused = false
        Task {
            if await nutrition.save(draft, expectedRevision: original.revision) {
                await health.refresh()
                dismiss()
            }
        }
    }

    static func format(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }
    static func number(_ value: Decimal, _ digits: Int) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(.number.precision(.fractionLength(digits == 0 ? 0...0 : 0...1)))
    }
}
