import SwiftUI

struct NativeNutritionQuickEntry: View {
    @State private var showing = false
    @State private var notice: String?
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack {
                Spacer()
                Button { notice = nil; showing = true } label: {
                    Label("Nutrizione", systemImage: "plus")
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                }.buttonStyle(NativeCompactPrimaryButtonStyle()).accessibilityIdentifier("quick-nutrition-open")
            }
            if let notice { Text(notice).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("quick-nutrition-notice") }
        }.sheet(isPresented: $showing) {
            NavigationStack { NativeNutritionQuickSheet { notice = "Registrazione salvata in Apple Salute." } }
                .modifier(NativeVisualTestSize()).modifier(NativeVisualTestMotion())
        }
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
    @State private var date = Date()
    @State private var showingHistory = false
    @State private var showingDate = false
    @FocusState private var focus: Field?
    private enum Field: Int, CaseIterable { case protein, carbohydrate, fat, fibre }
    private var pending: NativeNutritionEntry? { nutrition.entries.first { $0.id == id && !$0.confirmed } }
    private var blocked: Bool { nutrition.entries.contains { ($0.id != id && !$0.confirmed) || $0.deletionPending == true } }
    private var draft: NativeNutritionEntry? {
        guard let p = NativeNutritionEntry.grams(protein), let c = NativeNutritionEntry.grams(carbohydrate), let f = NativeNutritionEntry.grams(fat), let fi = NativeNutritionEntry.grams(fibre) else { return nil }
        return .direct(id: id, date: date, protein: p, carbohydrate: c, fat: f, fibre: fi)
    }
    var body: some View {
        VStack(spacing: NativeDesign.Space.none) {
            HStack(alignment: .top) {
                Text("Aggiungi nutrienti").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Spacer(minLength: NativeDesign.Space.small)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                        .background(NativeDesign.actionSurface, in: Circle())
                }.buttonStyle(.plain).disabled(nutrition.busy).accessibilityLabel("Chiudi").accessibilityIdentifier("quick-nutrition-close")
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.top, NativeDesign.Space.small)
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    Text("Quantità consumate").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.medium), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: NativeDesign.Space.medium) {
                        grams("Proteine", text: $protein, field: .protein)
                        grams("Carboidrati", text: $carbohydrate, field: .carbohydrate)
                        grams("Grassi", text: $fat, field: .fat)
                        grams("Fibre", text: $fibre, field: .fibre)
                    }.disabled(nutrition.busy || pending != nil)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text("Calorie").font(.headline)
                            Text("Calcolate automaticamente").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(draft.map { NSDecimalNumber(decimal: $0.calories).stringValue + " kcal" } ?? (allZero ? "0 kcal" : "Valori non validi"))
                            .font(.title2.bold()).monospacedDigit().accessibilityIdentifier("quick-nutrition-calories")
                    }
                    Divider()
                    HStack {
                        Text("Data")
                        Spacer()
                        Button { focus = nil; showingDate = true } label: {
                            Label(Calendar.current.isDateInToday(date) ? "Oggi" : date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .padding(.horizontal, NativeDesign.Space.medium).frame(minHeight: NativeDesign.Layout.touchTarget)
                                .background(NativeDesign.actionSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
                        }.buttonStyle(.plain).disabled(nutrition.busy || pending != nil)
                            .accessibilityLabel("Data").accessibilityValue(date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityIdentifier("quick-nutrition-date")
                            .popover(isPresented: $showingDate) {
                                DatePicker("Data", selection: $date, displayedComponents: .date).datePickerStyle(.graphical).padding()
                                    .presentationCompactAdaptation(.popover)
                            }
                    }
                    if let error = nutrition.error { Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("quick-nutrition-error") }
                    if blocked {
                        Button("Completa la registrazione in sospeso dalla cronologia") { focus = nil; showingHistory = true }
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                    }
                }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.medium)
            }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("quick-nutrition-scroll")
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(NativeDesign.healthCanvas)
        .safeAreaInset(edge: .bottom, spacing: NativeDesign.Space.none) {
            Button(action: save) {
                HStack {
                    if nutrition.busy { ProgressView().accessibilityLabel("Salvataggio") }
                    Text(pending == nil ? "Aggiungi" : "Riprova").font(.headline)
                }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.rowHeight)
            }.buttonStyle(NativeCompactPrimaryButtonStyle())
                .disabled(nutrition.busy || blocked || (pending ?? draft) == nil)
                .accessibilityIdentifier("quick-nutrition-save")
                .padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.small)
                .background(NativeDesign.healthCanvas)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if let focus {
                    if focus != .fibre { Button("Avanti") { self.focus = Field(rawValue: focus.rawValue + 1) } }
                    Spacer()
                    Button("Fine") { self.focus = nil }.accessibilityIdentifier("quick-nutrition-keyboard-done")
                }
            }
        }
        .sheet(isPresented: $showingHistory) { NavigationStack { NativeNutritionScreen().toolbar { DoneButton() } } }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .interactiveDismissDisabled(nutrition.busy)
    }
    private var allZero: Bool {
        [protein, carbohydrate, fat, fibre].allSatisfy { NativeNutritionEntry.grams($0) == 0 }
    }
    private func grams(_ title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text).keyboardType(.decimalPad).focused($focus, equals: field)
                    .font(.title2.weight(.semibold)).frame(minHeight: NativeDesign.Layout.nutritionInputLine)
                    .accessibilityLabel(title + " in grammi").accessibilityIdentifier("quick-nutrition-" + title)
                Text("g").foregroundStyle(.secondary)
            }
        }.padding(NativeDesign.Space.small).frame(minHeight: NativeDesign.Layout.nutritionFieldHeight)
            .background(NativeDesign.actionSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
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
