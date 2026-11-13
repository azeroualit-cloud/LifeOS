import XCTest
@testable import LifeOSProbe

@MainActor final class NativeCatalogExpansionTests: XCTestCase {
    func testCommunityCatalogLoadsWithTraceableSourcesAndUniqueIdentities() throws {
        let foods = NativeGenericFood.communityFoods
        XCTAssertFalse(foods.isEmpty)
        XCTAssertEqual(Set(foods.map(\.id)).count, foods.count)
        for food in foods {
            XCTAssertTrue(food.isCommunitySourced, food.id)
            XCTAssertNotNil(food.brand)
            XCTAssertNotNil(food.dataNote)
            XCTAssertTrue(["g", "ml"].contains(food.measurementBasis ?? ""))
            XCTAssertNotNil(food.portion(id: UUID(), date: .now, grams: 100), food.id)
        }
        let barilla = try XCTUnwrap(foods.first { $0.brand?.localizedCaseInsensitiveContains("Barilla") == true })
        XCTAssertTrue(NativeGenericFood.matches("barilla").contains { $0.id == barilla.id })
        XCTAssertTrue(NativeGenericFood.matches(try XCTUnwrap(barilla.barcode)).contains { $0.id == barilla.id })
    }

    func testCommunitySourceIsExplicitAndDoesNotTrustSimilarHostNames() throws {
        let data = try JSONEncoder().encode(XCTUnwrap(NativeGenericFood.italianBrands.first))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["sourceURL"] = "https://it.openfoodfacts.org/prodotto/123"
        let community = try JSONDecoder().decode(NativeGenericFood.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(community.isCommunitySourced)
        object["sourceURL"] = "https://openfoodfacts.org.example.com/prodotto/123"
        let other = try JSONDecoder().decode(NativeGenericFood.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(other.isCommunitySourced)
    }
}
