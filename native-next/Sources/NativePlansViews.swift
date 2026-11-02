import SwiftUI

struct NativeMonthPicker: View {
    let title: String
    @Binding var selection: String
    private var month: Binding<Int> { Binding(get: { Int(selection.suffix(2)) ?? 1 }, set: { selection = String(selection.prefix(4)) + String(format: "-%02d", $0) }) }
    private var year: Binding<Int> { Binding(get: { Int(selection.prefix(4)) ?? 2026 }, set: { selection = String($0) + "-" + String(selection.suffix(2)) }) }
    private var years: ClosedRange<Int> {
        let current = Int(CivilDate.month().prefix(4))!, selected = Int(selection.prefix(4)) ?? current
        return min(current, selected)...min(2099, max(current + 20, selected))
    }
    var body: some View {
        HStack {
            Text(title).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: NativeDesign.Space.small)
            Picker("Mese · " + title, selection: month) {
                ForEach(1...12, id: \.self) { value in Text(CivilDate.monthTitle(String(format: "2026-%02d", value)).components(separatedBy: " ")[0]).tag(value) }
            }.labelsHidden().pickerStyle(.menu)
            Picker("Anno · " + title, selection: year) { ForEach(Array(years), id: \.self) { Text(String($0)).tag($0) } }.labelsHidden().pickerStyle(.menu)
        }
    }
}
struct NativePlansScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @AppStorage("native-hide-money") private var hidden = false
    @State private var info = false
    private var plans: [Record] { store.finance.record("plansV2").records("plans") }
    private var flow: NativeBudgetFlow { NativeBudgetFlow(summary: store.summary, plans: plans, month: store.financeMonth) }
    private func money(_ cents: Int) -> String { hidden ? "•••• €" : (Double(cents) / 100).euro }
    var body: some View {
        List {
            Section {
                MonthControl(finance: true)
                Text("Stipendio, piani e budget disponibile").font(.caption).foregroundStyle(NativeDesign.secondary)
                if store.plansBusy { ProgressView("Aggiorno i piani…") }
                if let error = store.plansError {
                    NativeInlineMessage(text: error)
                    if let server = store.server { Text(server.host ?? "").font(.caption).foregroundStyle(NativeDesign.secondary) }
                    Button("Riprova") { Task { await store.loadFinancePlans() } }
                }
                if store.isDemo { Text("Piani demo · nessuna modifica al server").font(.caption).foregroundStyle(NativeDesign.secondary) }
            }
            Section("Budget del mese") {
                LabeledContent("Stipendio di riferimento", value: money(flow.salaryCents)).accessibilityIdentifier("budget-salary-reference")
                if flow.rows.isEmpty { Text("Nessun piano per questo mese. Aggiungi un piano per destinare una quota dello stipendio.").foregroundStyle(NativeDesign.secondary) }
                ForEach(flow.rows) { row in
                    if let id = row.planID {
                        NavigationLink { NativePlanDetail(planID: id) } label: { budgetRow(row) }.accessibilityIdentifier("plan-" + id)
                    } else { budgetRow(row) }
                }
                LabeledContent("Spese non già coperte dai piani", value: money(-flow.spentCents))
                LabeledContent("Budget finale", value: money(flow.remainingCents)).font(.headline).accessibilityIdentifier("budget-final-remaining")
                Text("Le quote dei piani riducono il budget. I pagamenti già coperti da un piano non vengono sottratti una seconda volta.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
            Section {
                DisclosureGroup("Altri piani · futuri e conclusi") {
                    ForEach(plans.filter { !flow.planIDs.contains($0.text("id")) }, id: \.textID) { plan in
                        NavigationLink { NativePlanDetail(planID: plan.text("id")) } label: {
                            NativeRowText(title: plan.text("name"), subtitle: NativePlanRules.stateTitle(plan.text("status")) + " · da " + CivilDate.monthTitle(plan.text("startMonth")))
                        }.accessibilityIdentifier("plan-" + plan.text("id"))
                    }
                }.accessibilityIdentifier("budget-other-plans")
            }
            if !store.allocations.isEmpty {
                Section("Piani precedenti") {
                    Text("Le voci storiche non adottate sono conservate. Non duplicarle con un nuovo piano.").font(.caption).foregroundStyle(NativeDesign.secondary)
                    ForEach(Array(Dictionary(grouping: store.allocations, by: { $0.integer("cycle_id") }).values.compactMap(\.first)).sorted { $0.text("name") < $1.text("name") }.map { DisplayRecord($0, key: "cycle_id") }) { item in
                        Button { router.sheet = .extra(item.value) } label: { NativeRowText(title: item.value.text("name"), subtitle: NativeExtraState.title(item.value.text("status"))) }.buttonStyle(NativePressStyle())
                    }
                }
            }
            NativeSavingsSection()
        }.modifier(NativeListAppearance()).navigationTitle("Budget").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NativeIconButton(symbol: "info.circle", label: "Come funzionano i piani") { info = true }.accessibilityIdentifier("plans-info")
                    NativeIconButton(symbol: "plus", label: "Nuovo piano") { router.sheet = .financePlan }.accessibilityIdentifier("plans-add")
                }
            }
            .sheet(isPresented: $info) { NavigationStack { NativePlansInfo() } }
            .task(id: store.financeGeneration.description + store.financeMonth) { await store.loadFinancePlans() }
            .refreshable { await store.sync(scope: .finance); await store.loadFinancePlans() }
            .onAppear { router.financeSection = "Budget" }
            .onDisappear { router.financeSection = "Panoramica" }
    }
    private func budgetRow(_ row: NativeBudgetFlow.Row) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            LabeledContent(row.name, value: money(-row.amountCents))
            Text("Rimane " + money(row.remainingCents)).font(.caption).foregroundStyle(NativeDesign.secondary).monospacedDigit()
        }.padding(.vertical, NativeDesign.Space.xs)
    }
}
private extension Dictionary where Key == String, Value == JSONValue { var textID: String { text("id") } }

struct NativePlanEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NativePlanDraft()
    @State private var requestID = UUID().uuidString
    @State private var saving = false
    @State private var submitted = false
    @State private var error: String?
    @State private var usesExisting = false
    @State private var movement: Record?
    @FocusState private var editing: Bool
    private var preview: [Record] { (try? draft.preview()) ?? [] }
    private var validationIssue: String? {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !draft.amount.isEmpty else { return nil }
        do { _ = try draft.payload(requestID: requestID); return nil } catch { return error.localizedDescription }
    }
    var body: some View {
        Form {
            Section("Cosa vuoi fare?") {
                Picker("Tipo di piano", selection: $draft.kind) { ForEach(NativePlanKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).accessibilityIdentifier("plan-kind")
                TextField("Nome", text: $draft.name).focused($editing).accessibilityIdentifier("plan-name")
                if draft.kind != .advance {
                    Picker("Categoria della spesa", selection: $draft.category) { ForEach(Input.categories, id: \.self) { Text($0) } }
                }
                TextField(draft.kind == .estimated ? "Accantonamento mensile €" : draft.kind == .fund ? "Quota mensile €" : draft.kind == .fixed ? "Importo per scadenza €" : "Importo totale €", text: $draft.amount).keyboardType(.decimalPad).focused($editing).accessibilityIdentifier("plan-amount").disabled(draft.kind == .recovery && usesExisting)
            }.disabled(submitted)
            Section("Mesi del piano") {
                if draft.kind == .advance { NativeMonthPicker(title: "Mese beneficiario", selection: $draft.beneficiaryMonth) }
                NativeMonthPicker(title: draft.kind == .advance ? "Recupera da" : "Primo mese", selection: $draft.startMonth)
                if draft.kind.finite { NativeMonthPicker(title: "Ultimo mese", selection: $draft.endMonth) }
                else { Text("Senza scadenza · continua finché interrompi il piano").font(.caption).foregroundStyle(NativeDesign.secondary) }
                if draft.kind == .fixed { Stepper("Pagamento ogni \(draft.intervalMonths) mesi", value: $draft.intervalMonths, in: 1...12) }
                if draft.kind == .estimated { Text("La quota verrà aggiornata dai pagamenti e dai mesi coperti, a partire dal mese successivo. Le quote passate restano invariate.").font(.caption).foregroundStyle(NativeDesign.secondary) }
            }.disabled(submitted)
            if draft.kind == .recovery {
                Section("Pagamento già effettuato") {
                    Picker("Movimento bancario", selection: $usesExisting) { Text("Da registrare").tag(false); Text("Già registrato").tag(true) }.pickerStyle(.segmented)
                    if usesExisting { NativePlanMovementPicker(selection: $movement) }
                    else { DatePicker("Giorno del pagamento", selection: paymentDate, in: ...Date(), displayedComponents: .date) }
                    Text(usesExisting ? "Collega il movimento esistente: il saldo non cambia. Sono disponibili le spese dai risparmi e quelle del mese corrente non già collegate." : "Registra una sola spesa dai risparmi e recupera l’importo nei budget scelti.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }.disabled(submitted)
            }
            Section(draft.kind.finite ? "Anteprima budget" : "Anteprima · primi tre mesi") {
                ForEach(Array(preview.enumerated()), id: \.offset) { _, row in
                    LabeledContent(CivilDate.monthTitle(row.text("month")), value: (Double(row.integer("deltaCents")) / 100).euro)
                }
                Text(draft.kind == .recovery ? "Il saldo diminuisce una sola volta, dell’importo pagato. Le quote future modificano solo il budget." : "Queste quote modificano il budget, senza creare un’uscita dal conto.")
                    .font(.caption).foregroundStyle(NativeDesign.secondary)
                if preview.isEmpty { Text(validationIssue ?? "Completa nome, importo e mesi per visualizzare l’anteprima.").foregroundStyle(NativeDesign.secondary) }
            }
            if !store.isDemo && store.finance.record("plansV2").integer("version") != 2 {
                Section { Text("Per salvare serve l’aggiornamento del server al sistema Piani. I dati e i piani precedenti rimangono conservati.").foregroundStyle(NativeDesign.secondary) }
            }
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Nuovo piano").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitted ? "Riprova" : "Salva") { Task { await save() } }.disabled(saving || preview.isEmpty || (draft.kind == .recovery && usesExisting && movement == nil) || store.busy || (!store.isDemo && store.finance.record("plansV2").integer("version") != 2)).accessibilityIdentifier("plan-save")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } }
            }
            .onChange(of: draft.startMonth) { _, value in
                if draft.endMonth < value { draft.endMonth = value }
            }
            .onChange(of: draft.kind) { _, value in
                if value == .advance { draft.startMonth = NativePlanRules.adding(1, to: CivilDate.month()); draft.endMonth = draft.startMonth; draft.beneficiaryMonth = CivilDate.month() }
            }
            .onChange(of: movement) { _, value in
                if let value { draft.amount = String(format: "%.2f", Double(value.integer("amountCents")) / 100); draft.paymentDate = value.text("date") }
            }
            .interactiveDismissDisabled(saving)
    }
    private var paymentDate: Binding<Date> { Binding(get: { CivilDate.date(draft.paymentDate) }, set: { draft.paymentDate = CivilDate.day($0) }) }
    private func save() async {
        saving = true; editing = false; defer { saving = false }
        do {
            var payload = try draft.payload(requestID: requestID)
            if draft.kind == .recovery, usesExisting {
                guard let movement else { throw Message(text: "Scegli il movimento già registrato.") }
                payload["movementId"] = movement["row"]
            }
            submitted = true // Preserve the same operation after a timeout; never create a second payment.
            try await store.perform("saveFinancePlan", payload)
            await store.loadFinancePlans(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct NativePlanDetail: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    let planID: String
    @State private var paying = false
    @State private var editingPlan = false
    @State private var stopping = false
    @State private var working = false
    @State private var error: String?
    @State private var stopID = UUID().uuidString
    private var plan: Record { store.finance.record("plansV2").records("plans").first { $0.text("id") == planID } ?? [:] }
    private var payments: [Record] { store.finance.record("plansV2").records("payments").filter { $0.text("planId") == planID }.sorted { $0.text("date") > $1.text("date") } }
    var body: some View {
        List {
            Section {
                Text(plan.text("name")).font(NativeDesign.heading)
                LabeledContent("Tipo", value: NativePlanKind(rawValue: plan.text("kind"))?.title ?? "Piano")
                LabeledContent("Stato") { Text(NativePlanRules.stateTitle(plan.text("status"))).accessibilityIdentifier("plan-status") }
                LabeledContent("Primo mese", value: CivilDate.monthTitle(plan.text("startMonth")))
                if !plan.text("endMonth").isEmpty { LabeledContent("Ultimo mese", value: CivilDate.monthTitle(plan.text("endMonth"))) }
                else { Text("Senza scadenza").font(.caption).foregroundStyle(NativeDesign.secondary) }
                if plan.text("kind") == "advance" { LabeledContent("Mese beneficiario", value: CivilDate.monthTitle(plan.text("beneficiaryMonth"))) }
                LabeledContent((plan.text("kind") == "estimated" ? "Accantonato in " : "Budget di ") + CivilDate.monthTitle(store.financeMonth), value: (Double(plan.integer("contributionCents")) * (plan.text("kind") == "estimated" ? 1 : -1) / 100).euro)
                if !["advance", "recovery"].contains(plan.text("kind")) {
                    LabeledContent("Disponibile nel fondo", value: (Double(plan.integer("fundCents")) / 100).euro)
                    if plan.integer("fromGeneralSavingsCents") > 0 { LabeledContent("Pagato dagli altri risparmi", value: (Double(plan.integer("fromGeneralSavingsCents")) / 100).euro) }
                }
                if plan.text("status") == "active", plan.text("startMonth") <= CivilDate.month(), NativePlanKind(rawValue: plan.text("kind"))?.payable == true {
                    if NativePlanRules.isPaid(plan, payments: payments, month: store.financeMonth) { Text("Pagamento registrato").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
                    else {
                    Button(plan.text("kind") == "goal" ? "Paga dai risparmi e chiudi il piano" : "Registra un pagamento") { paying = true }
                        .accessibilityIdentifier("plan-record-payment")
                    }
                }
            }
            Section("Pagamenti") {
                if payments.isEmpty { Text("Nessun pagamento registrato").foregroundStyle(NativeDesign.secondary) }
                ForEach(Array(payments.enumerated()), id: \.element.textID) { _, payment in
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        NavigationLink {
                            NativePlanPaymentDetail(planID: planID, paymentID: payment.text("id"))
                        } label: {
                            LabeledContent(CivilDate.label(payment.text("date")), value: (Double(payment.integer("amountCents")) / 100).euro)
                        }.accessibilityIdentifier("plan-payment-detail-" + payment.text("id"))
                        Text(payment.text("status") == "posted" ? "Pagato · movimento collegato" : payment.text("status") == "deleting" ? "Eliminazione da completare" : "Da completare · non registrare una nuova spesa").font(.caption).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("plan-payment-status")
                        if payment.text("status") == "pending" {
                            Button("Completa questa registrazione") {
                                Task { await run("resumeFinancePlanPayment", ["paymentId": .string(payment.text("id"))]) }
                            }.disabled(working)
                        }
                    }
                }
            }
            if plan.text("status") == "active" {
                Section {
                    if !["advance", "recovery"].contains(plan.text("kind")) { Button("Modifica le quote future") { editingPlan = true }.accessibilityIdentifier("plan-edit") }
                    Button(plan.text("kind") == "advance" ? "Annulla l’intero anticipo" : "Interrompi le quote future", role: .destructive) { stopping = true }.disabled(working)
                }
            }
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Dettagli piano").navigationBarTitleDisplayMode(.inline)
            .onAppear { router.financeSection = "Budget" }
            .sheet(isPresented: $editingPlan) { NavigationStack { NativePlanQuotaEditor(plan: plan) } }
            .sheet(isPresented: $paying) { NavigationStack { NativePlanPaymentEditor(plan: plan) } }
            .confirmationDialog("Interrompere il piano? Le quote già maturate e i pagamenti rimangono nello storico. Un anticipo già usato in un mese chiuso non può essere cancellato.", isPresented: $stopping, titleVisibility: .visible) {
                Button("Conferma", role: .destructive) { Task { await run("stopFinancePlan", ["requestId": .string(stopID), "planId": .string(planID)]) } }
            }
    }
    private func run(_ method: String, _ payload: Record) async {
        working = true; defer { working = false }
        do { try await store.perform(method, payload); await store.loadFinancePlans() } catch { self.error = error.localizedDescription }
    }
}

private struct NativePlanPaymentEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let plan: Record
    @State private var amount = ""
    @State private var date = Date()
    @State private var cycleMonth = CivilDate.month()
    @State private var competenceMonths = 1
    @State private var bill = NativeUtilityPeriodDraft()
    @State private var recover = false
    @State private var first = NativePlanRules.adding(1, to: CivilDate.month())
    @State private var last = NativePlanRules.adding(1, to: CivilDate.month())
    @State private var requestID = UUID().uuidString
    @State private var submitted = false
    @State private var saving = false
    @State private var error: String?
    @State private var usesExisting = false
    @State private var movement: Record?
    @FocusState private var editing: Bool
    private var amountCents: Int? { Input.cents(amount) }
    private var expectedCents: Int { plan.text("kind") == "goal" && plan["outstandingCents"] != nil ? plan.integer("outstandingCents") : NativePlanRules.rate(plan, month: CivilDate.month()) }
    private var extra: Int { max(0, (amountCents ?? 0) - expectedCents) }
    var body: some View {
        Form {
            Section("Importo effettivo") {
                Text(plan.text("name")).font(.headline)
                TextField("Pagato €", text: $amount).keyboardType(.decimalPad).focused($editing).accessibilityIdentifier("plan-payment-amount").disabled(usesExisting)
                Picker("Movimento bancario", selection: $usesExisting) { Text("Da registrare").tag(false); Text("Già registrato").tag(true) }.pickerStyle(.segmented)
                if usesExisting { NativePlanMovementPicker(selection: $movement) }
                else { DatePicker("Giorno del pagamento", selection: $date, in: ...Date(), displayedComponents: .date) }
                if plan.text("kind") == "fixed" { NativeMonthPicker(title: "Scadenza pagata", selection: $cycleMonth) }
                if plan.text("kind") == "estimated" { NativeUtilityPeriodFields(period: $bill, amountCents: amountCents ?? 0) }
                Text(usesExisting ? "Collega una spesa esistente senza un secondo addebito. Le quote del piano restano distinte dal saldo." : "Un unico movimento dai risparmi. L’intero pagamento non verrà sottratto una seconda volta dal budget.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }.disabled(submitted)
            if plan.text("kind") == "goal", extra > 0 {
                Section("Differenza rispetto al previsto") {
                    LabeledContent("In più", value: (Double(extra) / 100).euro)
                    Toggle("Recupera la differenza nei budget futuri", isOn: $recover)
                    if recover { NativeMonthPicker(title: "Primo mese", selection: $first); NativeMonthPicker(title: "Ultimo mese", selection: $last) }
                    Text("Se non attivi il recupero, la differenza resta a carico dei risparmi.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }.disabled(submitted)
            }
            Section {
                Text(plan.text("kind") == "goal" ? "Il piano si chiude e le quote future si annullano. Il denaro non utilizzato rimane nei risparmi." : "Il piano rimane attivo dopo il pagamento. Il fondo residuo e le quote future continuano.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Registra pagamento").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button(submitted ? "Riprova" : "Conferma") { Task { await save() } }.disabled(saving || amountCents == nil || (usesExisting && movement == nil) || (plan.text("kind") == "estimated" && bill.months == nil)).accessibilityIdentifier("plan-payment-confirm") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } }
            }
            .task { amount = String(format: "%.2f", Double(expectedCents) / 100); competenceMonths = max(1, plan.integer("intervalMonths")); bill.prepare(day: CivilDate.day(date), required: plan.text("kind") == "estimated") }
            .onChange(of: movement) { _, value in
                if let value { amount = String(format: "%.2f", Double(value.integer("amountCents")) / 100); date = CivilDate.date(value.text("date")) }
            }
            .interactiveDismissDisabled(saving)
    }
    private func save() async {
        guard let cents = amountCents else { return }
        saving = true; editing = false; defer { saving = false }
        do {
            var payload: Record = ["requestId": .string(requestID), "planId": .string(plan.text("id")), "amountCents": .int(cents), "date": .string(CivilDate.day(date)), "cycleMonth": .string(cycleMonth), "competenceMonths": .int(competenceMonths)]
            if bill.enabled {
                guard bill.months != nil else { throw Message(text: "Verifica il periodo della bolletta.") }
                payload.merge(bill.payload) { _, value in value }
                payload["cycleMonth"] = .string(CivilDate.month(date))
            }
            if plan.text("kind") == "goal", extra > 0, recover {
                _ = try NativePlanRules.months(first, last)
                guard first >= CivilDate.month() else { throw Message(text: "Il recupero deve iniziare da un mese aperto o futuro.") }
                payload["recoverDifference"] = .bool(true); payload["recoveryStartMonth"] = .string(first); payload["recoveryEndMonth"] = .string(last)
            }
            if usesExisting {
                guard let movement else { throw Message(text: "Scegli il movimento già registrato.") }
                payload["movementId"] = movement["row"]
            }
            submitted = true
            try await store.perform(bill.enabled ? "recordUtilityPlanPayment" : "recordFinancePlanPayment", payload)
            await store.loadFinancePlans(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct NativePlansInfo: View {
    var body: some View {
        List {
            Section("La regola di base") {
                Text("Il budget indica quanto puoi destinare ai mesi. Il saldo è il denaro reale sul conto. Accantonare modifica il budget, pagare registra una sola uscita reale.")
            }
            Section("+ · Scegli cosa vuoi fare") {
                Text("Il + è indipendente dal mese che stai consultando. Prima scegli l’intento, poi nome, importo e mesi. Il giorno serve soltanto per il pagamento.")
            }
            Section("Anticipa budget") {
                Text("250 € su ottobre, recuperati da novembre e dicembre: ottobre +250 €, novembre −125 €, dicembre −125 €. Il saldo non cambia. Non puoi cancellare solo le quote future mantenendo l’anticipo di un mese chiuso.")
            }
            Section("Obiettivo finito") {
                Text("Distribuisci il totale sui mesi scelti. Quando paghi, confermi l’importo effettivo e chiudi le quote future. Le quote maturate restano nello storico.")
                Text("Previsti 600 €, pagati 500 €: il residuo rimane nei risparmi. Pagati 700 €: puoi recuperare i soli 100 € in più nei budget futuri; altrimenti restano a carico dei risparmi.")
            }
            Section("Fondo senza scadenza · manutenzione auto") {
                Text("Scegli una quota mensile. Il fondo accumula nel tempo. Un pagamento riduce il fondo e il saldo una sola volta; il piano continua. Interrompi ferma le quote future senza generare una spesa e libera l’eventuale residuo nei risparmi generali.")
            }
            Section("Affitto e utenze") {
                Text("Affitto: importo e periodicità fissi. Il pagamento chiude una scadenza, non il piano. Per le bollette scegli mese iniziale e finale: 221,79 € da agosto a ottobre pesano 73,93 € su ciascun mese, anche passato. Il costo effettivo sostituisce la stima; il pagamento resta unico e gli accantonamenti del fondo rimangono separati.")
            }
            Section("Rateizza una spesa") {
                Text("Il pagamento è una sola uscita dai risparmi. Nei mesi scelti riduci il budget per ricostituirli. Questo piano non ha un secondo pulsante Paga. Se la registrazione è rimasta in sospeso, usa Completa questa registrazione, senza creare un altro pagamento.")
            }
            Section("Piani precedenti e modifiche") {
                Text("Affitto, utenze e accantonamenti esistenti vengono adottati una sola volta, senza creare movimenti bancari né riscrivere i mesi chiusi. Il pagamento può essere nuovo oppure collegato a una spesa già registrata. Le modifiche alle quote decorrono da un mese futuro.")
            }
            Section("Spesa rapida") {
                Text("Automatico applica le regole ordinarie. Da risparmi evita un nuovo addebito al budget. I piani, i recuperi e i pagamenti pianificati si gestiscono qui.")
            }
            Section("Prima di confermare") {
                Text("Controlla l’anteprima mese per mese. Le quote sono esatte al centesimo. Un anticipo non è un’entrata bancaria. Un piano interrotto non cancella pagamenti già effettuati. L’adozione conserva le identità delle voci esistenti e sostituisce le loro quote dal mese corrente, senza duplicarle. Gli anticipi storici restano consultabili.")
            }
        }.modifier(NativeListAppearance()).navigationTitle("Come funzionano i piani").navigationBarTitleDisplayMode(.inline).toolbar { DoneButton() }
            .accessibilityIdentifier("plans-info-content")
    }
}

private struct NativePlanMovementPicker: View {
    @EnvironmentObject var store: NativeStore
    @Binding var selection: Record?
    @State private var month = CivilDate.month()
    @State private var rows: [Record] = []
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            NativeMonthPicker(title: "Mese del movimento", selection: $month)
            if loading { ProgressView("Cerco i movimenti…") }
            if let error { NativeInlineMessage(text: error) }
            if !loading, rows.isEmpty { Text("Nessun movimento collegabile in questo mese.").font(.caption).foregroundStyle(NativeDesign.secondary) }
            ForEach(rows.map { DisplayRecord($0, key: "row") }) { item in
                Button {
                    selection = item.value
                } label: {
                    HStack {
                        NativeRowText(title: item.value.text("name"), subtitle: CivilDate.label(item.value.text("date")))
                        Spacer()
                        Text((Double(item.value.integer("amountCents")) / 100).euro).monospacedDigit()
                        if selection?.integer("row") == item.value.integer("row") { Image(systemName: "checkmark") }
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(NativePressStyle()).accessibilityIdentifier("plan-link-movement-\(item.value.integer("row"))")
            }
        }
        .task(id: month) { await load() }
        .onChange(of: month) { _, _ in selection = nil }
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            if store.isDemo {
                let linked = Set(store.finance.record("plansV2").records("payments").map { $0.integer("movementId") })
                rows = store.finance.records("transactions").filter { $0.amount("amount") < 0 && $0.text("type") == "Spesa" && $0.text("date").hasPrefix(month) && !linked.contains($0.integer("row")) }.map { row in
                    var value = row; value["amountCents"] = .int(Int((-row.amount("amount") * 100).rounded())); return value
                }
            } else { rows = try await store.read("getFinancePlanMovements", args: [.string(month)]).object.records("movements") }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}

private struct NativePlanQuotaEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let plan: Record
    @State private var amount = ""
    @State private var first = NativePlanRules.adding(1, to: CivilDate.month())
    @State private var last = NativePlanRules.adding(1, to: CivilDate.month())
    @State private var saving = false
    @State private var submitted = false
    @State private var error: String?
    @State private var requestID = UUID().uuidString
    @FocusState private var editing: Bool
    var body: some View {
        Form {
            Section("Quote future") {
                Text(plan.text("name")).font(.headline)
                TextField(plan.text("kind") == "goal" ? "Nuovo totale previsto €" : plan.text("kind") == "fixed" ? "Importo per scadenza €" : plan.text("kind") == "estimated" ? "Accantonamento mensile €" : "Quota mensile €", text: $amount).keyboardType(.decimalPad).focused($editing).accessibilityIdentifier("plan-edit-amount")
                NativeMonthPicker(title: "Decorrenza", selection: $first)
                if plan.text("kind") == "goal" { NativeMonthPicker(title: "Ultimo mese", selection: $last) }
                Text("I mesi precedenti alla decorrenza e i pagamenti restano invariati. Per un obiettivo, il nuovo totale viene distribuito sui mesi futuri dopo le quote già maturate.").font(.caption).foregroundStyle(NativeDesign.secondary)
            }.disabled(submitted)
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Modifica piano").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button(submitted ? "Riprova" : "Salva") { Task { await save() } }.disabled(saving || Input.cents(amount) == nil).accessibilityIdentifier("plan-edit-save") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } }
            }
            .task { first = max(first, plan.text("startMonth")); amount = String(format: "%.2f", Double(NativePlanRules.rate(plan, month: first)) / 100); last = max(first, plan.text("endMonth")) }
            .interactiveDismissDisabled(saving)
    }
    private func save() async {
        guard let cents = Input.cents(amount) else { return }
        saving = true; editing = false; defer { saving = false }
        do {
            guard first > CivilDate.month() else { throw Message(text: "Scegli una decorrenza futura.") }
            var payload: Record = ["requestId": .string(requestID), "planId": .string(plan.text("id")), "amountCents": .int(cents), "fromMonth": .string(first)]
            if plan.text("kind") == "goal" { _ = try NativePlanRules.months(first, last); payload["endMonth"] = .string(last) }
            submitted = true
            try await store.perform("editFinancePlan", payload); await store.loadFinancePlans(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
