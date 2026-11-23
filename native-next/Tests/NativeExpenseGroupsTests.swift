import XCTest
@testable import LifeOSProbe

final class NativeExpenseGroupsTests: XCTestCase {
    func testGroupsKeepOrderAndPlaceEveryChoice() {
        let grouped = NativeExpenseGroups.grouped(["Altro", "Benzina", "Gas", "Alimentari", "Nuova voce"])
        XCTAssertEqual(grouped.map(\.group), ["Casa", "Auto", "Spesa", "Altro"])
        XCTAssertEqual(grouped.last?.items, ["Nuova voce", "Altro"])
        XCTAssertEqual(NativeExpenseGroups.label("Benzina"), "Auto · Benzina")
        XCTAssertEqual(NativeExpenseGroups.label("Abbonamenti"), "Abbonamenti")
    }
}
