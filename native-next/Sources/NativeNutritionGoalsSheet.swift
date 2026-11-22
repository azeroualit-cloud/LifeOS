import SwiftUI

/// "Obiettivi" sheet of the build 93 preview (NUTRITION-GOALS-93-2026-11-21).
/// Edits a draft; Salva writes it to NativeHealthPreferences.
struct NativeNutritionGoalsSheet: View {
    @ObservedObject var health: NativeHealthStore
    @ObservedObject private var preferences = NativeHealthPreferences.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NativeHealthPreferences.shared.goals

    private var tdee: Double? { health.estimate?.tdee }
    private var weight: Double? { health.goalWeight }
    private var targets: NativeNutritionGoals.Targets? { draft.targets(tdee: tdee, weight: weight) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                    calories
                    macros
                }
                .padding(.horizontal, NativeDesign.Layout.screenInset)
                .padding(.vertical, NativeDesign.Space.large)
            }
            .background(NativeDesign.canvas)
            .navigationTitle("Obiettivi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.accessibilityIdentifier("goals-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { preferences.goals = draft; dismiss() }
                        .fontWeight(.semibold).accessibilityIdentifier("goals-save")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("nutrition-goals-sheet")
    }

    private var calories: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Calorie")
            NativeCard {
                LOSegmented(options: [("Dal TDEE", "tdee"), ("Fisse", "fixed")], selection: Binding(
                    get: { draft.calorieMode == .tdee ? "Dal TDEE" : "Fisse" },
                    set: { draft.calorieMode = $0 == "Dal TDEE" ? .tdee : .fixed }), identifierPrefix: "goals-mode-")
                if draft.calorieMode == .tdee {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text("TDEE").font(.subheadline)
                            Text("dal tuo storico").font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                        Spacer()
                        Text(tdee.map { kcal($0) } ?? "Non disponibile").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    LOStepperRow(title: "Deficit o surplus", value: signed(draft.adjustment),
                        decrement: draft.adjustment > NativeNutritionGoals.adjustmentRange.lowerBound ? { draft.adjustment -= NativeNutritionGoals.adjustmentStep } : nil,
                        increment: draft.adjustment < NativeNutritionGoals.adjustmentRange.upperBound ? { draft.adjustment += NativeNutritionGoals.adjustmentStep } : nil,
                        identifier: "goals-adjustment")
                } else {
                    LOStepperRow(title: "Calorie al giorno", value: kcal(draft.fixedCalories),
                        decrement: draft.fixedCalories > NativeNutritionGoals.calorieRange.lowerBound ? { draft.fixedCalories -= NativeNutritionGoals.adjustmentStep } : nil,
                        increment: draft.fixedCalories < NativeNutritionGoals.calorieRange.upperBound ? { draft.fixedCalories += NativeNutritionGoals.adjustmentStep } : nil,
                        identifier: "goals-fixed")
                }
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("Obiettivo di oggi").font(.headline)
                    Spacer()
                    Text(draft.calories(tdee: tdee).map { kcal($0) } ?? "—").font(.headline.weight(.bold)).monospacedDigit()
                        .accessibilityIdentifier("goals-today")
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Macro")
            NativeCard {
                macroRow("Proteine", value: $draft.protein, unit: $draft.proteinUnit, color: NativeDesign.macroProtein, identifier: "goals-protein")
                Divider()
                macroRow("Grassi", value: $draft.fat, unit: $draft.fatUnit, color: NativeDesign.macroFat, identifier: "goals-fat")
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                        Text("Carboidrati").font(.subheadline).foregroundStyle(NativeDesign.macroCarbohydrate)
                        Text("il resto delle calorie").font(.footnote).foregroundStyle(NativeDesign.secondary)
                    }
                    Spacer()
                    Text(targets.map { grams($0.carbohydrate) } ?? "—").font(.subheadline.weight(.semibold)).monospacedDigit()
                        .accessibilityIdentifier("goals-carbohydrate")
                }
                .frame(minHeight: NativeDesign.Layout.rowHeight)
                .accessibilityElement(children: .combine)
            }
            if weight == nil, draft.proteinUnit == .perKG || draft.fatUnit == .perKG {
                Text("Serve almeno una pesata per i grammi per kg.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                    .padding(.horizontal, NativeDesign.Space.large)
            }
        }
    }

    private func macroRow(_ title: String, value: Binding<Double>, unit: Binding<NativeNutritionGoals.MacroUnit>, color: Color, identifier: String) -> some View {
        let perKG = unit.wrappedValue == .perKG
        let step = perKG ? 0.1 : 5
        let resolved = draft.grams(value.wrappedValue, unit: unit.wrappedValue, weight: weight)
        let shown = perKG
            ? value.wrappedValue.formatted(.number.precision(.fractionLength(1))) + " g/kg"
            : grams(value.wrappedValue)
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(color)
                Spacer()
                Menu {
                    Picker("Unità", selection: Binding(get: { unit.wrappedValue }, set: { newUnit in
                        // Keep the same grams when switching unit, if the weight is known.
                        if let weight, weight > 0, newUnit != unit.wrappedValue {
                            value.wrappedValue = newUnit == .perKG ? (value.wrappedValue / weight * 10).rounded() / 10 : (value.wrappedValue * weight).rounded()
                        }
                        unit.wrappedValue = newUnit
                    })) {
                        Text("Grammi").tag(NativeNutritionGoals.MacroUnit.grams)
                        Text("g per kg").tag(NativeNutritionGoals.MacroUnit.perKG)
                    }
                } label: {
                    HStack(spacing: NativeDesign.Space.xs) {
                        Text(perKG ? "g per kg" : "Grammi")
                        Image(systemName: "chevron.up.chevron.down").font(.footnote)
                    }
                    .font(.subheadline).foregroundStyle(NativeDesign.secondary)
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                }
                .accessibilityIdentifier(identifier + "-unit")
            }
            LOStepperRow(title: title, value: shown, detail: perKG ? resolved.map { grams($0) } : nil,
                decrement: value.wrappedValue - step >= 0 ? { value.wrappedValue = ((value.wrappedValue - step) * 10).rounded() / 10 } : nil,
                increment: { value.wrappedValue = ((value.wrappedValue + step) * 10).rounded() / 10 },
                identifier: identifier)
        }
    }

    private func kcal(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) + " kcal" }
    private func grams(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) + " g" }
    private func signed(_ value: Double) -> String {
        (value > 0 ? "+" : value < 0 ? "−" : "") + abs(value).formatted(.number.precision(.fractionLength(0)))
    }
}
