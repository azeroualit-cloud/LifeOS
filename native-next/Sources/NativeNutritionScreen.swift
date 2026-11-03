import SwiftUI

struct NativeNutritionScreen: View {
    @EnvironmentObject private var health: NativeHealthStore
    @StateObject private var nutrition = NativeNutritionStore.shared
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var date = Date()
    @State private var editing: UUID?
    @State private var deleting: UUID?
    @State private var notice: String?
    @FocusState private var focusedField: String?
    private var draft: NativeNutritionEntry? {
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat) else { return nil }
        return .init(id: editing ?? UUID(), revision: 0, date: date, protein: p, carbohydrate: c, fat: f, confirmed: false)
    }
    var body: some View {
        Form {
            Section("Macronutrienti") {
                field("Proteine", text: $protein)
                field("Carboidrati", text: $carbohydrate)
                field("Grassi", text: $fat)
                HStack {
                    Text("Calorie")
                    Spacer()
                    Text(draft.map { NSDecimalNumber(decimal: $0.calories).stringValue + " kcal" } ?? "Valori non validi")
                        .accessibilityIdentifier("nutrition-calories-value")
                }.accessibilityElement(children: .contain)
                DatePicker("Data e ora", selection: $date)
                Button(editing == nil ? "Aggiungi ad Apple Salute" : "Salva modifiche") {
                    guard let value = draft else { return }
                    Task {
                        if await nutrition.save(value) {
                            clear(); notice = "Registrazione salvata in Apple Salute."; await health.refresh()
                        }
                    }
                }.disabled(nutrition.busy || draft == nil || draft?.calories == 0)
                if editing != nil { Button("Annulla modifica", action: clear) }
                if nutrition.busy { ProgressView("Salvataggio") }
                if let notice { Text(notice).foregroundStyle(.secondary) }
                if let error = nutrition.error { Text(error).foregroundStyle(.red) }
            }
            Section("Registrazioni LifeOS") {
                ForEach(nutrition.entries.sorted { $0.date > $1.date }) { entry in
                    if entry.deletionPending == true {
                        VStack(alignment: .leading) {
                            Text("Eliminazione da completare")
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                            Button("Riprova eliminazione") { remove(entry.id) }.disabled(nutrition.busy)
                        }
                    } else if entry.confirmed {
                        Button { editing = entry.id; protein = NSDecimalNumber(decimal: entry.protein).stringValue; carbohydrate = NSDecimalNumber(decimal: entry.carbohydrate).stringValue; fat = NSDecimalNumber(decimal: entry.fat).stringValue; date = entry.date; notice = nil } label: {
                            VStack(alignment: .leading) {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                Text("P \(NSDecimalNumber(decimal: entry.protein)) · C \(NSDecimalNumber(decimal: entry.carbohydrate)) · G \(NSDecimalNumber(decimal: entry.fat)) g — \(NSDecimalNumber(decimal: entry.calories)) kcal").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions { Button("Elimina", role: .destructive) { deleting = entry.id }.disabled(nutrition.busy) }
                        .contextMenu { Button("Elimina registrazione", role: .destructive) { deleting = entry.id }.disabled(nutrition.busy) }
                    } else {
                        VStack(alignment: .leading) {
                            Text("Registrazione da completare")
                            Button("Riprova") { Task { if await nutrition.save(entry, retry: true) { if editing == entry.id { clear() }; await health.refresh() } } }.disabled(nutrition.busy)
                            Button("Modifica e riprova") {
                                editing = entry.id; protein = NSDecimalNumber(decimal: entry.protein).stringValue; carbohydrate = NSDecimalNumber(decimal: entry.carbohydrate).stringValue; fat = NSDecimalNumber(decimal: entry.fat).stringValue; date = entry.date; notice = nil
                            }.disabled(nutrition.busy)
                        }
                    }
                }
            }
        }.navigationTitle("Nutrizione")
            .confirmationDialog("Eliminare questa registrazione e i suoi campioni LifeOS da Apple Salute?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina da LifeOS e Apple Salute", role: .destructive) { if let id = deleting { remove(id) }; deleting = nil }
                Button("Annulla", role: .cancel) { deleting = nil }
            }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer()
                if focusedField == "Proteine" || focusedField == "Carboidrati" {
                    Button("Avanti") { focusedField = focusedField == "Proteine" ? "Carboidrati" : "Grassi" }
                }
                Button("Fine") { focusedField = nil } } }
    }
    private func remove(_ id: UUID) {
        Task {
            if await nutrition.delete(id) {
                if editing == id { clear() }
                notice = "Registrazione eliminata da LifeOS e Apple Salute."
                await health.refresh()
            }
        }
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title); TextField("0", text: text).focused($focusedField, equals: title).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityLabel(title + " in grammi").accessibilityIdentifier("nutrition-" + title); Text("g").foregroundStyle(.secondary) }
    }
    private func clear() { editing = nil; protein = ""; carbohydrate = ""; fat = ""; date = Date() }
}
