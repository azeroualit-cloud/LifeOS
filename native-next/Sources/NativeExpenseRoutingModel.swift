import Foundation

/// Shared by the form, previews and the explicit demo adapter. Server remains authoritative.
enum NativeExpenseRouting {
    static let ordinary = "__ordinary"
    static func plans(_ source: [Record], payments: [Record], category: String, day: String) -> [Record] {
        source.filter { p in
            ["fixed", "estimated", "goal", "fund"].contains(p.text("kind")) && p.text("status") == "active" && p.text("category") == category && p.text("startMonth") <= String(day.prefix(7)) &&
            (!["fixed", "estimated"].contains(p.text("kind")) || !NativePlanRules.isPaid(p, payments: payments, month: String(day.prefix(7))))
        }.sorted { $0.text("name") < $1.text("name") }
    }
    static func suggestion(_ plans: [Record]) -> String {
        plans.isEmpty ? ordinary : plans.count == 1 ? plans[0].text("id") : ""
    }
    static func available(_ plan: Record) -> Int { max(0, plan.integer(plan["availableCents"] == nil ? "fundCents" : "availableCents")) }
    static func split(amount: Int, plan: Record) -> (fund: Int, savings: Int) {
        let fund = min(max(0, amount), available(plan)); return (fund, max(0, amount - fund))
    }
    static func destination(_ selected: String) -> Record {
        var payload: Record = ["expenseRoutingVersion": .int(1), "expenseDestination": .string(selected == ordinary ? "ordinary" : "plan")]
        if selected != ordinary { payload["planId"] = .string(selected) }
        return payload
    }
}

