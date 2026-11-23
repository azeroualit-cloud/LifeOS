import SwiftUI

/// MICRO-BREAKDOWN-2026-11-24: which foods of the day make up a nutrient's value.
enum NativeNutrientSources {
    struct Row: Identifiable, Equatable { let id: UUID; let name: String; let amount: Decimal; let estimated: Bool; let share: Double }
    static func rows(_ nutrient: NativeTrackedNutrient, entries: [NativeNutritionEntry], on day: Date, calendar: Calendar = .current) -> [Row] {
        let values = entries.filter { $0.confirmed && $0.deletionPending != true && calendar.isDate($0.date, inSameDayAs: day) }
            .compactMap { entry -> (NativeNutritionEntry, Decimal, Bool)? in
                guard let value = nutrient.value(in: entry), value.amount > 0 else { return nil }
                return (entry, value.amount, value.estimated)
            }
        let total = values.reduce(Decimal(0)) { $0 + $1.1 }
        guard total > 0 else { return [] }
        return values.sorted { $0.1 > $1.1 }.map { entry, amount, estimated in
            Row(id: entry.id, name: entry.foodName ?? "Senza nome", amount: amount, estimated: estimated,
                share: NSDecimalNumber(decimal: amount / total).doubleValue)
        }
    }
}

struct NativeNutrientSourcesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let nutrient: NativeTrackedNutrient
    let entries: [NativeNutritionEntry]
    let day: Date
    var body: some View {
        let rows = NativeNutrientSources.rows(nutrient, entries: entries, on: day)
        let total = rows.reduce(Decimal(0)) { $0 + $1.amount }
        let format: (Decimal) -> String = { $0.formatted(Decimal.FormatStyle().precision(.fractionLength(0...1))) + " " + nutrient.unit }
        NavigationStack {
            List {
                Section {
                    LabeledContent("Totale del giorno", value: format(total) + " / " + format(nutrient.dailyReference)).font(.subheadline.weight(.semibold))
                }
                Section("Da quali alimenti") {
                    if rows.isEmpty { Text("Nessun alimento del giorno contiene questo nutriente.").foregroundStyle(NativeDesign.secondary) }
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            HStack {
                                Text(row.name).font(.subheadline).lineLimit(2)
                                Spacer(minLength: NativeDesign.Space.small)
                                Text((row.estimated ? "≈" : "") + format(row.amount)).font(.subheadline).monospacedDigit()
                                Text(String(Int((row.share * 100).rounded())) + "%").font(.footnote).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                                    .frame(minWidth: NativeDesign.Layout.iconTile, alignment: .trailing)
                            }
                            ProgressView(value: row.share).tint(NativeDesign.nutritionTitle).accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("nutrient-source-" + row.id.uuidString)
                    }
                }
            }
            .modifier(NativeListAppearance())
            .navigationTitle(nutrient.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { NativeSheetConfirm(title: "Fine") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
