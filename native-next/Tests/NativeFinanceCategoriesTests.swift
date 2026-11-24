import XCTest
@testable import LifeOSProbe

/// CATEGORY-ADMIN-2026-11-24: the category list edited on the site drives Categoria/Voce in the app.
final class NativeFinanceCategoriesTests: XCTestCase {
    override func tearDown() { UserDefaults.standard.removeObject(forKey: NativeFinanceCategories.key); super.tearDown() }

    func testServerListReplacesTheBuiltInGroupsAndEmptyGoesBack() {
        UserDefaults.standard.removeObject(forKey: NativeFinanceCategories.key)
        XCTAssertEqual(NativeExpenseGroups.order.map(\.group), NativeExpenseGroups.builtIn.map(\.group))
        let doc: Record = ["groups": .array([
            .object(["name": .string("Casa"), "items": .array([.string("Affitto"), .string(" Lavanderia "), .string("")])]),
            .object(["name": .string("Regali"), "items": .array([.string("Regali"), .string("Affitto")])]),
            .object(["name": .string("Vuoto"), "items": .array([])]),
        ]), "income": .array([.string("Stipendio"), .string("Altre entrate")])]
        NativeFinanceCategories.store(doc)
        XCTAssertEqual(NativeExpenseGroups.order.map(\.group), ["Casa", "Regali"], "empty groups are dropped")
        XCTAssertEqual(NativeExpenseGroups.order.first?.items, ["Affitto", "Lavanderia"], "blanks trimmed and removed")
        XCTAssertEqual(NativeExpenseGroups.order.last?.items, ["Regali"], "an item belongs to one group only")
        XCTAssertEqual(NativeExpenseGroups.group(of: "Lavanderia"), "Casa")
        XCTAssertEqual(NativeCategoryCatalog.choices(type: "Spesa", current: "Benzina"), ["Affitto", "Lavanderia", "Regali", "Benzina"], "an old category stays selectable on its movement")
        XCTAssertEqual(NativeCategoryCatalog.incomeChoices, ["Stipendio", "Altre entrate"])
        NativeFinanceCategories.store([:])
        XCTAssertNil(NativeFinanceCategories.current)
        XCTAssertEqual(NativeExpenseGroups.order.map(\.group), NativeExpenseGroups.builtIn.map(\.group))
    }
}
