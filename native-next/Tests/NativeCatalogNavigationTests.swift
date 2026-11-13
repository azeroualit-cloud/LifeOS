import XCTest
@testable import LifeOSProbe

@MainActor final class NativeCatalogNavigationTests: XCTestCase {
    func testSupplementsHaveTheirOwnScopeAndPersonalCopiesStayEditable() throws {
        let capsule = try XCTUnwrap(NativeGenericFood.brandedSupplements.first).personalCopy()
        let food = try XCTUnwrap(NativeGenericFood.foods.first).personalCopy()
        let personal = [capsule, food]
        XCTAssertFalse(NativeFoodPicker.items(in: .all, personal: personal).contains { $0.family == .supplement })
        let supplements = NativeFoodPicker.items(in: .supplements, personal: personal)
        XCTAssertTrue(supplements.allSatisfy { $0.family == .supplement })
        XCTAssertTrue(supplements.contains { $0.id == capsule.id })
        XCTAssertEqual(NativeFoodPicker.items(in: .personal, personal: personal).map(\.id), personal.map(\.id))
    }

    func testSearchSupportsBrandTokensAccentsAndExactBarcode() throws {
        let milk = try XCTUnwrap(NativeGenericFood.brandedFoods.first { $0.barcode != nil })
        XCTAssertEqual(NativeGenericFood.matches(try XCTUnwrap(milk.barcode)).first?.id, milk.id)
        let custom = NativeGenericFood(id: "personal-search", name: "CaffÃ¨ freddo", detail: nil,
            family: .drink, boneInEdiblePercent: nil, nutrientValues: nil, aliases: ["Espresso ghiacciato"],
            protein: 0, carbohydrate: 0, fat: 0, fibre: nil, calories: 0, brand: "Marca Prova")
        XCTAssertEqual(NativeGenericFood.matches("CAFFE prova", in: [custom]).first?.id, custom.id)
        XCTAssertEqual(NativeGenericFood.matches("espresso gh", in: [custom]).first?.id, custom.id)
        XCTAssertTrue(NativeGenericFood.matches("caffe inesistente", in: [custom]).isEmpty)
    }

    func testCoopSupplementsUseMassOrVolumeWithoutInventingCapsuleComposition() throws {
        let foods = NativeGenericFood.brandedFoods.filter { $0.sourceURL?.contains("/integratori/") == true }
        XCTAssertEqual(foods.count, 32)
        XCTAssertTrue(foods.allSatisfy { $0.family == .supplement && $0.quantityUnit.isMassOrVolume })
        let liquid = try XCTUnwrap(foods.first { $0.quantityUnit == .millilitre })
        let entry = try XCTUnwrap(liquid.portion(id: UUID(), date: .now, grams: 150))
        XCTAssertEqual(entry.portionMillilitres, 150)
        XCTAssertEqual(entry.quantityDescription, "150 ml")
        XCTAssertEqual(entry.calories, liquid.calories * 1.5)
    }

    func testPersonalEditSearchUsesCurrentNameRatherThanStaleIndex() throws {
        let original = try XCTUnwrap(NativeGenericFood.foods.first).personalCopy()
        var edited = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        edited["name"] = "Nome modificato unico"
        let food = try JSONDecoder().decode(NativeGenericFood.self, from: JSONSerialization.data(withJSONObject: edited))
        XCTAssertEqual(NativeGenericFood.matches("modificato unico", in: [food]).first?.id, original.id)
    }
}
