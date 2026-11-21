import SwiftUI
import HealthKit

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

    @State private var grouping: NativeNutritionGrouping = .days
    @State private var selectedBar: String?

    private var bars: [NativeNutritionBar] {
        let macros = health.nutrientsByDay.mapValues { NativeMacroDay(protein: $0[.dietaryProtein] ?? 0, carbohydrate: $0[.dietaryCarbohydrates] ?? 0, fat: $0[.dietaryFatTotal] ?? 0) }
        return NativeNutritionBars.bars(macros, grouping: grouping)
    }
    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func key(_ bar: NativeNutritionBar) -> String { String(Int(bar.start.timeIntervalSince1970)) }

    /// Cronologia (build 93 preview): grouping, stacked columns, selected detail,
    /// entries to complete; the day-grouped list keeps edit and delete.
    var body: some View {
        let bars = self.bars
        let targets = health.goalTargets
        let todayBar = grouping == .days ? bars.first { Calendar.current.isDateInToday($0.start) } : nil
        let selected = bars.first { key($0) == selectedBar } ?? todayBar ?? bars.last
        let pending = nutrition.entries.filter { !$0.confirmed && $0.deletionPending != true }
        Form {
            Section {
                LOSegmented(options: NativeNutritionGrouping.allCases.map { (title: $0.title, id: String($0.rawValue)) }, selection: Binding(
                    get: { grouping.title }, set: { title in grouping = NativeNutritionGrouping.allCases.first { $0.title == title } ?? .days; selectedBar = nil }),
                    identifierPrefix: "nutrition-grouping-")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                HStack {
                    Text("Media al giorno").font(.headline)
                    Spacer()
                    legend("P", NativeDesign.macroProtein)
                    legend("C", NativeDesign.macroCarbohydrate)
                    legend("G", NativeDesign.macroFat)
                }
                LOStackedColumns(columns: bars.map { bar in
                    LOStackedColumn(id: key(bar), label: bar.label, segments: [
                        LOSegment(id: "p", value: bar.protein * 4, color: NativeDesign.macroProtein),
                        LOSegment(id: "c", value: bar.carbohydrate * 4, color: NativeDesign.macroCarbohydrate),
                        LOSegment(id: "f", value: bar.fat * 9, color: NativeDesign.macroFat)],
                        accessibilityLabel: bar.name + ": " + (bar.days == 0 ? "nessun dato" : whole(bar.calories) + " kcal"))
                }, goal: targets?.calories, selection: Binding(get: { selected.map(key) }, set: { selectedBar = $0 }),
                identifierPrefix: "nutrition-bar-")
                .padding(.vertical, NativeDesign.Space.small)
                if let selected { detail(selected, targets: targets) }
            }
            if !pending.isEmpty {
                Section("Da completare") {
                    ForEach(pending) { entry in
                        HStack(spacing: NativeDesign.Space.medium) {
                            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                Text(entry.foodName ?? "Energia alimentare")
                                Text("Registrazione da completare").font(.footnote).foregroundStyle(NativeDesign.overGoal)
                            }
                            Spacer()
                            Button("Riprova") { retry(entry) }
                                .buttonStyle(LOGlassButtonStyle()).disabled(nutrition.busy)
                        }
                        Button("Modifica e riprova") { load(entry) }.disabled(nutrition.busy)
                    }
                }
            }
            if editing != nil {
                Section("Modifica quantità consumate") {
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
                    Button("Salva modifiche") {
                        guard let value = draft else { return }
                        Task {
                            if await nutrition.save(value, expectedRevision: expectedRevision) {
                                clear(); notice = "Registrazione salvata in Apple Salute."; await health.refresh()
                            }
                        }
                    }.disabled(nutrition.busy || draft == nil || draft?.calories == 0)
                    Button("Annulla modifica", action: clear)
                }
            }
            if nutrition.busy || notice != nil || nutrition.error != nil {
                Section {
                    if nutrition.busy { ProgressView("Salvataggio") }
                    if let notice { Text(notice).foregroundStyle(NativeDesign.secondary) }
                    if let error = nutrition.error { Text(error).foregroundStyle(NativeDesign.danger) }
                }
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
                        }
                    }
                } header: {
                    Text(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityIdentifier("nutrition-history-day-" + CivilDate.day(day.date))
                }
            }
        }.modifier(NativeListAppearance()).navigationTitle("Cronologia").navigationBarTitleDisplayMode(.inline)
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
    private func retry(_ entry: NativeNutritionEntry) {
        Task { if await nutrition.save(entry, retry: true) { if editing == entry.id { clear() }; await health.refresh() } }
    }
    private func legend(_ letter: String, _ color: Color) -> some View {
        HStack(spacing: NativeDesign.Space.xs) {
            Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            Text(letter).font(.footnote.weight(.semibold)).foregroundStyle(NativeDesign.secondary)
        }.accessibilityHidden(true)
    }
    private func detail(_ bar: NativeNutritionBar, targets: NativeNutritionGoals.Targets?) -> some View {
        let over = targets.map { bar.calories > $0.calories } ?? false
        let empty = bar.days == 0
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(bar.name).font(.headline)
                Spacer()
                Text(empty ? "—" : whole(bar.calories)).font(.title3.weight(.bold)).monospacedDigit()
                    .foregroundStyle(over ? NativeDesign.overGoal : Color.primary)
                if let targets { Text("/ " + whole(targets.calories) + " kcal").font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit() }
            }
            HStack(alignment: .top, spacing: NativeDesign.Space.medium) {
                LOMacroValue(title: "P", value: empty ? nil : bar.protein, goal: targets?.protein, unit: "g", color: NativeDesign.macroProtein, identifier: "nutrition-detail-protein")
                LOMacroValue(title: "C", value: empty ? nil : bar.carbohydrate, goal: targets?.carbohydrate, unit: "g", color: NativeDesign.macroCarbohydrate, identifier: "nutrition-detail-carbohydrate")
                LOMacroValue(title: "G", value: empty ? nil : bar.fat, goal: targets?.fat, unit: "g", color: NativeDesign.macroFat, identifier: "nutrition-detail-fat")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition-selected-detail")
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
