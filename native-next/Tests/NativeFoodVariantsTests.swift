import XCTest
@testable import LifeOSProbe

/// FOOD-DB-RESET-2026-11-25: curated base with versions grouped by food.
final class NativeFoodVariantsTests: XCTestCase {
    func testBaseHasNoSupplementsAndGroupsChickenThigh() throws {
        let base = NativeGenericFood.baseFoods
        XCTAssertGreaterThan(base.count, 250)
        XCTAssertFalse(base.contains { $0.family == .supplement })
        XCTAssertTrue(base.allSatisfy { $0.origin == "base" && $0.id.hasPrefix("base-") })
        let thigh = base.filter { $0.group == "Coscia di pollo" }
        XCTAssertEqual(thigh.count, 6)
        XCTAssertTrue(thigh.allSatisfy { $0.boneInEdiblePercent != nil })
        let axes = NativeFoodVariants.axes(thigh)
        XCTAssertEqual(axes.map(\.name), ["Stato", "Pelle"])
        XCTAssertEqual(Set(axes[1].values), ["Con pelle", "Senza pelle"])
    }
    func testOneRowPerFoodAndPickKeepsTheOtherAxis() throws {
        let base = NativeGenericFood.baseFoods
        let rows = NativeFoodVariants.collapse(base)
        XCTAssertEqual(rows.filter { $0.food.group == "Coscia di pollo" }.count, 1)
        XCTAssertEqual(rows.first { $0.food.group == "Coscia di pollo" }?.count, 6)
        let thigh = base.filter { $0.group == "Coscia di pollo" }
        let raw = try XCTUnwrap(thigh.first { $0.variant == ["Stato": "Crudo", "Pelle": "Con pelle"] })
        let baked = NativeFoodVariants.pick(thigh, from: raw, axis: "Stato", value: "Al forno")
        XCTAssertEqual(baked?.variant, ["Stato": "Al forno", "Pelle": "Con pelle"])
        XCTAssertEqual(NativeFoodVariants.siblings(of: raw, in: base).count, 6)
    }
}
