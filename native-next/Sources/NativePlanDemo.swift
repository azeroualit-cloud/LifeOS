import Foundation

/// Explicit offline demo adapter. Production calculations are validated by the server.
enum NativePlanDemo {
    static func apply(_ method: String, payload: Record, state: inout NativeArchive, today: String = CivilDate.day()) throws {
        var next = state, data = next.finance.record("plansV2")
        var plans = data.records("plans"), payments = data.records("payments"), commands = data.record("commands")
        let id = payload.text("requestId")
        guard !id.isEmpty else { throw Message(text: "Identificatore operazione mancante.") }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let fingerprint = String(data: try encoder.encode(payload), encoding: .utf8)!
        if let old = commands[id] {
            guard old.string == method + fingerprint else { throw Message(text: "Operazione già usata con dati diversi.") }; return
        }
        if payload.integer("movementId") > 0, payments.contains(where: { $0.integer("movementId") == payload.integer("movementId") }) { throw Message(text: "Movimento già collegato a un piano.") }
        if method == "saveFinancePlan" {
            guard let kind = NativePlanKind(rawValue: payload.text("kind")) else { throw Message(text: "Tipo di piano non valido.") }
            var draft = NativePlanDraft(); draft.kind = kind; draft.name = payload.text("name"); draft.category = payload.text("category", fallback: "Altro"); draft.amount = String(format: "%.2f", Double(payload.integer("amountCents")) / 100)
            draft.startMonth = payload.text("startMonth"); draft.endMonth = payload.text("endMonth"); draft.beneficiaryMonth = payload.text("beneficiaryMonth"); draft.paymentDate = payload.text("paymentDate"); draft.intervalMonths = max(1, payload.integer("intervalMonths"))
            var plan = try draft.payload(requestID: id, today: today)
            plan["id"] = .string(id); plan["status"] = .string("active"); plan["rateChanges"] = .array([])
            if kind == .recovery {
                let row = try recordCash(name: draft.name, category: draft.category, cents: payload.integer("amountCents"), day: draft.paymentDate, requestID: id, existing: payload.integer("movementId"), state: &next)
                payments.append(["id": .string(id), "planId": .string(id), "date": .string(draft.paymentDate), "amountCents": payload["amountCents"]!, "status": .string("posted"), "movementId": .int(row), "settlementKey": .string("once")])
            }
            plans.append(plan)
        } else {
            guard let index = plans.firstIndex(where: { $0.text("id") == payload.text("planId") }) else { throw Message(text: "Piano non trovato.") }
            var plan = plans[index]
            guard method == "deleteFinancePlanPayment" || plan.text("status") == "active" else { throw Message(text: "Il piano non è attivo.") }
            if method == "deleteFinancePlanPayment" {
                guard let payment = payments.first(where: { $0.text("id") == payload.text("paymentId") && $0.text("planId") == plan.text("id") }) else { throw Message(text: "Pagamento non trovato.") }
                var unlinked = data
                unlinked["payments"] = .array(payments.filter { $0.text("id") != payment.text("id") }.map(JSONValue.object))
                next.finance["plansV2"] = .object(unlinked)
                try DemoActions.apply("deleteMovement", [:], args: [.int(payment.integer("movementId"))], state: &next)
                payments.removeAll { $0.text("id") == payment.text("id") }
                if plan.text("kind") == "goal" && plan.text("status") == "closed" { plan["status"] = .string("active"); plan["closedMonth"] = .null }
                if plan.text("kind") == "recovery" { plan["status"] = .string("cancelled") }
                for i in plans.indices where plans[i].text("sourcePaymentId") == payment.text("id") { plans[i]["status"] = .string("cancelled") }
            } else if method == "editFinancePlan" {
                let amount = payload.integer("amountCents"), first = payload.text("fromMonth")
                guard amount > 0, amount <= 100_000_000, NativePlanRules.validMonth(first), first > String(today.prefix(7)), first >= plan.text("startMonth"), !["advance", "recovery"].contains(plan.text("kind")) else { throw Message(text: "Scegli una quota valida e un mese futuro del piano.") }
                if plan.text("kind") == "goal" {
                    let last = payload.text("endMonth"), future = try NativePlanRules.months(first, last)
                    let oldFuture = plan.text("endMonth") >= first ? try NativePlanRules.months(first, plan.text("endMonth")).reduce(0) { $0 + NativePlanRules.contribution(plan, month: $1) } : 0
                    let matured = plan.integer("amountCents") - oldFuture, remaining = max(0, amount - matured)
                    var schedule = plan.record("legacySchedule")
                    if schedule.isEmpty { for month in try NativePlanRules.months(plan.text("startMonth"), plan.text("endMonth")) { schedule[month] = .int(NativePlanRules.contribution(plan, month: month)) } }
                    schedule = schedule.filter { $0.key < first }
                    for (i, month) in future.enumerated() { schedule[month] = .int(remaining / future.count + (i < remaining % future.count ? 1 : 0)) }
                    plan["legacySchedule"] = .object(schedule); plan["endMonth"] = .string(last); plan["amountCents"] = .int(amount)
                } else {
                    var changes = plan.records("rateChanges").filter { $0.text("fromMonth") != first }
                    changes.append(["fromMonth": .string(first), "amountCents": .int(amount)])
                    plan["rateChanges"] = .array(changes.sorted { $0.text("fromMonth") < $1.text("fromMonth") }.map(JSONValue.object))
                }
            } else if method == "stopFinancePlan" {
                if plan.text("kind") == "advance" {
                    guard plan.text("beneficiaryMonth") >= String(today.prefix(7)) else { throw Message(text: "Non puoi cancellare il recupero di un anticipo già usato in un mese chiuso.") }
                    plan["status"] = .string("cancelled")
                } else { plan["status"] = .string("stopped"); plan["stopAfter"] = .string(String(today.prefix(7))) }
            } else if method == "recordFinancePlanPayment" {
                guard let kind = NativePlanKind(rawValue: plan.text("kind")), kind.payable else { throw Message(text: "Questo piano non prevede un nuovo pagamento.") }
                let amount = payload.integer("amountCents"), day = payload.text("date"), cycle = payload.text("cycleMonth", fallback: String(day.prefix(7)))
                guard amount > 0, amount <= 100_000_000, day <= today, CivilDate.day(CivilDate.date(day)) == day else { throw Message(text: "Importo o data non validi.") }
                let bill = NativeUtilityPeriodDraft(record: payload)
                if bill.enabled && bill.months == nil { throw Message(text: "Periodo della bolletta non valido.") }
                let settlement = kind == .goal ? "once" : kind == .estimated && bill.enabled ? id : [.fixed, .estimated].contains(kind) ? NativePlanRules.cycleKey(plan, month: cycle) : id
                guard !payments.contains(where: { $0.text("planId") == plan.text("id") && $0.text("settlementKey") == settlement }) else { throw Message(text: "Pagamento già registrato.") }
                if [.fixed, .estimated].contains(kind) {
                    guard NativePlanRules.validMonth(cycle), cycle <= String(today.prefix(7)), cycle >= plan.text("startMonth") || kind == .estimated && bill.enabled else { throw Message(text: "Scadenza non valida.") }
                }
                let covered = bill.months?.count ?? (payload.integer("competenceMonths") == 0 ? 1 : payload.integer("competenceMonths"))
                guard (1...12).contains(covered) else { throw Message(text: "Mesi coperti non validi.") }
                if payload.flag("recoverDifference") {
                    guard kind == .goal, amount > plan.integer("amountCents") else { throw Message(text: "Nessuna eccedenza da recuperare.") }
                    var draft = NativePlanDraft(); draft.kind = .goal; draft.name = "Recupero eccedenza · " + plan.text("name"); draft.amount = String(format: "%.2f", Double(amount - plan.integer("amountCents")) / 100)
                    draft.startMonth = payload.text("recoveryStartMonth"); draft.endMonth = payload.text("recoveryEndMonth")
                    var recovery = try draft.payload(requestID: id + "-difference", today: today)
                    recovery["id"] = .string(id + "-difference"); recovery["kind"] = .string("recovery"); recovery["status"] = .string("active")
                    plans.append(recovery)
                }
                let row = try recordCash(name: plan.text("name"), category: plan.text("category", fallback: "Altro"), cents: amount, day: day, requestID: id, existing: payload.integer("movementId"), state: &next)
                payments.append(["id": .string(id), "planId": plan["id"]!, "date": .string(day), "amountCents": .int(amount), "status": .string("posted"), "movementId": .int(row), "settlementKey": .string(settlement), "competenceMonths": .int(covered)])
                if bill.enabled {
                    payments[payments.count - 1]["utilityPeriod"] = .object(["start": .string(bill.start), "end": .string(bill.end)])
                    next.finance["utilityCompetenceEnabled"] = .bool(true)
                }
                if kind == .goal { plan["status"] = .string("closed"); plan["closedMonth"] = .string(String(today.prefix(7))) }
                if kind == .estimated {
                    let history = payments.filter { $0.text("planId") == plan.text("id") }.sorted { $0.text("date") < $1.text("date") }.suffix(12)
                    let total = history.reduce(0) { $0 + $1.integer("amountCents") }, months = history.reduce(0) { $0 + max(1, $1.integer("competenceMonths")) }
                    let from = NativePlanRules.adding(1, to: String(today.prefix(7)))
                    var changes = plan.records("rateChanges").filter { $0.text("fromMonth") != from }
                    changes.append(["fromMonth": .string(from), "amountCents": .int(max(1, Int((Double(total) / Double(months)).rounded())))])
                    plan["rateChanges"] = .array(changes.map(JSONValue.object))
                }
            } else { throw Message(text: "Operazione non disponibile nella demo.") }
            plans[index] = plan
        }
        commands[id] = .string(method + fingerprint)
        data["plans"] = .array(plans.map(JSONValue.object)); data["payments"] = .array(payments.map(JSONValue.object)); data["commands"] = .object(commands)
        next.finance["plansV2"] = .object(data); project(month: next.financeMonth, state: &next, today: today); state = next
    }
    private static func recordCash(name: String, category: String, cents: Int, day: String, requestID: String, existing: Int = 0, state: inout NativeArchive) throws -> Int {
        if existing > 0 {
            guard let movement = state.finance.records("transactions").first(where: { $0.integer("row") == existing }), Int((-movement.amount("amount") * 100).rounded()) == cents, movement.text("date") == day else { throw Message(text: "Movimento non compatibile con importo e data.") }
            return existing
        }
        try DemoActions.apply("saveTransaction", ["requestId": .string(requestID), "name": .string(name), "amount": .number(Double(cents) / 100), "date": .string(day), "account": .string("Trade Republic"), "category": .string(category), "type": .string("Spesa"), "budgetTreatment": .string("savings")], args: nil, state: &state)
        return state.finance.records("transactions").last!.integer("row")
    }
    static func project(month: String, state: inout NativeArchive, today: String = CivilDate.day()) {
        var data = state.finance.record("plansV2"), plans = data.records("plans")
        let payments = data.records("payments"), current = String(today.prefix(7))
        func fund(_ plan: Record, through end: String) -> (Int, Int, Int) {
            let start = plan.text("startMonth")
            guard NativePlanRules.validMonth(start), start <= end else { return (0, 0, 0) }
            // Continuous funds do not inherit the finite-goal month-count limit.
            var cursor = start, saved = 0
            while cursor <= end { saved += max(0, NativePlanRules.contribution(plan, month: cursor)); cursor = NativePlanRules.adding(1, to: cursor) }
            let spent = payments.filter { $0.text("planId") == plan.text("id") && String($0.text("date").prefix(7)) <= end }.reduce(0) { $0 + $1.integer("amountCents") }
            let earmarked = plan.text("status") == "active" && !["advance", "recovery"].contains(plan.text("kind")) ? max(0, saved - spent) : 0
            return (earmarked, saved, spent)
        }
        let adjustment = -plans.filter { !state.finance.flag("utilityCompetenceEnabled") || $0.text("kind") != "estimated" }.reduce(0) { $0 + NativePlanRules.contribution($1, month: month) }
        let currentEarmarked = plans.reduce(0) { $0 + fund($1, through: current).0 }
        var summary = state.finance.record("summary")
        let previous = data.integer("demoAppliedAdjustmentCents"), previousReserved = data.integer("demoAppliedReservedCents")
        summary["monthlyRemaining"] = .number(summary.amount("monthlyRemaining") + Double(adjustment - previous) / 100)
        summary["monthlyCommitted"] = .number(summary.amount("monthlyCommitted") - Double(adjustment - previous) / 100)
        summary["committedCurrent"] = .number(summary.amount("committedCurrent") + Double(currentEarmarked - previousReserved) / 100)
        summary["remainingFree"] = .number(summary.amount("budget") - summary.amount("committedCurrent"))
        for index in plans.indices {
            let values = fund(plans[index], through: month)
            plans[index]["contributionCents"] = .int(NativePlanRules.contribution(plans[index], month: month))
            plans[index]["fundCents"] = .int(values.0); plans[index]["contributedCents"] = .int(values.1); plans[index]["paidCents"] = .int(values.2)
            plans[index]["outstandingCents"] = .int(max(0, plans[index].integer("amountCents") - payments.filter { $0.text("planId") == plans[index].text("id") }.reduce(0) { $0 + $1.integer("amountCents") }))
            plans[index]["fromGeneralSavingsCents"] = .int(max(0, values.2 - values.1))
        }
        data["version"] = .int(2); data["month"] = .string(month); data["adjustmentCents"] = .int(adjustment); data["plans"] = .array(plans.map(JSONValue.object)); data["payments"] = .array(payments.map(JSONValue.object))
        data["demoAppliedAdjustmentCents"] = .int(adjustment); data["demoAppliedReservedCents"] = .int(currentEarmarked)
        state.finance["summary"] = .object(summary); state.finance["plansV2"] = .object(data)
        NativeUtilityDemo.project(month: month, state: &state)
    }
}
