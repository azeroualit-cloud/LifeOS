import SwiftUI

/// One stable draft identity across network/HealthKit retries.
struct NativeNutritionQuickEntry: View {
    @EnvironmentObject private var health: NativeHealthStore
    @ObservedObject private var nutrition = NativeNutritionStore.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var id = UUID()
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var calories = ""
    @State private var portion = "100"
    @State private var date = Date()
    @State private var showingHistory = false
    @State private var notice: String?
    @FocusState private var focus: Field?
    private enum Field: Hashable { case protein, carbohydrate, fat, fibre, calories, portion }
    private var pending: NativeNutritionEntry? { nutrition.entries.first { $0.id == id && !$0.confirmed } }
    private var hasPendingOperation: Bool { nutrition.entries.contains { !$0.confirmed || $0.deletionPending == true } }
    private var draft: NativeNutritionEntry? {
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat), let fi = NativeNutritionEntry.grams(fibre), let kcal = NativeNutritionEntry.grams(calories), let g = NativeNutritionEntry.grams(portion) else { return nil }
        return .portion(id: id, date: date, protein: p, carbohydrate: c, fat: f, fibre: fi, calories: kcal, grams: g)
    }
    var body: some View {
        NativeCard(density: .compact) {
            HStack {
                Label("Nutrizione", systemImage: "fork.knife").font(.headline)
                Spacer()
                Button("Cronologia") { showingHistory = true }
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
            }
            if hasPendingOperation {
                Button("Completa la registrazione in sospeso") { showingHistory = true }
                    .font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget)
            }
            Text("Valori dell’etichetta per 100 g").font(.subheadline).foregroundStyle(.secondary)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.small)) : AnyLayout(HStackLayout(spacing: NativeDesign.Space.small))
            layout {
                grams("Proteine", text: $protein, field: .protein)
                grams("Carboidrati", text: $carbohydrate, field: .carbohydrate)
                grams("Grassi", text: $fat, field: .fat)
            }.disabled(nutrition.busy || pending != nil)
            layout {
                grams("Fibre", text: $fibre, field: .fibre)
                grams("Calorie", text: $calories, field: .calories, unit: "kcal")
            }.disabled(nutrition.busy || pending != nil)
            grams("Porzione effettiva", text: $portion, field: .portion)
                .disabled(nutrition.busy || pending != nil)
            DatePicker("Data", selection: $date, displayedComponents: .date).disabled(nutrition.busy || pending != nil)
            HStack {
                Text(draft.map { NSDecimalNumber(decimal: $0.calories).stringValue + " kcal" } ?? "Controlla i valori")
                    .font(.subheadline).monospacedDigit().accessibilityIdentifier("quick-nutrition-calories")
                Spacer()
                if nutrition.busy { ProgressView().accessibilityLabel("Salvataggio") }
                Button { save() } label: {
                    Text(pending == nil ? "Aggiungi" : "Riprova")
                        .foregroundStyle(NativeDesign.onAccent)
                        .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
                        .contentShape(Rectangle())
                }.buttonStyle(NativeCompactPrimaryButtonStyle())
                    .disabled(nutrition.busy || draft == nil || draft?.calories == 0)
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
                    .accessibilityIdentifier("quick-nutrition-save")
            }
            if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = nutrition.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .sheet(isPresented: $showingHistory) { NavigationStack { NativeNutritionScreen().toolbar { DoneButton() } } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focus != nil {
                    Spacer()
                    if focus != .portion { Button("Avanti") {
                        switch focus {
                        case .protein: focus = .carbohydrate
                        case .carbohydrate: focus = .fat
                        case .fat: focus = .fibre
                        case .fibre: focus = .calories
                        case .calories: focus = .portion
                        default: focus = nil
                        }
                    } }
                    Button("Fine") { focus = nil }
                }
            }
        }
    }
    private func grams(_ title: String, text: Binding<String>, field: Field, unit: String = "g") -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: NativeDesign.Space.xs) {
                TextField("0", text: text).keyboardType(.decimalPad).focused($focus, equals: field)
                    .accessibilityLabel(title + (unit == "g" ? " in grammi" : " in kcal")).accessibilityIdentifier("quick-nutrition-" + title)
                Text(unit).foregroundStyle(.secondary)
            }.frame(minHeight: NativeDesign.Layout.touchTarget)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func save() {
        guard let value = pending ?? draft, !nutrition.busy else { return }
        let retry = pending != nil
        focus = nil; notice = nil
        Task {
            if await nutrition.save(value, retry: retry) {
                id = UUID(); protein = ""; carbohydrate = ""; fat = ""; fibre = ""; calories = ""; portion = "100"; date = Date()
                notice = "Registrazione salvata in Apple Salute."
                await health.refresh()
            }
        }
    }
}
