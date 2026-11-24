import SwiftUI

/// FOOD-QUICK-ADD-2026-11-23: «Alimento» opens the search at once. The grams are typed first; the +
/// on a result records that quantity without leaving the list, so several foods go in a row.
/// Tapping the food itself opens the detailed sheet (units, bone, portion); manual macros stay at the bottom.
struct NativeFoodQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var health: NativeHealthStore
    @ObservedObject private var nutrition = NativeNutritionUIFixture.current
    var initialDate: Date = .now
    var onSaved: () -> Void = {}
    @State private var detail: NativeGenericFood?
    @State private var manual = false
    @State private var added: String?
    @State private var newStack: NativeSupplementStack?

    var body: some View {
        NavigationStack {
            NativeFoodPicker(quickAdd: add, onManual: { manual = true },
                             onNewStack: { newStack = NativeSupplementStack(id: UUID().uuidString, name: "", items: []) }, confirmation: added,
                             accessory: AnyView(NativeSupplementStackStrip(date: initialDate, showsNew: false) { text in added = text; onSaved(); Task { await health.refresh() } }
                                .padding(.bottom, NativeDesign.Space.small))) { food in
                detail = food
            }
            .navigationTitle("Aggiungi alimento")
        }
        .sheet(item: $detail) { food in
            NavigationStack { NativeNutritionQuickSheet(initialDate: initialDate, initialFood: food) { onSaved(); dismiss() } }
                .environmentObject(health)
        }
        .sheet(item: $newStack) { stack in NavigationStack { NativeSupplementStackEditor(stack: stack) } }
        .sheet(isPresented: $manual) {
            NavigationStack { NativeNutritionQuickSheet(initialDate: initialDate) { onSaved(); dismiss() } }
                .environmentObject(health)
        }
    }

    /// Quantity of a quick add: the number typed («avena 63»); supplements and drinks without a number use
    /// their usual dose (1 capsule/tablet when unset); a food without a number opens its detail to ask.
    static func quantity(for food: NativeGenericFood, typed: Decimal?) -> Decimal? {
        if let typed, typed > 0, typed <= 9999 { return typed }
        if food.family == .supplement { return food.defaultQuantity ?? (food.quantityUnit.isMassOrVolume ? nil : 1) }
        if food.cocktail != nil { return food.defaultQuantity ?? 1 }
        return nil
    }

    private func add(_ food: NativeGenericFood, _ typed: Decimal?) {
        guard !nutrition.busy else { return }
        guard let amount = Self.quantity(for: food, typed: typed) else {
            detail = food // no quantity: the detail asks for it
            return
        }
        let now = Date(), day = Calendar.current.isDate(initialDate, inSameDayAs: now) ? now : initialDate
        guard let entry = food.portion(id: UUID(), date: day, grams: amount) else { return }
        Task {
            if await nutrition.save(entry) {
                let unit = food.cocktail != nil || (food.family == .supplement && !food.quantityUnit.isMassOrVolume) ? "" : food.quantityUnit == .millilitre ? " ml" : " g"
                added = food.name + " · " + NSDecimalNumber(decimal: amount).stringValue + unit
                onSaved()
                await health.refresh()
            }
        }
    }
}

/// FOOD-QUICK-ADD-2026-11-23 «Ripeti da ieri»: the same food again on another day, as a new entry.
extension NativeNutritionEntry {
    func repeated(on day: Date, now: Date = .now, calendar: Calendar = .current) -> NativeNutritionEntry {
        var copy = self
        copy.id = UUID(); copy.revision = 0; copy.confirmed = false; copy.deletionPending = nil; copy.modifiedAt = nil
        if calendar.isDate(day, inSameDayAs: now) { copy.date = now }
        else {
            let time = calendar.dateComponents([.hour, .minute], from: date)
            copy.date = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
        }
        return copy
    }
}
