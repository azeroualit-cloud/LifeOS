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
    @State private var date = Date()
    @State private var showingHistory = false
    @State private var notice: String?
    @FocusState private var focus: Field?
    private enum Field: Hashable { case protein, carbohydrate, fat }
    private var pending: NativeNutritionEntry? { nutrition.entries.first { $0.id == id && !$0.confirmed } }
    private var draft: NativeNutritionEntry? {
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat) else { return nil }
        return .init(id: id, revision: 0, date: date, protein: p, carbohydrate: c, fat: f, confirmed: false)
    }
    var body: some View {
        NativeCard {
            HStack {
                Label("Nutrizione", systemImage: "fork.knife").font(.headline)
                Spacer()
                Button("Cronologia") { showingHistory = true }
                    .frame(minHeight: NativeDesign.Layout.touchTarget)
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.small)) : AnyLayout(HStackLayout(spacing: NativeDesign.Space.small))
            layout {
                grams("Proteine", text: $protein, field: .protein)
                grams("Carboidrati", text: $carbohydrate, field: .carbohydrate)
                grams("Grassi", text: $fat, field: .fat)
            }.disabled(nutrition.busy || pending != nil)
            DatePicker("Data e ora", selection: $date).disabled(nutrition.busy || pending != nil)
            HStack {
                Text(draft.map { NSDecimalNumber(decimal: $0.calories).stringValue + " kcal" } ?? "Controlla i valori")
                    .font(.subheadline).monospacedDigit().accessibilityIdentifier("quick-nutrition-calories")
                Spacer()
                if nutrition.busy { ProgressView().accessibilityLabel("Salvataggio") }
                Button(pending == nil ? "Aggiungi" : "Riprova") { save() }
                    .buttonStyle(.borderedProminent)
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
                    if focus != .fat { Button("Avanti") { focus = focus == .protein ? .carbohydrate : .fat } }
                    Button("Fine") { focus = nil }
                }
            }
        }
    }
    private func grams(_ title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: NativeDesign.Space.xs) {
                TextField("0", text: text).keyboardType(.decimalPad).focused($focus, equals: field)
                    .accessibilityLabel(title + " in grammi").accessibilityIdentifier("quick-nutrition-" + title)
                Text("g").foregroundStyle(.secondary)
            }.frame(minHeight: NativeDesign.Layout.touchTarget)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func save() {
        guard let value = pending ?? draft, !nutrition.busy else { return }
        let retry = pending != nil
        focus = nil; notice = nil
        Task {
            if await nutrition.save(value, retry: retry) {
                id = UUID(); protein = ""; carbohydrate = ""; fat = ""; date = Date()
                notice = "Registrazione salvata in Apple Salute."
                await health.refresh()
            }
        }
    }
}
