import SwiftUI

struct NativeGenericFood: Decodable, Identifiable {
    let id: String
    let name: String
    let search: String
    let protein: Decimal
    let carbohydrate: Decimal
    let fat: Decimal
    let fibre: Decimal
    let calories: Decimal

    func portion(id: UUID, date: Date, grams: Decimal) -> NativeNutritionEntry? {
        guard var entry = NativeNutritionEntry.portion(id: id, date: date, protein: protein,
            carbohydrate: carbohydrate, fat: fat, fibre: fibre, calories: calories, grams: grams) else { return nil }
        entry.foodName = name
        return entry
    }

    // USDA FoodData Central, SR Legacy, April 2018. Values per 100 g.
    static let catalog: [Self] = {
        guard let url = Bundle.main.url(forResource: "generic-foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return foods
    }()
}

struct NativeFoodPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let select: (NativeGenericFood) -> Void

    private var matches: [NativeGenericFood] {
        let words = query.split(whereSeparator: \.isWhitespace)
        return Array(NativeGenericFood.catalog.lazy.filter { food in
            let search = food.name + " " + food.search
            return words.allSatisfy { search.localizedStandardContains(String($0)) }
        }.prefix(80))
    }

    var body: some View {
        List {
            Section {
                ForEach(matches) { food in
                    Button {
                        select(food)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                            Text(food.name)
                            Text("\(NSDecimalNumber(decimal: food.calories)) kcal / 100 g")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                    }
                }
                if matches.isEmpty {
                    Text(NativeGenericFood.catalog.isEmpty ? "Catalogo non disponibile" : "Nessun alimento trovato")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("USDA FoodData Central · SR Legacy")
            }
        }
        .modifier(NativeListAppearance())
        .navigationTitle("Alimenti generici")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Cerca alimento")
        .toolbar { DoneButton() }
    }
}
