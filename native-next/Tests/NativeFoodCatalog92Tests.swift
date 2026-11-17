import XCTest
@testable import LifeOSProbe

/// FOOD-CATALOG-92 and SUPPLEMENTS-PERSONAL-ONLY-92.
final class NativeFoodCatalog92Tests: XCTestCase {
    private let required = ["vitaminC", "zinc", "vitaminA", "vitaminD", "vitaminE", "vitaminK1", "vitaminK2", "vitaminB1", "vitaminB2",
                            "vitaminB3", "vitaminB5", "vitaminB6", "vitaminB12", "calcium", "chloride", "copper", "iron", "iodine",
                            "magnesium", "manganese", "phosphorus", "potassium", "selenium", "sodium", "ala", "epa", "dha"]

    func testEveryGenericFoodHasCompleteMicronutrients() {
        XCTAssertGreaterThanOrEqual(NativeGenericFood.foods.count, 380)
        for food in NativeGenericFood.foods {
            let values = food.nutrientValues ?? [:]
            let missing = required.filter { values[$0] == nil } + (values["folate"] == nil && values["folateMass"] == nil ? ["folate"] : [])
            XCTAssertTrue(missing.isEmpty, food.name + " misses " + missing.joined(separator: ","))
        }
    }

    func testNewGenericFoodsAreSearchable() {
        for query in ["albume", "skyr", "fiocchi di latte", "ricotta", "gallette", "datteri", "pane arabo", "msemen", "borlotti", "orata"] {
            XCTAssertFalse(NativeGenericFood.matches(query).isEmpty, query)
        }
    }

    func testEggIsLoggedByThePiece() throws {
        let egg = try XCTUnwrap(NativeGenericFood.foods.first { $0.name == "Uova" })
        let piece = try XCTUnwrap(egg.pieces?.first)
        XCTAssertEqual(piece.grams, 50)
        let two = try XCTUnwrap(egg.portion(id: UUID(), date: .now, grams: 2 * piece.grams))
        XCTAssertEqual(two.portionGrams, 100)
    }

    func testBrandedProductsCarryEstimatedMicronutrients() throws {
        let estimated = NativeGenericFood.catalog.filter { $0.nutrientEstimateFrom != nil }
        XCTAssertGreaterThan(estimated.count, 1000)
        let sample = try XCTUnwrap(estimated.first { $0.nutrientValues?["zinc"] != nil })
        XCTAssertTrue(sample.nutrientValues?["zinc"]?.estimateSource?.hasPrefix("stima:generico:") == true)
    }

    func testNoPresetSupplementsInTheCatalog() {
        XCTAssertFalse(NativeGenericFood.catalog.contains { $0.family == .supplement })
        XCTAssertTrue(NativeGenericFood.catalogSupplements.isEmpty)
    }
}
