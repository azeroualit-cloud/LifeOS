import Foundation

/// Isolated demo projection. Production costs come from the authoritative Worker.
enum NativeUtilityDemo {
    static func reestimated(_ plan: Record, payments: [Record], today: String) -> Record {
        guard plan.text("kind") == "estimated", plan.text("status") == "active" else { return plan }
        let history = payments.filter { $0.text("planId") == plan.text("id") && $0.text("status") == "posted" }.sorted { $0.text("date") < $1.text("date") }.suffix(12)
        guard !history.isEmpty else { return plan }
        let total = history.reduce(0) { $0 + $1.integer("amountCents") }, months = history.reduce(0) { $0 + max(1, $1.integer("competenceMonths")) }
        let from = NativePlanRules.adding(1, to: String(today.prefix(7)))
        var value = plan, changes = plan.records("rateChanges").filter { $0.text("fromMonth") != from }
        changes.append(["fromMonth": .string(from), "amountCents": .int(max(1, Int((Double(total) / Double(months)).rounded())))])
        value["rateChanges"] = .array(changes.sorted { $0.text("fromMonth") < $1.text("fromMonth") }.map(JSONValue.object))
        return value
    }
    static func editLinkedPeriod(_ payload: Record, paymentID: String, state: inout NativeArchive) throws {
        let period = NativeUtilityPeriodDraft(record: payload)
        guard let months = period.months else { throw Message(text: "Periodo non valido.") }
        var data = state.finance.record("plansV2"), payments = data.records("payments"), plans = data.records("plans")
        guard let index = payments.firstIndex(where: { $0.text("id") == paymentID && $0.text("status") == "posted" }),
              let planIndex = plans.firstIndex(where: { $0.text("id") == payments[index].text("planId") && $0.text("kind") != "recovery" }) else { throw Message(text: "Completa prima il pagamento in sospeso.") }
        payments[index]["utilityPeriod"] = .object(["start": .string(period.start), "end": .string(period.end)])
        payments[index]["competenceMonths"] = .int(months.count)
        plans[planIndex] = reestimated(plans[planIndex], payments: payments, today: CivilDate.day())
        data["payments"] = .array(payments.map(JSONValue.object)); data["plans"] = .array(plans.map(JSONValue.object))
        state.finance["plansV2"] = .object(data); state.finance["utilityCompetenceEnabled"] = .bool(true)
    }
    static func enriched(_ record: Record, state: NativeArchive) -> Record {
        let row = record.integer("row")
        let candidates = state.finance.records("utilityBills") + state.finance.record("plansV2").records("payments")
        guard let bill = candidates.first(where: { $0.integer("movementId") == row && !$0.record("utilityPeriod").isEmpty }) else { return record }
        var value = record; value["utilityPeriod"] = bill["utilityPeriod"]; return value
    }
    static func project(month: String, state: inout NativeArchive) {
        guard state.finance.flag("utilityCompetenceEnabled") else { return }
        let transactions = state.finance.records("transactions")
        let plans = state.finance.record("plansV2").records("plans").filter(NativeUtilityPeriodDraft.isCostFund)
        let payments = state.finance.record("plansV2").records("payments")
        let ordinary = state.finance.records("utilityBills").filter { bill in transactions.contains { $0.integer("row") == bill.integer("movementId") } }
        state.finance["utilityBills"] = .array(ordinary.map(JSONValue.object))
        let bills = ordinary + payments.filter { !$0.record("utilityPeriod").isEmpty }
        let categories = Set(plans.map { $0.text("category") } + bills.compactMap { bill in transactions.first { $0.integer("row") == bill.integer("movementId") }?.text("category") })
        var summary = state.finance.record("summary"), baseline = state.finance.record("demoUtilityBaseline")
        var breakdown = summary.records("monthlyBudgetBreakdown")
        var delta = 0
        for category in categories {
            if baseline[category] == nil {
                var value = breakdown.filter { $0.text("name") == category }.reduce(0) { $0 + Int(($1.amount("amount") * 100).rounded()) }
                if value == 0, let i = breakdown.firstIndex(where: { $0.text("name") == "Bollette e abbonamenti" }) {
                    let estimate = state.finance.records("recurring").first { $0.text("name") == category }?.amount("estimate") ?? 0
                    value = min(Int((estimate * 100).rounded()), Int((breakdown[i].amount("amount") * 100).rounded()))
                    breakdown[i]["amount"] = .number(breakdown[i].amount("amount") - Double(value) / 100)
                }
                baseline[category] = .int(value)
            }
            let actual = bills.compactMap { bill -> Int? in
                guard let row = transactions.first(where: { $0.integer("row") == bill.integer("movementId") && $0.text("category") == category }) else { return nil }
                return NativeUtilityPeriodDraft(record: bill).shares(Int((abs(row.amount("amount")) * 100).rounded())).first { $0.month == month }?.cents
            }
            let profiles = plans.filter { $0.text("category") == category && $0.text("startMonth") <= month }
            let estimate = profiles.isEmpty ? baseline.integer(category) : profiles.reduce(0) { $0 + NativePlanRules.contribution($1, month: month) }
            let cost = actual.isEmpty ? estimate : actual.reduce(0, +)
            delta += cost - baseline.integer(category)
            breakdown.removeAll { $0.text("name") == category }
            if cost != 0 { breakdown.append(["name": .string(category), "amount": .number(Double(cost) / 100), "competenceSource": .string(actual.isEmpty ? "estimate" : "actual")]) }
        }
        let refund = ordinary.compactMap { bill in transactions.first { $0.integer("row") == bill.integer("movementId") } }
            .filter { $0.text("date").hasPrefix(CivilDate.month()) && $0.text("budgetTreatment") == "ordinary" }
            .reduce(0) { $0 + Int((abs($1.amount("amount")) * 100).rounded()) }
        let previousCost = state.finance.integer("demoUtilityCostDelta"), previousRefund = state.finance.integer("demoUtilityCashRefund")
        summary["monthlyRemaining"] = .number(summary.amount("monthlyRemaining") + Double(previousCost - delta + refund - previousRefund) / 100)
        summary["monthlyCommitted"] = .number(summary.amount("monthlyCommitted") + Double(delta - previousCost) / 100)
        summary["monthlySpent"] = .number(summary.amount("monthlySpent") - Double(refund - previousRefund) / 100)
        summary["monthlyBudgetBreakdown"] = .array(breakdown.map(JSONValue.object)); summary["utilityCompetenceVersion"] = .int(1)
        state.finance["summary"] = .object(summary); state.finance["demoUtilityBaseline"] = .object(baseline)
        state.finance["demoUtilityCostDelta"] = .int(delta); state.finance["demoUtilityCashRefund"] = .int(refund)
    }
}
