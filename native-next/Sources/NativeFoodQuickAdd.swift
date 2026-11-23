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
    @State private var quantity = "100"
    @State private var detail: NativeGenericFood?
    @State private var manual = false
    @State private var added: String?

    var body: some View {
        NavigationStack {
            NativeFoodPicker(quickQuantity: $quantity, quickAdd: add, onManual: { manual = true }, confirmation: added,
                             accessory: AnyView(NativeSupplementStackStrip(date: initialDate) { text in added = text; onSaved(); Task { await health.refresh() } })) { food in
                detail = food
            }
            .navigationTitle("Aggiungi alimento")
        }
        .sheet(item: $detail) { food in
            NavigationStack { NativeNutritionQuickSheet(initialDate: initialDate, initialFood: food) { onSaved(); dismiss() } }
                .environmentObject(health)
        }
        .sheet(isPresented: $manual) {
            NavigationStack { NativeNutritionQuickSheet(initialDate: initialDate) { onSaved(); dismiss() } }
                .environmentObject(health)
        }
    }

    /// Quantity of a quick add: grams for food, the usual dose for supplements and drinks counted per unit.
    static func quantity(for food: NativeGenericFood, typed: String) -> Decimal? {
        if food.cocktail != nil || (food.family == .supplement && !food.quantityUnit.isMassOrVolume) { return food.defaultQuantity ?? 1 }
        guard let grams = NativeNutritionEntry.grams(typed), grams > 0, grams <= 9999 else { return nil }
        return grams
    }

    private func add(_ food: NativeGenericFood) {
        guard !nutrition.busy, let amount = Self.quantity(for: food, typed: quantity) else { return }
        let now = Date(), day = Calendar.current.isDate(initialDate, inSameDayAs: now) ? now : initialDate
        guard let entry = food.portion(id: UUID(), date: day, grams: amount) else { return }
        Task {
            if await nutrition.save(entry) {
                let unit = food.cocktail != nil || (food.family == .supplement && !food.quantityUnit.isMassOrVolume) ? "" : " g"
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
