import Foundation

/// Explicit demo only. Production destinations are validated and committed by the Worker.
enum NativeExpenseDemo {
    static func preview(state: NativeArchive, category: String, day: String, movementID: Int) -> [Record] {
        var copy = state
        if movementID > 0 { try? removeLink(movementID, state: &copy) }
        return NativeExpenseRouting.plans(copy.finance.record("plansV2").records("plans"), payments: copy.finance.record("plansV2").records("payments"), category: category, day: day)
    }
    static func apply(_ method: String, payload: Record, state: inout NativeArchive) throws {
        var next = state
        let id = payload.text("requestId")
        guard !id.isEmpty else { throw Message(text: "Identificatore mancante.") }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let signature = method + String(data: try encoder.encode(payload), encoding: .utf8)!
        var commands = next.finance.record("expenseRoutingCommands")
        if let old = commands[id] { guard old.string == signature else { throw Message(text: "Operazione già usata con dati diversi.") }; return }
        var movement = payload
        if method == "changeExpenseDestination" {
            guard let old = next.finance.records("transactions").first(where: { $0.integer("row") == payload.integer("movementId") }), old.text("type") == "Spesa" else { throw Message(text: "Movimento non trovato.") }
            let linked = next.finance.record("plansV2").records("payments").first { $0.integer("movementId") == payload.integer("movementId") }
            guard (linked?.text("id") ?? "") == payload.text("expectedPaymentId") else { throw Message(text: "La destinazione è cambiata. Riapri il movimento.") }
            try removeLink(payload.integer("movementId"), state: &next)
            movement = old; movement["amount"] = .number(abs(old.amount("amount")))
        }
        let planned = payload.text("expenseDestination") == "plan"
        movement["budgetTreatment"] = .string(planned ? "savings" : "ordinary")
        if method == "changeExpenseDestination" { try DemoActions.apply("editMovement", movement, args: nil, state: &next) }
        if planned {
            let candidates = preview(state: next, category: movement.text("category"), day: movement.text("date"), movementID: 0)
            guard candidates.contains(where: { $0.text("id") == payload.text("planId") }) else { throw Message(text: "Piano non compatibile.") }
            var payment: Record = ["requestId": .string(id), "planId": payload["planId"]!, "amountCents": .int(Int((movement.amount("amount") * 100).rounded())), "date": movement["date"]!, "cycleMonth": .string(String(movement.text("date").prefix(7))), "competenceMonths": .int(max(1, payload.integer("competenceMonths")))]
            if method == "changeExpenseDestination" { payment["movementId"] = payload["movementId"] }
            try NativePlanDemo.apply("recordFinancePlanPayment", payload: payment, state: &next)
            if method != "changeExpenseDestination", let index = next.finance.records("transactions").firstIndex(where: { $0.text("requestId") == id }) {
                var rows = next.finance.records("transactions"); rows[index]["name"] = payload["name"]; rows[index]["note"] = payload["note"]; next.finance["transactions"] = .array(rows.map(JSONValue.object))
            }
        } else if method != "changeExpenseDestination" { try DemoActions.apply("saveTransaction", movement, args: nil, state: &next) }
        NativePlanDemo.project(month: next.financeMonth, state: &next)
        commands[id] = .string(signature); next.finance["expenseRoutingCommands"] = .object(commands); state = next
    }
    private static func removeLink(_ row: Int, state: inout NativeArchive) throws {
        var data = state.finance.record("plansV2"), plans = data.records("plans"), payments = data.records("payments")
        guard let old = payments.first(where: { $0.integer("movementId") == row }) else { return }
        guard let index = plans.firstIndex(where: { $0.text("id") == old.text("planId") }), plans[index].text("kind") != "recovery" else { throw Message(text: "Gestisci questo pagamento dal piano.") }
        payments.removeAll { $0.text("id") == old.text("id") }
        if plans[index].text("kind") == "goal", plans[index].text("status") == "closed" { plans[index]["status"] = .string("active"); plans[index]["closedMonth"] = .null }
        if plans[index].text("kind") == "estimated" {
            let history = payments.filter { $0.text("planId") == old.text("planId") }.sorted { $0.text("date") < $1.text("date") }.suffix(12)
            let total = history.reduce(0) { $0 + $1.integer("amountCents") }, months = history.reduce(0) { $0 + max(1,$1.integer("competenceMonths")) }
            let from = NativePlanRules.adding(1, to: CivilDate.month())
            var rates = plans[index].records("rateChanges").filter { $0.text("fromMonth") != from }
            rates.append(["fromMonth": .string(from), "amountCents": .int(months == 0 ? plans[index].integer("amountCents") : max(1,Int((Double(total)/Double(months)).rounded())))])
            plans[index]["rateChanges"] = .array(rates.map(JSONValue.object))
        }
        for i in plans.indices where plans[i].text("sourcePaymentId") == old.text("id") { plans[i]["status"] = .string("cancelled") }
        data["plans"] = .array(plans.map(JSONValue.object)); data["payments"] = .array(payments.map(JSONValue.object)); state.finance["plansV2"] = .object(data)
        NativePlanDemo.project(month: state.financeMonth, state: &state)
    }
}
