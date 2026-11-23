import XCTest
@testable import LifeOSProbe

/// MICRO-BREAKDOWN-2026-11-24: the foods behind a nutrient, largest first, shares adding up to 100%.
final class NativeNutrientSourcesTests: XCTestCase {
    func testFoodsOfTheDaySortedWithShares() {
        let day = Date()
        func entry(_ name: String, _ mg: Decimal, confirmed: Bool = true, date: Date = Date()) -> NativeNutritionEntry {
            var e = NativeNutritionEntry(id: UUID(), revision: 1, date: date, protein: 1, carbohydrate: 1, fat: 1, confirmed: confirmed, foodName: name)
            e.nutrientValues = [NativeTrackedNutrient.vitaminC.rawValue: NativeNutrientAmount(amount: mg, estimateSource: nil)]
            return e
        }
        let entries = [entry("Arancia", 60), entry("Kiwi", 20), entry("Non confermato", 100, confirmed: false),
                       entry("Ieri", 50, date: Calendar.current.date(byAdding: .day, value: -1, to: day)!)]
        let rows = NativeNutrientSources.rows(.vitaminC, entries: entries, on: day)
        XCTAssertEqual(rows.map(\.name), ["Arancia", "Kiwi"])
        XCTAssertEqual(rows.first?.share ?? 0, 0.75, accuracy: 0.0001)
    }
}
