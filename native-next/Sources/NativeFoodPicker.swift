import SwiftUI

struct NativeGenericFood: Decodable, Identifiable {
    let id: String
    let name: String
    let detail: String?
    let aliases: [String]?
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

    // Anses. 2025. Ciqual French food composition table. Values per 100 g.
    static func matches(_ query: String) -> [Self] {
        let words = searchWords(query)
        guard !words.isEmpty else { return Array(catalog.prefix(24)) }

        return catalog.compactMap { food -> (food: Self, rank: Int)? in
            let name = searchWords(food.name)
            let aliases = (food.aliases ?? []).map(searchWords)
            if words == name { return (food, 0) }
            if aliases.contains(words) { return (food, 1) }
            let fields = name + searchWords(food.detail ?? "") + aliases.flatMap { $0 }
            guard words.allSatisfy({ word in fields.contains { $0.hasPrefix(word) } }) else { return nil }
            let rank = words.allSatisfy { word in name.contains { $0.hasPrefix(word) } } ? 2 : 3
            return (food, rank)
        }.sorted { $0.rank < $1.rank }.map { $0.food }
    }

    private static func searchWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

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

    @FocusState private var searchFocused: Bool

    var body: some View {
        let matches = NativeGenericFood.matches(query)

        VStack(spacing: NativeDesign.Space.none) {
            HStack(spacing: NativeDesign.Space.small) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Cerca alimento", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("generic-food-search")
            }
            .padding(.horizontal, NativeDesign.Space.medium)
            .frame(minHeight: NativeDesign.Layout.touchTarget)
            .background(NativeDesign.actionSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .padding(.horizontal, NativeDesign.Layout.screenInset)

            List {
                Section {
                    ForEach(matches) { food in
                        Button {
                            select(food)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                                Text(food.name)
                                if let detail = food.detail {
                                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("\(NSDecimalNumber(decimal: food.calories)) kcal / 100 g")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.frame(minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                        }.accessibilityIdentifier("generic-food-" + food.id)
                    }
                    if matches.isEmpty {
                        Text(NativeGenericFood.catalog.isEmpty ? "Catalogo non disponibile" : "Nessun alimento trovato")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Anses · Ciqual 2025")
                }
            }
            .modifier(NativeListAppearance())
            .scrollDismissesKeyboard(.interactively)
        }
        .background(NativeDesign.healthCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { DoneButton() }
        .task { searchFocused = true }
    }
}
