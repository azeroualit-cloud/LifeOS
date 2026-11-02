import XCTest
@testable import LifeOSProbe

final class NativeUtilityCompetenceTests: XCTestCase {
    func testRequestedPeriodAndExactShares() {
        var period = NativeUtilityPeriodDraft(); period.enabled = true; period.start = "2026-08"; period.end = "2026-10"
        XCTAssertEqual(period.months, ["2026-08", "2026-09", "2026-10"])
        XCTAssertEqual(period.shares(22179).map(\.cents), [7393, 7393, 7393])
        XCTAssertEqual(period.payload.text("competenceStartMonth"), "2026-08")
        XCTAssertEqual(period.payload.integer("competenceMonths"), 3)
        XCTAssertEqual(period.shares(10000).map(\.cents), [3334, 3333, 3333])
    }
    func testPeriodValidationAndNoInferenceFromLegacyCount() {
        var period = NativeUtilityPeriodDraft(record: ["competence_months": .int(3)])
        XCTAssertFalse(period.enabled); XCTAssertNil(period.months)
        period.start = "2026-10"; period.end = "2026-08"; XCTAssertNil(period.months)
        period.start = "2025-08"; period.end = "2026-10"; XCTAssertNil(period.months)
        period.start = "2026-12"; period.end = "2027-02"
        XCTAssertEqual(period.months, ["2026-12", "2027-01", "2027-02"])
    }
    private func fixture() -> NativeArchive {
        var state = DemoData.make()
        state.finance["summary"] = .object(["monthlySalary": .number(1800), "monthlyCommitted": .number(550), "monthlySpent": .number(0), "monthlyRemaining": .number(1250), "budget": .number(1000), "committedCurrent": .number(0),
            "monthlyBudgetBreakdown": .array([.object(["name": .string("Affitto"), "amount": .number(500)]), .object(["name": .string("Acqua"), "amount": .number(50)])])])
        state.finance["transactions"] = .array([])
        state.finance["plansV2"] = .object(["plans": .array([]), "payments": .array([])])
        return state
    }
    private func payload() -> Record {
        ["requestId": .string("synthetic-bill-75"), "name": .string("Bolletta sintetica"), "amount": .number(221.79), "type": .string("Spesa"), "account": .string("Trade Republic"), "category": .string("Acqua"), "date": .string(CivilDate.day()), "expenseRoutingVersion": .int(1), "expenseDestination": .string("ordinary"), "utilityCompetenceVersion": .int(1), "competenceStartMonth": .string("2026-08"), "competenceEndMonth": .string("2026-10"), "competenceMonths": .int(3)]
    }
    func testOrdinaryDemoBillUpdatesPastCostsWithoutDuplicatingCashAndOldRetryKeepsEditedPeriod() throws {
        var state = fixture(); let original = payload()
        try NativeExpenseDemo.apply("saveUtilityBill", payload: original, state: &state)
        try NativeExpenseDemo.apply("saveUtilityBill", payload: original, state: &state)
        XCTAssertEqual(state.finance.records("transactions").count, 1)
        XCTAssertEqual(state.finance.records("transactions")[0].amount("amount"), -221.79)
        for month in ["2026-08", "2026-09", "2026-10"] {
            NativePlanDemo.project(month: month, state: &state)
            XCTAssertEqual(state.finance.record("summary").amount("monthlyCommitted"), 573.93, accuracy: 0.001)
            XCTAssertEqual(state.finance.record("summary").amount("monthlyRemaining"), 1226.07, accuracy: 0.001)
            XCTAssertEqual(state.finance.record("summary").amount("monthlySpent"), 0, accuracy: 0.001)
        }
        var edit: Record = ["requestId": .string("synthetic-bill-edit-75"), "movementId": .int(state.finance.records("transactions")[0].integer("row")), "expenseDestination": .string("ordinary"), "expectedPaymentId": .string("")]
        edit.merge(original.filter { ["competenceEndMonth", "utilityCompetenceVersion"].contains($0.key) }) { _, new in new }
        edit["competenceStartMonth"] = .string("2026-09")
        try NativeExpenseDemo.apply("changeUtilityBill", payload: edit, state: &state)
        try NativeExpenseDemo.apply("saveUtilityBill", payload: original, state: &state)
        NativePlanDemo.project(month: "2026-08", state: &state)
        XCTAssertEqual(state.finance.record("summary").amount("monthlyRemaining"), 1250, accuracy: 0.001)
        XCTAssertEqual(state.finance.records("transactions").count, 1)
        XCTAssertEqual(state.finance.records("utilityBills")[0].record("utilityPeriod").text("start"), "2026-09")
    }
    func testBudgetFlowShowsCostOnceAndKeepsFundAccessible() {
        let summary: Record = ["monthlySalary": .number(1800), "monthlySpent": .number(0), "monthlyRemaining": .number(1726.07), "utilityCompetenceVersion": .int(1),
            "monthlyBudgetBreakdown": .array([.object(["name": .string("Acqua"), "amount": .number(73.93)])])]
        let plan: Record = ["id": .string("water"), "name": .string("Acqua"), "category": .string("Acqua"), "kind": .string("estimated"), "contributionCents": .int(5000), "status": .string("active"), "startMonth": .string("2026-08")]
        let flow = NativeBudgetFlow(summary: summary, plans: [plan], month: "2026-09")
        XCTAssertEqual(flow.rows.count, 1); XCTAssertEqual(flow.rows[0].amountCents, 7393); XCTAssertEqual(flow.rows[0].planID, "water")
    }
}
