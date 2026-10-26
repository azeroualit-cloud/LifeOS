import Foundation

enum DemoData {
    static func emptyLife() -> Record {
        ["tasks": .array([]), "categories": .array([.object(["key": .string("action"), "label": .string("Attività"), "position": .int(0)])]),
         "events": .array([]), "shifts": .array([]), "routines": .array([]), "today": .string(CivilDate.day())]
    }
    static func make() -> NativeArchive {
        let today = CivilDate.day(), month = CivilDate.month()
        let categories = ["Attività", "Desideri", "Giochi", "Letture"].enumerated().map { i, name in
            JSONValue.object(["key": .string(["action", "wish", "games", "reading"][i]), "label": .string(name), "position": .int(i)])
        }
        let tasks: [JSONValue] = ["Organizzare la settimana", "Prenotare il controllo auto", "Finire il libro"].enumerated().map { i, title in
            .object(["id": .int(i + 1), "title": .string(title), "list_kind": .string(i == 2 ? "reading" : "action"),
                     "notes": .string("Esempio modificabile nella demo."), "status": .string("todo"), "sort_order": .int(i + 1)])
        }
        let routines = ["Leggere", "Camminare"].enumerated().map { i, title in
            JSONValue.object(["id": .int(i + 1), "title": .string(title), "position": .int(i), "checked": .int(0)])
        }
        let life: Record = ["categories": .array(categories), "tasks": .array(tasks), "routines": .array(routines),
            "shifts": .array([.object(["day": .string(today), "kind": .string("morning")]), .object(["day": .string(CivilDate.adding(1, to: today)), "kind": .string("rest")])]),
            "events": .array([.object(["id": .int(1), "title": .string("Allenamento"), "day": .string(CivilDate.adding(1, to: today)), "start_time": .string("18:00"), "end_time": .string("19:00"), "frequency": .string("weekly"), "location": .string("Palestra"), "notes": .string("")])]),
            "occurrences": .object([:]), "today": .string(today), "month": .string(month)]
        let summary: Record = ["budget": .number(1000), "committedCurrent": .number(200), "remainingFree": .number(800),
            "account": .string("Trade Republic"), "revolutBalance": .number(0), "monthlySalary": .number(1800),
            "monthlyCommitted": .number(850), "monthlySpent": .number(112.34), "monthlyRemaining": .number(837.66),
            "monthlyBudgetBreakdown": .array([.object(["name": .string("Affitto"), "amount": .number(550)]), .object(["name": .string("Bollette e abbonamenti"), "amount": .number(100)]), .object(["name": .string("Accantonamenti"), "amount": .number(200)])])]
        let movements: [JSONValue] = [.object(["row": .int(2), "date": .string(today), "name": .string("Spesa alimentare"), "amount": .number(-12.34), "account": .string("Trade Republic"), "category": .string("Alimentari"), "type": .string("Spesa")]),
            .object(["row": .int(3), "date": .string(CivilDate.adding(-1, to: today)), "name": .string("Stipendio demo"), "amount": .number(1800), "account": .string("Trade Republic"), "category": .string("Stipendio"), "type": .string("Entrata")])]
        let yearly = (1...12).map { i in JSONValue.object(["month": .string(String(month.prefix(4)) + String(format: "-%02d", i)), "income": .number(1800), "spent": .number(Double(700 + i * 23)), "commitments": .number(850)]) }
        let recurring = ["Elettricità", "Gas", "Acqua", "Condominio", "Palestra", "Abbonamenti", "Benzina"].enumerated().map { i, name in
            JSONValue.object(["name": .string(name), "estimate": .number([44, 30, 20, 25, 33, 13, 66][i]), "treatment": .string(i == 6 ? "Flessibile" : "Vincolata")])
        }
        let observed: [JSONValue] = (1...6).reversed().map { offset in
            let m = String(CivilDate.adding(-offset, to: month + "-01", component: .month).prefix(7))
            return .object(["month": .string(m), "observed": .bool(true), "ordinaryNet": .number(Double(80 + offset * 15))])
        }
        let historical: [JSONValue] = observed.enumerated().map { index, value in
            var row = value.object; row["wealth"] = .number(Double(200 + index * 130)); return .object(row)
        }
        let finance: Record = ["summary": .object(summary), "transactions": .array(movements), "recurring": .array(recurring), "yearly": .array(yearly),
            "categories": .array([.object(["name": .string("Alimentari"), "amount": .number(12.34)])]),
            "planning": .object(["goal": .number(3000), "monthlySaving": .number(150), "projection": .number(1450), "now": .number(1000)]), "forecastHistory": .array(observed), "lifetime": .object(["series": .array(historical)]), "history": .array([])]
        let allocation: Record = ["cycle_id": .int(1), "extraordinary_source_row": .int(2), "month": .string(month), "name": .string("Manutenzione auto"),
            "start_month": .string(month), "end_month": .string(String(CivilDate.adding(11, to: month + "-01", component: .month).prefix(7))), "amount_cents": .int(5000), "total_cents": .int(60000), "kind": .string("expense"), "status": .string("Programmato"), "payment_account": .string("Trade Republic"), "repeat": .string("Annuale")]
        return NativeArchive(life: life, finance: finance, plan: ["allocations": .array([.object(allocation)]), "links": .array([])], demo: true, refreshedAt: Date(), routineDay: today)
    }
}

enum DemoActions {
    static func apply(_ method: String, _ payload: Record, args: [JSONValue]?, state: inout NativeArchive) throws {
        let id = payload.integer("id")
        let scalar = args?.first?.number ?? Double(id)
        func nextID(_ rows: [Record], _ key: String = "id") -> Int { (rows.map { $0.integer(key) }.max() ?? 0) + 1 }
        func checkedTitle(_ key: String = "title") throws -> String {
            let title = payload.text(key).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw Message(text: "Inserisci un nome.") }; return title
        }
        func replace(_ key: String, _ rows: [Record]) { state.life[key] = .array(rows.map(JSONValue.object)) }
        switch method {
        case "saveHealthEntry":
            let checked = try HealthMeasurement.payload(day: payload.text("day"), weight: payload["weightKg"].map { String($0.number) } ?? "", calories: payload["calories"].map { String($0.number) } ?? "")
            var rows = state.life.records("health")
            let day = checked.text("day"), index = rows.firstIndex { $0.text("day") == day }
            var row = index.map { rows[$0] } ?? ["day": .string(day)]
            if let value = checked["weightKg"] { row["weight_kg"] = value }
            if let value = checked["calories"] { row["calories"] = value }
            if let index { rows[index] = row } else { rows.append(row) }
            replace("health", rows.sorted { $0.text("day") < $1.text("day") })
        case "saveFinancePlan", "recordFinancePlanPayment", "stopFinancePlan", "editFinancePlan", "deleteFinancePlanPayment":
            try NativePlanDemo.apply(method, payload: payload, state: &state)
        case "saveTask":
            var rows = state.life.records("tasks"), p = payload
            p["title"] = .string(try checkedTitle())
            if let index = rows.firstIndex(where: { $0.integer("id") == id }) {
                p["section_status"] = rows[index]["section_status"]; p["completed_at"] = rows[index]["completed_at"]; p["status"] = rows[index]["status"]; p["sort_order"] = rows[index]["sort_order"]; rows[index] = p
            } else { p["id"] = .int(nextID(rows)); p["status"] = .string("todo"); p["sort_order"] = .int(nextID(rows, "sort_order")); rows.append(p) }
            replace("tasks", rows)
        case "setTaskStatus":
            var rows = state.life.records("tasks")
            if let index = rows.firstIndex(where: { $0.integer("id") == id }) {
                let status = payload.text("status")
                guard ["todo", "waiting", "done"].contains(status) else { throw Message(text: "Stato non valido.") }
                rows[index]["section_status"] = .string(status == "done" ? NativeTaskList.section(rows[index]) : status)
                rows[index]["status"] = .string(status)
                rows[index]["completed_at"] = status == "done" ? .string(CivilDate.day()) : .null
            }
            replace("tasks", rows)
        case "deleteTask": replace("tasks", state.life.records("tasks").filter { $0.integer("id") != Int(scalar) })
        case "deleteCompletedTasks":
            let category = payload.text("category")
            replace("tasks", state.life.records("tasks").filter { !($0.text("list_kind") == category && $0.text("status") == "done") })
        case "reorderTasks":
            let ids = payload["ids"]?.array.map { Int($0.number) } ?? []
            var rows = state.life.records("tasks")
            for index in rows.indices { if let pos = ids.firstIndex(of: rows[index].integer("id")) { rows[index]["sort_order"] = .int(pos + 1) } }
            replace("tasks", rows)
        case "addCategory", "renameCategory":
            let label = try checkedTitle("label"); var rows = state.life.records("categories")
            if method == "addCategory" {
                guard !rows.contains(where: { $0.text("label").lowercased() == label.lowercased() }) else { throw Message(text: "La categoria esiste già.") }
                rows.append(["key": .string("custom-" + UUID().uuidString), "label": .string(label), "position": .int(rows.count)])
            } else if let i = rows.firstIndex(where: { $0.text("key") == payload.text("key") }) { rows[i]["label"] = .string(label) }
            replace("categories", rows)
        case "reorderCategories":
            let keys = payload["keys"]?.array.map(\.string) ?? []; var rows = state.life.records("categories")
            for i in rows.indices { if let pos = keys.firstIndex(of: rows[i].text("key")) { rows[i]["position"] = .int(pos) } }
            replace("categories", rows)
        case "deleteCategory":
            let key = payload.text("key"), destination = payload.text("destination")
            guard key != destination, state.life.records("categories").contains(where: { $0.text("key") == destination }) else { throw Message(text: "Scegli dove spostare le attività.") }
            replace("categories", state.life.records("categories").filter { $0.text("key") != key })
            replace("tasks", state.life.records("tasks").map { r in var next = r; if r.text("list_kind") == key { next["list_kind"] = .string(destination) }; return next })
        case "saveRoutine":
            var rows = state.life.records("routines"), p = payload; p["title"] = .string(try checkedTitle())
            if let schedule = p["schedule"] { p["schedule"] = try NativeRoutineSchedule(schedule).value }
            if let i = rows.firstIndex(where: { $0.integer("id") == id }) { rows[i]["title"] = p["title"]; if let schedule = p["schedule"] { rows[i]["schedule"] = schedule } }
            else {
                guard rows.count < 100 else { throw Message(text: "Massimo 100 abitudini.") }
                p["id"] = .int(nextID(rows)); p["checked"] = .int(0); p["position"] = .int(rows.count); rows.append(p)
            }
            replace("routines", rows)
        case "deleteRoutine": replace("routines", state.life.records("routines").filter { $0.integer("id") != Int(scalar) })
        case "setRoutineCheck":
            guard payload.text("day") == CivilDate.day() else { throw Message(text: "È iniziato un nuovo giorno. Aggiorna le routine.") }
            var rows = state.life.records("routines")
            guard let i = rows.firstIndex(where: { $0.integer("id") == id }) else { throw Message(text: "Abitudine non trovata.") }
            guard !payload.flag("checked") || NativeRoutineSchedule.due(rows[i]) else { throw Message(text: "Questa abitudine non è prevista per oggi.") }
            rows[i]["checked"] = .int(payload.flag("checked") ? 1 : 0)
            replace("routines", rows)
        case "paintShift":
            var rows = state.life.records("shifts").filter { $0.text("day") != payload.text("day") }
            if payload.text("kind") != "erase" { rows.append(payload) }; replace("shifts", rows)
        case "saveEvent", "splitEventSeries":
            var rows = state.life.records("events"), p = payload; p["title"] = .string(try checkedTitle())
            if method == "splitEventSeries" {
                guard let i = rows.firstIndex(where: { $0.integer("id") == id }) else { throw Message(text: "Serie non trovata.") }
                let from = payload.text("split_from")
                let future = state.life.record("occurrences").keys.contains { $0.hasPrefix("\(id):") && String($0.suffix(10)) >= from }
                guard !future else { throw Message(text: "Riapri prima le occorrenze future già segnate.") }
                rows[i]["until_day"] = .string(CivilDate.adding(-1, to: from)); p["id"] = .int(nextID(rows)); rows.append(p)
            } else if let i = rows.firstIndex(where: { $0.integer("id") == id }) {
                if (rows[i].text("day") != p.text("day") || rows[i].text("frequency") != p.text("frequency")) && (rows[i].text("frequency", fallback: "none") != "none" || p.text("frequency", fallback: "none") != "none") {
                    guard !state.life.record("occurrences").keys.contains(where: { $0.hasPrefix("\(id):") }) else { throw Message(text: "Usa Modifica da qui per preservare le occorrenze segnate.") }
                }
                rows[i] = p
            } else { p["id"] = .int(nextID(rows)); rows.append(p) }; replace("events", rows)
        case "setEventOccurrence":
            var statuses = state.life.record("occurrences"); let key = "\(id):\(payload.text("day"))"
            if payload.text("status") == "open" { statuses.removeValue(forKey: key) } else { statuses[key] = payload["status"] }
            state.life["occurrences"] = .object(statuses)
        case "deleteEvent":
            replace("events", state.life.records("events").filter { $0.integer("id") != Int(scalar) })
            state.life["occurrences"] = .object(state.life.record("occurrences").filter { !$0.key.hasPrefix("\(Int(scalar)):") })
        case "saveTransaction", "saveRecurringPayment", "editMovement":
            if method == "editMovement", state.finance.record("plansV2").records("payments").contains(where: { $0.integer("movementId") == payload.integer("row") }) { throw Message(text: "Gestisci il pagamento dal piano collegato.") }
            var rows = state.finance.records("transactions"), p = payload
            if method != "editMovement", !payload.text("requestId").isEmpty,
               rows.contains(where: { $0.text("requestId") == payload.text("requestId") }) { return }
            let amount = payload.amount("amount"), type = payload.text("type", fallback: "Spesa")
            guard amount > 0, amount.isFinite, !payload.text("name").isEmpty, payload.text("date") <= CivilDate.day() else { throw Message(text: "Controlla importo, descrizione e data.") }
            let oldRow = rows.first { $0.integer("row") == payload.integer("row") }
            let signed = (type == "Trasferimento" && method == "editMovement" && (oldRow?.amount("amount") ?? 0) > 0) ? amount : ["Spesa", "Trasferimento"].contains(type) ? -amount : amount
            p["amount"] = .number(signed); p["account"] = .string(payload.text("account", fallback: "Trade Republic"))
            var previous: Record?
            if method == "editMovement", let i = rows.firstIndex(where: { $0.integer("row") == payload.integer("row") }) {
                previous = rows[i]
                let transfer = rows[i].text("transfer_id")
                if !transfer.isEmpty {
                    guard type == "Trasferimento", let pairIndex = rows.firstIndex(where: { $0.text("transfer_id") == transfer && $0.integer("row") != payload.integer("row") }), accountDifferent(payload) else { throw Message(text: "Mantieni entrambi i conti e il tipo del trasferimento.") }
                    let oldPair = rows[pairIndex]; var pair = oldPair
                    p["transfer_id"] = .string(transfer); pair["amount"] = .number(-signed); pair["account"] = payload["counterpart"]; pair["counterpart"] = payload["account"]; pair["date"] = payload["date"]
                    rows[pairIndex] = pair; adjustDemoMoney(new: pair, old: oldPair, state: &state)
                }
                rows[i] = p
            } else {
                p["row"] = .int(max(2, nextID(rows, "row")))
                if type == "Trasferimento" {
                    guard accountDifferent(payload) else { throw Message(text: "Scegli due conti diversi.") }
                    let transfer = UUID().uuidString; p["transfer_id"] = .string(transfer)
                    var pair = p; pair["row"] = .int(p.integer("row") + 1); pair["account"] = payload["counterpart"]; pair["counterpart"] = payload["account"]; pair["amount"] = .number(amount); pair["name"] = .string("Trasferimento da " + p.text("account"))
                    rows.append(p); rows.append(pair); adjustDemoMoney(new: pair, old: nil, state: &state)
                } else { rows.append(p) }
            }
            state.finance["transactions"] = .array(rows.map(JSONValue.object)); adjustDemoMoney(new: p, old: previous, state: &state)
        case "deleteMovement":
            if state.finance.record("plansV2").records("payments").contains(where: { $0.integer("movementId") == Int(scalar) }) { throw Message(text: "Gestisci il pagamento dal piano collegato.") }
            let rows = state.finance.records("transactions"), old = rows.first { $0.integer("row") == Int(scalar) }
            let transfer = old?.text("transfer_id") ?? ""
            let removed = rows.filter { $0.integer("row") == Int(scalar) || (!transfer.isEmpty && $0.text("transfer_id") == transfer) }
            state.finance["transactions"] = .array(rows.filter { row in !removed.contains { $0.integer("row") == row.integer("row") } }.map(JSONValue.object))
            for row in removed { adjustDemoMoney(new: nil, old: row, state: &state) }
            let ids = removed.map { $0.integer("row") }
            state.plan["settlements"] = .array(state.plan.records("settlements").filter { !ids.contains($0.integer("movement_source_row")) }.map(JSONValue.object))
            let links = state.plan.records("links"), affected = Set(links.filter { ids.contains($0.integer("movement_source_row")) }.map { $0.integer("cycle_id") })
            state.plan["links"] = .array(links.filter { !ids.contains($0.integer("movement_source_row")) }.map(JSONValue.object))
            state.plan["allocations"] = .array(state.plan.records("allocations").map { r in var p = r; if affected.contains(r.integer("cycle_id")) && r.text("status") == "Pagato" { p["status"] = .string("Da riconciliare") }; return .object(p) })
        case "saveExtra", "updateExtraPlan":
            if method == "saveExtra", !payload.text("requestId").isEmpty,
               state.plan.records("allocations").contains(where: { $0.text("requestId") == payload.text("requestId") }) { return }
            let amount = payload.amount("amount"), start = payload.text("month"), end = payload.text("endMonth")
            let startParts = start.split(separator: "-").compactMap { Int($0) }, endParts = end.split(separator: "-").compactMap { Int($0) }
            guard startParts.count == 2, endParts.count == 2, amount > 0 else { throw Message(text: "Controlla importo e periodo.") }
            let months = (endParts[0] - startParts[0]) * 12 + endParts[1] - startParts[1] + 1
            let shares = NativeValidation.shares(cents: Int((amount * 100).rounded()), months: months)
            guard !shares.isEmpty else { throw Message(text: "Scegli da uno a sessanta mesi.") }
            var rows = state.plan.records("allocations")
            let cycle = method == "updateExtraPlan" ? payload.integer("cycleId") : nextID(rows, "cycle_id")
            let linked = state.plan.records("links").filter { $0.integer("cycle_id") == cycle }.reduce(0) { $0 + $1.integer("attributed_cents") }
            guard Int((amount * 100).rounded()) >= linked else { throw Message(text: "Il piano non può scendere sotto quanto già attribuito.") }
            let previousStatus = rows.first { $0.integer("cycle_id") == cycle }?.text("status")
            rows.removeAll { $0.integer("cycle_id") == cycle }
            for (i, share) in shares.enumerated() {
                rows.append(["requestId": payload["requestId"] ?? .string(""), "cycle_id": .int(cycle), "extraordinary_source_row": .int(cycle + 1), "month": .string(String(CivilDate.adding(i, to: start + "-01", component: .month).prefix(7))),
                    "start_month": .string(start), "end_month": .string(end), "name": .string(try checkedTitle("name")), "total_cents": .int(Int((amount * 100).rounded())),
                    "amount_cents": .int(share), "kind": .string("expense"), "status": .string(previousStatus ?? payload.text("status", fallback: "Programmato")), "payment_account": .string("Trade Republic"), "repeat": payload["repeat"] ?? .string("No")])
            }
            state.plan["allocations"] = .array(rows.map(JSONValue.object))
        case "recordExtraPayment", "markExtraPaid", "cancelExtraCycle", "deleteExtraPlan":
            let cycle = payload.integer("cycleId"); var rows = state.plan.records("allocations")
            if method == "deleteExtraPlan" {
                guard !state.plan.records("links").contains(where: { $0.integer("cycle_id") == cycle }), rows.first(where: { $0.integer("cycle_id") == cycle })?.text("status") == "Annullato" else { throw Message(text: "Annulla prima il piano e conserva i pagamenti collegati.") }
                rows.removeAll { $0.integer("cycle_id") == cycle }
            }
            else {
                guard let first = rows.first(where: { $0.integer("cycle_id") == cycle }) else { throw Message(text: "Piano non trovato.") }
                let status = method == "cancelExtraCycle" ? "Annullato" : "Pagato"
                if method == "recordExtraPayment" && first.text("status") != "Pagato" {
                    var transaction = payload; transaction["type"] = .string("Spesa"); transaction["category"] = .string("Straordinarie"); transaction["budgetTreatment"] = .string("savings")
                    try apply("saveTransaction", transaction, args: nil, state: &state)
                    if let movement = state.finance.records("transactions").last {
                        var settlements = state.plan.records("settlements").filter { $0.integer("cycle_id") != cycle }
                        settlements.append(["cycle_id": .int(cycle), "movement_source_row": movement["row"]!, "actual_cents": .int(Int((payload.amount("amount") * 100).rounded())), "planned_cents": first["total_cents"] ?? .int(0)])
                        state.plan["settlements"] = .array(settlements.map(JSONValue.object))
                        var links = state.plan.records("links")
                        links.append(["cycle_id": .int(cycle), "movement_source_row": movement["row"]!, "attributed_cents": .int(min(Int((payload.amount("amount") * 100).rounded()), first.integer("total_cents"))), "role": .string("payment")])
                        state.plan["links"] = .array(links.map(JSONValue.object))
                    }
                }
                for i in rows.indices where rows[i].integer("cycle_id") == cycle { rows[i]["status"] = .string(status) }
            }; state.plan["allocations"] = .array(rows.map(JSONValue.object))
        case "linkExtraMovement", "unlinkExtraMovement":
            let cycle = payload.integer("cycleId"), movement = payload.integer("movementId")
            var links = state.plan.records("links"), rows = state.plan.records("allocations")
            guard let plan = rows.first(where: { $0.integer("cycle_id") == cycle }) else { throw Message(text: "Piano non trovato.") }
            if method == "linkExtraMovement" {
                guard let transaction = state.finance.records("transactions").first(where: { $0.integer("row") == movement }), transaction.amount("amount") < 0,
                      transaction.text("budgetTreatment") != "recovery", !["Pagato", "Annullato"].contains(plan.text("status")) else { throw Message(text: "Movimento non compatibile con il piano.") }
                let cents = Int((payload.amount("amount") * 100).rounded())
                let attributed = links.filter { $0.integer("movement_source_row") == movement }.reduce(0) { $0 + $1.integer("attributed_cents") }
                let paid = links.filter { $0.integer("cycle_id") == cycle }.reduce(0) { $0 + $1.integer("attributed_cents") }
                guard cents > 0, cents + attributed <= Int((-transaction.amount("amount") * 100).rounded()), cents + paid <= plan.integer("total_cents"), !links.contains(where: { $0.integer("cycle_id") == cycle && $0.integer("movement_source_row") == movement }) else { throw Message(text: "Importo già attribuito o superiore al residuo.") }
                links.append(["cycle_id": .int(cycle), "movement_source_row": .int(movement), "attributed_cents": .int(cents), "role": .string("payment")])
            } else { links.removeAll { $0.integer("cycle_id") == cycle && $0.integer("movement_source_row") == movement } }
            let paid = links.filter { $0.integer("cycle_id") == cycle }.reduce(0) { $0 + $1.integer("attributed_cents") }
            for i in rows.indices where rows[i].integer("cycle_id") == cycle {
                if paid >= plan.integer("total_cents") { rows[i]["status"] = .string("Pagato") }
                else if ["Pagato", "Da riconciliare"].contains(rows[i].text("status")) { rows[i]["status"] = .string("Da riconciliare") }
            }
            state.plan["links"] = .array(links.map(JSONValue.object)); state.plan["allocations"] = .array(rows.map(JSONValue.object))
        case "saveEstimate":
            guard let args, args.count == 2 else { throw Message(text: "Stima non valida.") }
            var rows = state.finance.records("recurring")
            if let i = rows.firstIndex(where: { $0.text("name") == args[0].string }) { rows[i]["estimate"] = args[1] }
            state.finance["recurring"] = .array(rows.map(JSONValue.object))
        case "savePlanningSettings":
            guard let args, args.count >= 2 else { throw Message(text: "Impostazioni non valide.") }
            var p = state.finance.record("planning"); p["goal"] = args[0]; p["monthlySaving"] = args[1]; if args.count > 2 { p["savingsTarget"] = args[2] }
            state.finance["planning"] = .object(p)
        default: throw Message(text: "Questa azione richiede la copia di test collegata.")
        }
    }
    private static func adjustDemoMoney(new: Record?, old: Record?, state: inout NativeArchive) {
        func cents(_ r: Record?) -> Int { Int(((r?.amount("amount") ?? 0) * 100).rounded()) }
        var s = state.finance.record("summary")
        func contribution(_ r: Record?, _ account: String) -> Int { r?.text("account") == account ? cents(r) : 0 }
        let delta = contribution(new, "Trade Republic") - contribution(old, "Trade Republic")
        s["budget"] = .number(Double(Int((s.amount("budget") * 100).rounded()) + delta) / 100)
        s["remainingFree"] = .number(s.amount("budget") - s.amount("committedCurrent"))
        s["revolutBalance"] = .number(Double(Int((s.amount("revolutBalance") * 100).rounded()) + contribution(new, "Revolut") - contribution(old, "Revolut")) / 100)
        func discretionary(_ r: Record?) -> Int {
            guard let r, !["planned", "savings", "recovery"].contains(r.text("budgetTreatment")), ["Spesa", "Rimborso"].contains(r.text("type")), r.text("date").hasPrefix(CivilDate.month()) else { return 0 }
            return -cents(r)
        }
        let spentDelta = Double(discretionary(new) - discretionary(old)) / 100
        s["monthlySpent"] = .number(s.amount("monthlySpent") + spentDelta)
        s["monthlyRemaining"] = .number(s.amount("monthlyRemaining") - spentDelta)
        state.finance["summary"] = .object(s)
    }
    private static func accountDifferent(_ payload: Record) -> Bool {
        let a = payload.text("account"), b = payload.text("counterpart")
        return ["Revolut", "Trade Republic", "IsyBank"].contains(a) && ["Revolut", "Trade Republic", "IsyBank"].contains(b) && a != b
    }
}
