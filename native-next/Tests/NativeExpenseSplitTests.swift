import XCTest
@testable import LifeOSProbe

/// REVIEW-95 / FUNDING-BLOCK-2026-11-21: savings and budget months chosen by the user.
final class NativeExpenseSplitTests: XCTestCase {
    func testDefaultIsThePlainMonthlyBudget() {
        let split = NativeExpenseSplit()
        XCTAssertFalse(split.isCustom(day: "2026-11-23"))
        XCTAssertNil(split.payload(amount: 4280, day: "2026-11-23"))
        XCTAssertEqual(split.budget(4280), 4280)
    }
    func testSavingsAndMonthsBecomeARecoveryWithTheServerRounding() {
        var split = NativeExpenseSplit()
        split.change(1000, amount: 18600)
        split.toggle("2026-12", day: "2026-11-23")
        XCTAssertEqual(split.chosenMonths(day: "2026-11-23"), ["2026-11", "2026-12"])
        let payload = split.payload(amount: 18601, day: "2026-11-23")
        XCTAssertEqual(payload?.text("budgetTreatment"), "recovery")
        XCTAssertEqual(payload?.text("recoveryMonths"), "2026-11, 2026-12")
        XCTAssertEqual(payload?.amount("recoveryAmount") ?? 0, 176.01, accuracy: 0.0001)
        XCTAssertEqual(split.shares(18601, day: "2026-11-23").map(\.cents), [8801, 8800], "extra cent on the first month, as the server")
    }
    func testSavingsNeverTakeTheWholeAmountAndTheLastMonthStays() {
        var split = NativeExpenseSplit()
        for _ in 0..<10 { split.change(NativeExpenseSplit.step, amount: 1200) }
        XCTAssertEqual(split.savings, 1199, "the whole amount from savings is the Risparmi destination")
        XCTAssertEqual(split.budget(1200), 1)
        split.toggle("2026-11", day: "2026-11-23")
        XCTAssertEqual(split.chosenMonths(day: "2026-11-23"), ["2026-11"], "at least one budget month")
        XCTAssertEqual(NativeExpenseSplit.offered(day: "2026-11-23").prefix(3), ["2026-11", "2026-12", "2027-01"])
    }
}
