import XCTest
@testable import LifeOSProbe

/// NAV-E-SLOT-2026-11-25: only Finanza or Bloom can be the fifth tab.
final class NativeAppLayoutTests: XCTestCase {
    func testSlotAcceptsOnlyFinanceOrBloom() {
        XCTAssertEqual(NativeAppLayout.slot(from: "finance"), .finance)
        XCTAssertEqual(NativeAppLayout.slot(from: "bloom"), .bloom)
        XCTAssertNil(NativeAppLayout.slot(from: "tasks"))
        XCTAssertNil(NativeAppLayout.slot(from: nil))
    }
    @MainActor func testBarKeepsFourFixedTabsFirst() {
        XCTAssertEqual(Array(NativeAppLayout.shared.barOrder.prefix(4)), [.dashboard, .tasks, .calendar, .health])
        XCTAssertEqual(NativeAppLayout.shared.barOrder.count, 5)
    }
}
