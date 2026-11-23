import XCTest
@testable import LifeOSProbe

/// SUPPLEMENT-STACK-2026-11-23: a stack becomes one entry per supplement with its dose.
@MainActor final class NativeSupplementStackTests: XCTestCase {
    func testStackEntriesUseEachDoseAndSkipMissingSupplements() throws {
        // Any catalog food works for the mapping (the test catalog has no supplements).
        let supplements = NativeFoodPicker.items(in: .all, personal: [])
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
        XCTAssertEqual(NativeFoodQuickAddSheet.quantity(for: food, typed: 150), 150)
        XCTAssertNil(NativeFoodQuickAddSheet.quantity(for: food, typed: nil), "a food without a number asks for it")
    }
    func testOneFieldNameAndQuantity() {
        XCTAssertEqual(NativeQuickQuery.parse("avena 63"), .init(name: "avena", quantity: 63))
        XCTAssertEqual(NativeQuickQuery.parse("63 avena"), .init(name: "avena", quantity: 63))
        XCTAssertEqual(NativeQuickQuery.parse("yogurt greco 150 g"), .init(name: "yogurt greco", quantity: 150))
        XCTAssertEqual(NativeQuickQuery.parse("latte 200ml"), .init(name: "latte", quantity: 200))
        XCTAssertEqual(NativeQuickQuery.parse("riso 72,5"), .init(name: "riso", quantity: Decimal(string: "72.5")))
        XCTAssertEqual(NativeQuickQuery.parse("avena"), .init(name: "avena", quantity: nil))
        XCTAssertEqual(NativeQuickQuery.parse("63"), .init(name: "63", quantity: nil), "a lone number stays a search (barcode)")
    }
}
