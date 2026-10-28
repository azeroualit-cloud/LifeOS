import XCTest
@testable import LifeOSProbe

final class NativeExpenseRoutingTests: XCTestCase {
    func testSuggestionRequiresChoiceForMultipleMatchesAndSplitNeverExceedsPayment() {
        XCTAssertEqual(NativeExpenseRouting.suggestion([]), NativeExpenseRouting.ordinary)
        XCTAssertEqual(NativeExpenseRouting.suggestion([["id": .string("a")]]), "a")
        XCTAssertEqual(NativeExpenseRouting.suggestion([["id": .string("a")],["id": .string("b")]]), "")
        XCTAssertEqual(NativeExpenseRouting.split(amount: 3000, plan: ["availableCents": .int(2000)]).fund, 2000)
        XCTAssertEqual(NativeExpenseRouting.split(amount: 3000, plan: ["availableCents": .int(2000)]).savings, 1000)
        XCTAssertEqual(NativeExpenseRouting.split(amount: 3000, plan: ["availableCents": .int(9000)]).fund, 3000)
    }
    private func fixture() throws -> NativeArchive {
        var state = DemoData.make()
        try NativePlanDemo.apply("saveFinancePlan", payload: ["requestId": .string("water-plan-demo"), "kind": .string("estimated"), "category": .string("Acqua"), "name": .string("Acqua"), "amountCents": .int(2000), "startMonth": .string(CivilDate.month())], state: &state)
        return state
    }
    private func expense(_ selected: String) -> Record {
        var result = NativeExpenseRouting.destination(selected)
        result.merge(["requestId": .string("water-payment-demo"), "type": .string("Spesa"), "account": .string("Trade Republic"), "category": .string("Acqua"), "amount": .number(30), "name": .string("Bolletta acqua"), "date": .string(CivilDate.day()), "note": .string("Nota personale"), "competenceMonths": .int(1)]) { _, value in value }
        return result
    }
    func testDemoWaterUsesFundAndSavingsWithoutSecondBudgetChargeOrDuplicate() throws {
        var state = try fixture()
        let count = state.finance.records("transactions").count, before = state.finance.record("summary").amount("monthlyRemaining"), bank = state.finance.record("summary").amount("budget")
        let payload = expense("water-plan-demo")
        try NativeExpenseDemo.apply("saveTransaction", payload: payload, state: &state)
        try NativeExpenseDemo.apply("saveTransaction", payload: payload, state: &state)
        XCTAssertEqual(state.finance.records("transactions").count, count + 1)
        XCTAssertEqual(state.finance.record("summary").amount("budget"), bank - 30, accuracy: 0.001)
        XCTAssertEqual(state.finance.record("summary").amount("monthlyRemaining"), before, accuracy: 0.001)
        XCTAssertEqual(state.finance.records("transactions").last?.text("name"), "Bolletta acqua")
        XCTAssertEqual(state.finance.records("transactions").last?.text("note"), "Nota personale")
    }
    func testDemoExistingExpenseChangesDestinationWithoutChangingCashOrIdentity() throws {
        var state = try fixture()
        try NativeExpenseDemo.apply("saveTransaction", payload: expense(NativeExpenseRouting.ordinary), state: &state)
        let original = state.finance.records("transactions").last!, bank = state.finance.record("summary").amount("budget"), remaining = state.finance.record("summary").amount("monthlyRemaining")
        var route = NativeExpenseRouting.destination("water-plan-demo")
        route["requestId"] = .string("attach-water-demo"); route["movementId"] = original["row"]; route["expectedPaymentId"] = .string(""); route["competenceMonths"] = .int(1)
        try NativeExpenseDemo.apply("changeExpenseDestination", payload: route, state: &state)
        XCTAssertEqual(state.finance.record("summary").amount("budget"), bank, accuracy: 0.001)
        XCTAssertEqual(state.finance.record("summary").amount("monthlyRemaining"), remaining + 30, accuracy: 0.001)
        var detach = NativeExpenseRouting.destination(NativeExpenseRouting.ordinary)
        detach["requestId"] = .string("detach-water-demo"); detach["movementId"] = original["row"]; detach["expectedPaymentId"] = route["requestId"]
        try NativeExpenseDemo.apply("changeExpenseDestination", payload: detach, state: &state)
        try NativeExpenseDemo.apply("changeExpenseDestination", payload: detach, state: &state)
        XCTAssertEqual(state.finance.record("summary").amount("budget"), bank, accuracy: 0.001)
        XCTAssertEqual(state.finance.record("summary").amount("monthlyRemaining"), remaining, accuracy: 0.001)
        XCTAssertEqual(state.finance.records("transactions").last?.integer("row"), original.integer("row"))
    }
}
