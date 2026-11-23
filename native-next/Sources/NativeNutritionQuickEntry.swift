import SwiftUI
import HealthKit

struct NativeNutritionQuickEntry: View {
    @EnvironmentObject private var health: NativeHealthStore
    @EnvironmentObject private var router: NativeRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showing = false
    @State private var addingWeight = false
    @State private var notice: String?
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current

    var body: some View {
        // NUTRITION-GOALS-93-2026-11-21: today's totals against the goals, as the preview.
        let targets = health.goalTargets
        let values = health.nutrients(on: .now)
        let kcal = health.todayCalories
        let kcalText = kcal.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—"
        let goalText = targets.map { " / " + $0.calories.formatted(.number.precision(.fractionLength(0))) } ?? ""
        let macroLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.small))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NativeDesign.Space.medium))
        NativeCard {
            Button { router.tab = .health } label: {
                LOCardHeader(title: "Nutrizione", systemImage: NativeHealthMetric.calories.symbol, section: .nutrition,
                             showsChevron: true, trailing: kcalText + goalText + " kcal")
                .contentShape(Rectangle().inset(by: -NativeDesign.Space.medium)) // 44 pt touch without 44 pt of layout
            }
            .buttonStyle(NativePressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Nutrizione, calorie di oggi " + (kcal == nil ? "nessun dato" : kcalText) + (targets.map { " di " + $0.calories.formatted(.number.precision(.fractionLength(0))) } ?? ""))
            .accessibilityIdentifier("home-nutrition")
            LOProgressBar(value: kcal ?? 0, total: targets?.calories, color: NativeDesign.nutritionTitle)
            macroLayout {
                LOMacroValue(title: "Proteine", value: values[.dietaryProtein], goal: targets?.protein, unit: "g", color: NativeDesign.macroProtein, identifier: "home-nutrient-protein")
                LOMacroValue(title: "Carbo", value: values[.dietaryCarbohydrates], goal: targets?.carbohydrate, unit: "g", color: NativeDesign.macroCarbohydrate, identifier: "home-nutrient-carbohydrate")
                LOMacroValue(title: "Grassi", value: values[.dietaryFatTotal], goal: targets?.fat, unit: "g", color: NativeDesign.macroFat, identifier: "home-nutrient-fat")
            }
            let actions = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.small))
                : AnyLayout(HStackLayout(spacing: NativeDesign.Space.small))
            actions {
                // Build 93 preview: Peso on the left, Alimento on the right.
                Button { addingWeight = true } label: {
                    LOActionLabel(title: "Peso", systemImage: NativeHealthMetric.weight.symbol, section: .weight)
                }.buttonStyle(LOGlassButtonStyle(fillsWidth: true, compact: true)).accessibilityLabel("Aggiungi peso")
                Button { notice = nil; showing = true } label: {
                    LOActionLabel(title: "Alimento", systemImage: NativeHealthMetric.calories.symbol, section: .nutrition)
                }.buttonStyle(LOGlassButtonStyle(fillsWidth: true, compact: true)).accessibilityLabel("Aggiungi alimento")
                    .accessibilityIdentifier("quick-nutrition-open")
            }
            .padding(.top, NativeDesign.Space.small) // 16 pt from the macros, like the card edges (SPACING-SYSTEM-2026-11-23)
            if let notice { Text(notice).font(.footnote).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("quick-nutrition-notice") }
        }.sheet(isPresented: $showing) {
            NavigationStack { NativeNutritionQuickSheet { notice = "Registrazione salvata." } }
                .modifier(NativeVisualTestSize()).modifier(NativeVisualTestMotion())
        }.sheet(isPresented: $addingWeight) {
            NativeAddWeightSheet(health: health)
        }.task { await NativeGenericFood.preload() }
    }
}

/// One identity survives write failure/retry; dismissal happens only after confirmation.
struct NativeNutritionQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var health: NativeHealthStore
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current
    var onSaved: () -> Void = {}
    @State private var id = UUID()
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var fibre = ""
    @State private var date: Date
    @State private var dateSelection: Date
    @State private var showingHistory = false
    @State private var showingDate = false
    @State private var showingCatalog = false
    @State private var selectedFood: NativeGenericFood?
    @State private var portionGrams = "100"
    @State private var weighedWithBone = false
    /// Selected natural unit; nil means grams/ml (FOOD-CATALOG-92).
    @State private var pieceName: String?
    @FocusState private var focus: Field?
    init(initialDate: Date = .now, onSaved: @escaping () -> Void = {}) {
        let calendar = Calendar.current
        let now = Date()
        let date = calendar.isDate(initialDate, inSameDayAs: now) ? now : initialDate
        self._date = State(initialValue: date)
        self._dateSelection = State(initialValue: date)
        self.onSaved = onSaved
    }

    private enum Field: Hashable { case protein, carbohydrate, fat, fibre, portion }
    private var selectedPiece: NativeGenericFood.Piece? {
        guard let pieceName else { return nil }
        return selectedFood?.pieces?.first { $0.name == pieceName }
    }
    private var pending: NativeNutritionEntry? { nutrition.entries.first { $0.id == id && !$0.confirmed } }
    private var blocked: Bool { nutrition.entries.contains { ($0.id != id && !$0.confirmed) || $0.deletionPending == true } }
    private var draft: NativeNutritionEntry? {
        if let selectedFood {
            guard let quantity = NativeNutritionEntry.grams(portionGrams), quantity <= 9999 else { return nil }
            if let piece = selectedPiece {
                guard quantity <= 99 else { return nil }
                return selectedFood.portion(id: id, date: date, grams: quantity * piece.grams)
            }
            return selectedFood.portion(id: id, date: date, grams: quantity, weighedWithBone: weighedWithBone)
        }
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat), let fi = NativeNutritionEntry.grams(fibre) else { return nil }
        return .direct(id: id, date: date, protein: p, carbohydrate: c, fat: f, fibre: fi)
    }
    var body: some View {
        VStack(spacing: NativeDesign.Space.none) {
            HStack(alignment: typeSize.isAccessibilitySize ? .top : .center) {
                Text("Aggiungi nutrienti").font(.title.bold()).accessibilityAddTraits(.isHeader)
                    .onTapGesture { focus = nil }
                    .accessibilityAction(named: Text("Nascondi tastiera")) { focus = nil }
                Spacer(minLength: NativeDesign.Space.small)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                        .background(NativeDesign.nutritionInput, in: Circle())
                }.buttonStyle(.plain).disabled(nutrition.busy).accessibilityLabel("Chiudi").accessibilityIdentifier("quick-nutrition-close")
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.top, typeSize.isAccessibilitySize ? NativeDesign.Space.small : NativeDesign.Space.large)
            if !typeSize.isAccessibilitySize {
                catalogButton
                    .padding(.horizontal, NativeDesign.Layout.screenInset)
                    .padding(.top, NativeDesign.Space.small)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    if typeSize.isAccessibilitySize { catalogButton }
                    if let selectedFood {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text(selectedFood.name).font(.headline)
                            if let detail = selectedFood.displayDetail {
                                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let note = selectedFood.dataNote { Text(note).font(.footnote).foregroundStyle(.secondary) }
                            if let source = selectedFood.sourceURL, let url = URL(string: source), url.scheme == "https" {
                                Link(selectedFood.isCommunitySourced ? "Open Food Facts · scheda prodotto" : "Scheda prodotto", destination: url).font(.footnote).accessibilityIdentifier("nutrition-product-source")
                            }
                            if selectedFood.isCommunitySourced, let license = URL(string: "https://opendatacommons.org/licenses/odbl/1.0/") {
                                Link("Database Open Food Facts · licenza ODbL", destination: license).font(.footnote).accessibilityIdentifier("nutrition-source-license")
                            }
                        }
                        if selectedFood.boneInEdiblePercent != nil {
                            Picker("Pesatura", selection: $weighedWithBone) {
                                Text("Senza osso").tag(false)
                                Text("Con osso").tag(true)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("quick-nutrition-weighing")
                            .disabled(nutrition.busy || pending != nil)
                        }
                        if let pieces = selectedFood.pieces, !pieces.isEmpty, selectedFood.family != .supplement {
                            Picker("Unità", selection: Binding(get: { pieceName }, set: { name in
                                pieceName = name
                                portionGrams = name == nil ? "100" : "1"
                                weighedWithBone = false
                            })) {
                                Text(selectedFood.quantityUnit == .millilitre ? "Millilitri" : "Grammi").tag(String?.none)
                                ForEach(pieces) { piece in
                                    Text(piece.name.prefix(1).uppercased() + piece.name.dropFirst() + " (" + NSDecimalNumber(decimal: piece.grams).stringValue + " g)").tag(Optional(piece.name))
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("quick-nutrition-unit")
                            .disabled(nutrition.busy || pending != nil)
                        }
                        if let piece = selectedPiece {
                            grams("Pezzi", text: $portionGrams, field: .portion, unit: piece.name)
                                .disabled(nutrition.busy || pending != nil)
                        } else {
                            grams(selectedFood.family == .supplement ? selectedFood.quantityUnit.quantityTitle : selectedFood.cocktail == nil ? "Porzione" : "Bicchieri", text: $portionGrams,
                                  field: .portion, unit: selectedFood.cocktail == nil && (selectedFood.family != .supplement || selectedFood.quantityUnit.isMassOrVolume) ? (selectedFood.quantityUnit == .millilitre ? "ml" : "g") : nil)
                                .disabled(nutrition.busy || pending != nil)
                        }
                        if let draft {
                            if let recipe = selectedFood.cocktail, let alcohol = draft.alcoholGrams, let units = draft.standardDrinks {
                                let precision = Decimal.FormatStyle().precision(.fractionLength(0...1))
                                Text("≈ \(alcohol.formatted(precision)) g di alcol · \(units.formatted(precision)) UA")
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityIdentifier("quick-nutrition-alcohol")
                                Text("Bicchiere da circa \(recipe.volumeML) ml · 1 UA = 12 g")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if weighedWithBone, let edible = draft.portionGrams {
                                Text("Parte edibile stimata: \(NSDecimalNumber(decimal: edible).doubleValue.formatted(.number.precision(.fractionLength(0)))) g")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            activeNutrients(draft)
                            if let caffeine = draft.nutrientValues?["caffeine"]?.amount {
                                Text("Caffeina: \(NSDecimalNumber(decimal: caffeine)) mg").font(.subheadline)
                            }
                            let fibreText = draft.fibre.map { NSDecimalNumber(decimal: $0).stringValue } ?? "—"
                            Text(draft.nutritionNotDeclared == true ? "Energia e macronutrienti non dichiarati: non inviati ad Apple Salute" : "P \(NSDecimalNumber(decimal: draft.protein)) · C \(NSDecimalNumber(decimal: draft.carbohydrate)) · G \(NSDecimalNumber(decimal: draft.fat)) · F \(fibreText) g")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Inserisci nutrienti a mano") { self.selectedFood = nil; focus = nil }
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                            .disabled(nutrition.busy || pending != nil)
                    } else {
                        Text("Quantità consumate").font(.subheadline).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.medium), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: NativeDesign.Space.medium) {
                            grams("Proteine", text: $protein, field: .protein)
                            grams("Carboidrati", text: $carbohydrate, field: .carbohydrate)
                            grams("Grassi", text: $fat, field: .fat)
                            grams("Fibre", text: $fibre, field: .fibre)
                        }.disabled(nutrition.busy || pending != nil)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text("Calorie").font(.headline)
                            Text(selectedFood == nil ? "Calcolate automaticamente" : "Dalla porzione selezionata").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(draft.map { $0.nutritionNotDeclared == true ? "Non dichiarate" : NSDecimalNumber(decimal: $0.calories).doubleValue.formatted(.number.precision(.fractionLength(0...1))) + " kcal" } ?? (allZero ? "0 kcal" : "Valori non validi"))
                            .font(.title.bold()).monospacedDigit().accessibilityIdentifier("quick-nutrition-calories")
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("quick-nutrition-calorie-summary")
                    Divider()
                    HStack {
                        Text("Data")
                        Spacer()
                        Button {
                            focus = nil
                            dateSelection = date
                            showingDate = true
                        } label: {
                            Label(Calendar.current.isDateInToday(date) ? "Oggi" : date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .padding(.horizontal, NativeDesign.Space.medium).frame(minHeight: NativeDesign.Layout.touchTarget)
                                .background(NativeDesign.nutritionInput, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
                        }.buttonStyle(.plain).disabled(nutrition.busy || pending != nil)
                            .accessibilityLabel("Data").accessibilityValue(date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityIdentifier("quick-nutrition-date")
                    }
                    if blocked {
                        Button("Completa la registrazione in sospeso dalla cronologia") { focus = nil; showingHistory = true }
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                    }
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.medium)
            }.clipped().scrollDismissesKeyboard(.interactively).accessibilityIdentifier("quick-nutrition-scroll")
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(NativeDesign.nutritionCanvas)
        .safeAreaInset(edge: .bottom, spacing: NativeDesign.Space.none) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                if let error = nutrition.error {
                    Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("quick-nutrition-error")
                }
                Button(action: save) {
                    HStack {
                        if nutrition.busy { ProgressView().accessibilityLabel("Salvataggio") }
                        Text(pending == nil ? "Aggiungi" : "Riprova").font(.headline)
                    // The sheet draws this a few percent smaller than its layout (42 pt measured for 44,
                    // candidate 94): keep a margin so the save button stays at least 44 pt.
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget + NativeDesign.Space.small)
                }.buttonStyle(NativeCompactPrimaryButtonStyle(readableDisabled: true))
                    .disabled(nutrition.busy || blocked || (pending ?? draft) == nil)
                    .accessibilityIdentifier("quick-nutrition-save")
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
            .background(NativeDesign.nutritionCanvas)
            .accessibilityElement(children: .contain).accessibilityIdentifier("quick-nutrition-footer")
        }
        .sheet(isPresented: $showingDate) {
            dateSheet
        }
        .sheet(isPresented: $showingCatalog) {
            NavigationStack {
                NativeFoodPicker { food in
                    selectedFood = food
                    // Foods eaten by the piece open on their first natural unit.
                    pieceName = food.family == .supplement ? nil : food.pieces?.first?.name
                    portionGrams = pieceName != nil ? "1" : food.defaultQuantity.map { NSDecimalNumber(decimal: $0).stringValue } ?? (food.cocktail == nil && food.family != .supplement ? "100" : "1")
                    weighedWithBone = false
                }
            }
        }
        .sheet(isPresented: $showingHistory) { NavigationStack { NativeNutritionScreen().toolbar { DoneButton() } } }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled(nutrition.busy || pending != nil)
    }
    private var catalogButton: some View {
        Button {
            focus = nil
            showingCatalog = true
        } label: {
            Label("Cerca alimento", systemImage: "magnifyingglass")
                .foregroundStyle(Color.primary)
                .padding(.horizontal, NativeDesign.Space.medium)
                .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                .background(NativeDesign.nutritionInput, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
        }
        .buttonStyle(.plain)
        .disabled(nutrition.busy || pending != nil)
        .accessibilityIdentifier("quick-nutrition-catalog")
    }

    private var dateSheet: some View {
        NavigationStack {
            ScrollView {
                DatePicker("Data", selection: $dateSelection, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(NativeDesign.Space.large)
            }
            .navigationTitle("Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { showingDate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        date = dateSelection
                        showingDate = false
                    }.accessibilityIdentifier("quick-nutrition-date-done")
                }
            }
        }
        .tint(NativeDesign.calendarAccent)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(NativeDesign.Layout.datePickerSheetHeight), .large])
        .presentationDragIndicator(.visible)
    }

    private var allZero: Bool {
        selectedFood == nil && [protein, carbohydrate, fat, fibre].allSatisfy { NativeNutritionEntry.grams($0) == 0 }
    }
    private func activeNutrients(_ entry: NativeNutritionEntry) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            ForEach(NativeTrackedNutrient.micronutrients + [.ala, .epa, .dha]) { nutrient in
                let key = nutrient == .folate ? "folateMass" : nutrient.rawValue
                if let value = entry.nutrientValues?[key] {
                    Text(nutrient.title + ": " + NSDecimalNumber(decimal: value.amount).doubleValue.formatted(.number.precision(.fractionLength(0...2))) + " " + nutrient.unit)
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("quick-nutrition-nutrient-" + nutrient.rawValue)
                }
            }
        }
    }

    private func grams(_ title: String, text: Binding<String>, field: Field, unit: String? = "g") -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text, prompt: typeSize.isAccessibilitySize ? nil : Text("0").foregroundStyle(NativeDesign.secondary)).keyboardType(.decimalPad).focused($focus, equals: field)
                    .font(.title.weight(.semibold)).frame(minHeight: NativeDesign.Layout.nutritionInputLine)
                    .accessibilityLabel(unit == nil ? title : unit == "ml" ? title + " in millilitri" : unit == "g" ? title + " in grammi" : title + ", " + (unit ?? "")).accessibilityIdentifier("quick-nutrition-" + title)
                if let unit { Text(unit).foregroundStyle(.secondary) }
            }
        }.padding(NativeDesign.Space.small).frame(minHeight: NativeDesign.Layout.nutritionFieldHeight)
            .background(NativeDesign.nutritionInput, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .contentShape(Rectangle()).onTapGesture { focus = field }
    }
    private func save() {
        guard let value = pending ?? draft, !nutrition.busy, !blocked else { return }
        let retry = pending != nil
        focus = nil
        Task {
            if await nutrition.save(value, retry: retry) {
                onSaved(); dismiss()
                await health.refresh()
            }
        }
    }
}
