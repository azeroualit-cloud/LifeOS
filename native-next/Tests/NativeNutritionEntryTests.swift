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
}
