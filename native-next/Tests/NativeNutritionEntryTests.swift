import XCTest
@testable import LifeOSProbe
final class NativeNutritionEntryTests: XCTestCase {
    func testItalianDecimalsAndFourFourNineCalculation() {
        let entry = NativeNutritionEntry(id: UUID(), revision: 1, date: Date(), protein: 10, carbohydrate: 20, fat: 5, confirmed: false)
        XCTAssertEqual(entry.calories, 165)
        XCTAssertEqual(NativeNutritionEntry.grams("1,25"), Decimal(string: "1.25"))
        XCTAssertEqual(NativeNutritionEntry.grams("1.25"), Decimal(string: "1.25"))
        XCTAssertEqual(NativeNutritionEntry.grams(""), 0)
        for invalid in ["-1", "NaN", "inf", "1,2,3", "4g"] { XCTAssertNil(NativeNutritionEntry.grams(invalid)) }
    }
    func testTwentyGramPortionUsesLabelEnergyAndScalesFibre() throws {
        let entry = try XCTUnwrap(NativeNutritionEntry.portion(id: UUID(), date: Date(),
            protein: 6, carbohydrate: 60, fat: 20, fibre: 8, calories: 450, grams: 20))
        XCTAssertEqual(entry.protein, Decimal(string: "1.2"))
        XCTAssertEqual(entry.carbohydrate, 12)
        XCTAssertEqual(entry.fat, 4)
        XCTAssertEqual(entry.fibre, Decimal(string: "1.6"))
        XCTAssertEqual(entry.calories, 90)
        XCTAssertNotEqual(entry.calories, entry.protein * 4 + entry.carbohydrate * 4 + entry.fat * 9)
        XCTAssertEqual(entry.portionGrams, 20)
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry)), entry)
    }
    func testMissingLabelEnergyOrZeroPortionCannotCreateEntry() {
        let invalid: [(Decimal, Decimal)] = [(0, 20), (450, 0), (450, -1)]
        for (calories, grams) in invalid {
            XCTAssertNil(NativeNutritionEntry.portion(id: UUID(), date: Date(),
                protein: 6, carbohydrate: 60, fat: 20, fibre: 8, calories: calories, grams: grams))
        }
    }
}
