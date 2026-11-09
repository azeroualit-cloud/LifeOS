import Foundation

@MainActor enum NativeNutritionUIFixture {
    static var current: NativeNutritionStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--nutrition-ui-fixture") || ProcessInfo.processInfo.arguments.contains("--health-week-review") { return fixture }
        #endif
        return .shared
    }
    static func prepareReview() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--health-week-review"), !didSeedReview else { return }
        didSeedReview = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in -14...0 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  var item = NativeNutritionEntry.direct(id: UUID(), date: date, protein: 32,
                                                         carbohydrate: 65, fat: 18, fibre: 8) else { continue }
            item.foodName = "Pasto di prova"
            item.nutrientValues = [
                "vitaminC": .init(amount: 25, estimateSource: nil),
                "zinc": .init(amount: 11, estimateSource: nil),
                "potassium": .init(amount: 1800, estimateSource: nil),
                "epa": .init(amount: 90, estimateSource: nil),
                "dha": .init(amount: 110, estimateSource: nil)
            ]
            _ = await fixture.save(item)
        }
        if ProcessInfo.processInfo.arguments.contains("--health-catalog-review") {
            for name in ["Gin Tonic", "Gin Tonic", "Biscotti"] {
                guard let food = NativeGenericFood.matches(name).first,
                      let item = food.portion(id: UUID(), date: today, grams: food.cocktail == nil ? 100 : 1) else { continue }
                _ = await fixture.save(item)
            }
        }
        #endif
    }
    #if DEBUG
    private static var didSeedReview = false
    private static let fixture = NativeNutritionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), writer: Writer())
    private final class Writer: NativeNutritionWriting {
        private var attempted = false
        func authorize(includeFibre: Bool) async throws {}
        func write(_ entry: NativeNutritionEntry) async throws {
            if !attempted && ProcessInfo.processInfo.arguments.contains("--nutrition-write-failure") {
                attempted = true; throw Message(text: "Scrittura interrotta. Riprova senza reinserire i valori.")
            }
        }
        func delete(_ entry: NativeNutritionEntry) async throws {}
    }
    #endif
}
