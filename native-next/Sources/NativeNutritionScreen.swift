import SwiftUI

struct NativeNutritionScreen: View {
    @EnvironmentObject private var health: NativeHealthStore
    @StateObject private var nutrition = NativeNutritionUIFixture.current
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var date = Date()
    @State private var draftID = UUID()
    @State private var expectedRevision: Int?
    @State private var editing: UUID?
    @State private var deleting: UUID?
    @State private var notice: String?
    @FocusState private var focusedField: String?
    private var draft: NativeNutritionEntry? {
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat), let fi = NativeNutritionEntry.grams(fibre) else { return nil }
        return .direct(id: editing ?? draftID, date: date, protein: p, carbohydrate: c, fat: f, fibre: fi, preserving: nutrition.entries.first { $0.id == editing })
    }

    var body: some View {
        Form {
            Section(editing == nil ? "Quantità consumate" : "Modifica quantità consumate") {
                field("Proteine", text: $protein)
                field("Carboidrati", text: $carbohydrate)
                field("Grassi", text: $fat)
                field("Fibre", text: $fibre)
                HStack {
                    Text("Calorie")
                    Spacer()
                    Text(draft.map { NSDecimalNumber(decimal: $0.calories).stringValue + " kcal" } ?? "Valori non validi")
                        .accessibilityIdentifier("nutrition-calories-value")
                }.accessibilityElement(children: .contain)
                DatePicker("Data", selection: $date, displayedComponents: .date)
                Button(editing == nil ? "Aggiungi ad Apple Salute" : "Salva modifiche") {
                    guard let value = draft else { return }
                    Task {
                        if await nutrition.save(value, expectedRevision: expectedRevision) {
                            clear(); notice = "Registrazione salvata in Apple Salute."; await health.refresh()
                        }
                    }
                }.disabled(nutrition.busy || draft == nil || draft?.calories == 0)
                if editing != nil { Button("Annulla modifica", action: clear) }
                if nutrition.busy { ProgressView("Salvataggio") }
                if let notice { Text(notice).foregroundStyle(.secondary) }
                if let error = nutrition.error { Text(error).foregroundStyle(.red) }
            }
            ForEach(NativeNutritionHistory.days(nutrition.entries)) { day in
                Section {
                    ForEach(day.entries) { entry in
                        if entry.deletionPending == true {
                            VStack(alignment: .leading) {
                                Text("Eliminazione da completare")
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                                Button("Riprova eliminazione") { remove(entry.id) }.disabled(nutrition.busy)
                            }
                        } else if entry.confirmed {
                            Button { load(entry) } label: {
                                VStack(alignment: .leading) {
                                    if let name = entry.foodName { Text(name) }
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    if let quantity = entry.quantityDescription { Text(quantity).font(.caption).foregroundStyle(.secondary) }
                                    Text(entry.nutritionSummary).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions { Button("Elimina", role: .destructive) { deleting = entry.id }.disabled(nutrition.busy) }
                            .contextMenu { Button("Elimina registrazione", role: .destructive) { deleting = entry.id }.disabled(nutrition.busy) }
                        } else {
                            VStack(alignment: .leading) {
                                Text("Registrazione da completare")
                                Button("Riprova") { Task { if await nutrition.save(entry, retry: true) { if editing == entry.id { clear() }; await health.refresh() } } }.disabled(nutrition.busy)
                                Button("Modifica e riprova") {
                                    load(entry)
                                }.disabled(nutrition.busy)
                            }
                        }
                    }
                } header: {
                    Text(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityIdentifier("nutrition-history-day-" + CivilDate.day(day.date))
                }
            }
        }.navigationTitle("Nutrizione")
            .confirmationDialog("Eliminare questa registrazione e i suoi campioni LifeOS da Apple Salute?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina da LifeOS e Apple Salute", role: .destructive) { if let id = deleting { remove(id) }; deleting = nil }
                Button("Annulla", role: .cancel) { deleting = nil }
            }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer()
                let fields = ["Proteine", "Carboidrati", "Grassi", "Fibre"]
                if let focusedField, let index = fields.firstIndex(of: focusedField), index + 1 < fields.count {
                    Button("Avanti") { self.focusedField = fields[index + 1] }
                }
                Button("Fine") { focusedField = nil }.accessibilityIdentifier("nutrition-keyboard-done") } }
    }
    private func load(_ entry: NativeNutritionEntry) {
        editing = entry.id; expectedRevision = entry.revision
        protein = NSDecimalNumber(decimal: entry.protein).stringValue
        carbohydrate = NSDecimalNumber(decimal: entry.carbohydrate).stringValue
        fat = NSDecimalNumber(decimal: entry.fat).stringValue
        fibre = NSDecimalNumber(decimal: entry.fibre ?? 0).stringValue
        date = entry.date; notice = nil
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
    private func field(_ title: String, text: Binding<String>, unit: String = "g") -> some View {
        HStack { Text(title); TextField("0", text: text).focused($focusedField, equals: title).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityLabel(title + (unit == "g" ? " in grammi" : " in kcal")).accessibilityIdentifier("nutrition-" + title); Text(unit).foregroundStyle(.secondary) }
    }
    private func clear() { draftID = UUID(); expectedRevision = nil; editing = nil; protein = ""; carbohydrate = ""; fat = ""; fibre = ""; date = Date() }
}
