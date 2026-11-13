import XCTest
@testable import LifeOSProbe

@MainActor final class NativeFoodCatalogPolicyTests: XCTestCase {
    func testSupermarketAlcoholIsHiddenButNightclubCocktailsRemain() {
        let excluded = NativeGenericFood.brandedFoods.filter { !NativeFoodCatalogPolicy.includes($0) }
        XCTAssertEqual(excluded.count, 128)
        XCTAssertTrue(excluded.allSatisfy { item in !NativeGenericFood.catalog.contains { $0.id == item.id } })
        XCTAssertEqual(NativeGenericFood.cocktails.count, 30)
        XCTAssertTrue(NativeGenericFood.cocktails.allSatisfy { item in NativeGenericFood.catalog.contains { $0.id == item.id } })
    }

    func testVinegarYeastAndSoftDrinksAreNotRemovedBySubstring() throws {
        let exceptions = ["coop-5f1d036420368a6f8d40", "coop-ean-8001120448323", "coop-ean-8001120779885"]
        for id in exceptions {
            let food = try XCTUnwrap(NativeGenericFood.brandedFoods.first { $0.id == id })
            XCTAssertTrue(NativeFoodCatalogPolicy.includes(food))
        }
        let vinegar = NativeGenericFood.brandedFoods.filter { $0.name.localizedCaseInsensitiveContains("aceto") }
        XCTAssertFalse(vinegar.isEmpty)
        XCTAssertTrue(vinegar.allSatisfy(NativeFoodCatalogPolicy.includes))
    }

    func testVisibilityPolicyDoesNotDeleteOrRewriteSavedPortions() throws {
        let food = try XCTUnwrap(NativeGenericFood.brandedFoods.first { !NativeFoodCatalogPolicy.includes($0) && $0.nutritionNotDeclared != true })
        let entry = try XCTUnwrap(food.portion(id: UUID(), date: .now, grams: 100))
        let decoded = try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(decoded.foodID, food.id)
        XCTAssertEqual(decoded.foodName, food.name)
        XCTAssertEqual(decoded.calories, entry.calories)
    }
}
