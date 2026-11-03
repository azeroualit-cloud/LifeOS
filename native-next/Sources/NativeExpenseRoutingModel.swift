import Foundation

/// Shared by the form, previews and the explicit demo adapter. Server remains authoritative.
enum NativeExpenseRouting {
    static let ordinary = "__ordinary"
    static func coveredMonths(_ record: Record) -> Int {
        let values = [record.integer("financePlanCompetenceMonths"), record.integer("competence_months"), record.integer("months")]
        return min(12, max(1, values.first(where: { $0 > 0 }) ?? 1))
    }
    static func plans(_ source: [Record], payments: [Record], category: String, day: String, bill: Bool = false) -> [Record] {
        source.filter { p in
            ["fixed", "estimated", "goal", "fund"].contains(p.text("kind")) && p.text("status") == "active" && p.text("category") == category && (p.text("startMonth") <= String(day.prefix(7)) || bill && NativeUtilityPeriodDraft.isCostFund(p)) &&
            (bill && NativeUtilityPeriodDraft.isCostFund(p) || !["fixed", "estimated"].contains(p.text("kind")) || !NativePlanRules.isPaid(p, payments: payments, month: String(day.prefix(7))))
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


/// Capability failures must never be presented as connectivity failures.
enum NativeExpenseCapabilityError: LocalizedError {
    case routing, utilityCompetence
    var errorDescription: String? {
        switch self {
        case .routing: return "Il server collegato deve essere aggiornato per gestire fondi e pagamenti. I dati inseriti restano nell’editor."
        case .utilityCompetence: return "Il server collegato non supporta ancora il periodo della bolletta. Occorre aggiornarlo prima di confermare. I dati inseriti restano nell’editor."
        }
    }
    static func message(for error: Error) -> String {
        if let capability = error as? NativeExpenseCapabilityError { return capability.localizedDescription }
        if let network = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed].contains(network.code) {
            return "Connessione al server non disponibile. Controlla la rete e riprova. I dati inseriti restano nell’editor."
        }
        return "Non posso verificare la destinazione. " + error.localizedDescription + " I dati inseriti restano nell’editor."
    }
}
