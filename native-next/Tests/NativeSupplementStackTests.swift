import XCTest
@testable import LifeOSProbe

/// SUPPLEMENT-STACK-2026-11-23: a stack becomes one entry per supplement with its dose.
@MainActor final class NativeSupplementStackTests: XCTestCase {
    func testStackEntriesUseEachDoseAndSkipMissingSupplements() throws {
        let supplements = NativeFoodPicker.items(in: .supplements, personal: [])
        let first = try XCTUnwrap(supplements.first)
        let stack = NativeSupplementStack(id: "s1", name: "Mattina", items: [
            .init(foodID: first.id, name: first.name, quantity: 2),
            .init(foodID: "missing", name: "Altro", quantity: 1),
            .init(foodID: first.id, name: first.name, quantity: 0),
        ])
        let entries = NativeSupplementStackStore.entries(stack, date: .now, foods: supplements)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.foodName, first.name)
        let data = try JSONEncoder().encode(["stacks": [stack]])
        let decoded = try JSONDecoder().decode([String: [NativeSupplementStack]].self, from: data)
        XCTAssertEqual(decoded["stacks"], [stack], "the stacks travel as {stacks: [...]} like the site writes them")
    }
    func testQuickAddQuantity() throws {
        let food = try XCTUnwrap(NativeFoodPicker.items(in: .all, personal: []).first { $0.family != .supplement && $0.cocktail == nil })
        XCTAssertEqual(NativeFoodQuickAddSheet.quantity(for: food, typed: "150"), 150)
        XCTAssertNil(NativeFoodQuickAddSheet.quantity(for: food, typed: "0"))
    }
}
