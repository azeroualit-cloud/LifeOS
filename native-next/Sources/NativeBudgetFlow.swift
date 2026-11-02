import Foundation

/// Display projection only. Never creates a payment or changes the bank balance.
struct NativeBudgetFlow {
    struct Row: Identifiable {
        let id: Int
        let name: String
        let planID: String?
        let amountCents: Int
        let remainingCents: Int
    }
    let salaryCents: Int
    let spentCents: Int
    let remainingCents: Int
    let rows: [Row]
    var planIDs: Set<String> { Set(rows.compactMap(\.planID)) }
    init(summary: Record, plans: [Record], month: String) {
        func cents(_ key: String) -> Int { Int((summary.amount(key) * 100).rounded()) }
        salaryCents = cents("monthlySalary"); spentCents = cents("monthlySpent"); remainingCents = cents("monthlyRemaining")
        let separatesUtilityCosts = summary.integer("utilityCompetenceVersion") == 1
        let current = plans.filter { (!separatesUtilityCosts || $0.text("kind") != "estimated") && ($0.integer("contributionCents") != 0 || ($0.text("status") == "active" && $0.text("startMonth") <= month && ($0.text("endMonth").isEmpty || $0.text("endMonth") >= month))) }
        var entries: [(String, String?, Int)] = current.map { ($0.text("name"), $0.text("id"), $0.integer("contributionCents")) }
        entries += summary.records("monthlyBudgetBreakdown").filter { $0.text("planId").isEmpty && $0.amount("amount") != 0 }.map { row in
            let plan = separatesUtilityCosts ? plans.first { $0.text("kind") == "estimated" && $0.text("category") == row.text("name") } : nil
            return (row.text("name"), plan?.text("id"), Int((row.amount("amount") * 100).rounded()))
        }
        let difference = salaryCents - spentCents - remainingCents - entries.reduce(0) { $0 + $1.2 }
        if difference != 0 { entries.append(("Altri impegni del mese", nil, difference)) }
        var running = salaryCents
        rows = entries.enumerated().map { index, entry in
            running -= entry.2
            return Row(id: index, name: entry.0, planID: entry.1, amountCents: entry.2, remainingCents: running)
        }
    }
}
