import SwiftUI

struct NativeMonthPicker: View {
    let title: String
    @Binding var selection: String
    /// Months already gone (Analisi start): years up to the current one, the last five before it.
    var pastOnly = false
    private var month: Binding<Int> { Binding(get: { Int(selection.suffix(2)) ?? 1 }, set: { selection = String(selection.prefix(4)) + String(format: "-%02d", $0) }) }
    private var year: Binding<Int> { Binding(get: { Int(selection.prefix(4)) ?? 2026 }, set: { selection = String($0) + "-" + String(selection.suffix(2)) }) }
    private var years: ClosedRange<Int> {
        let current = Int(CivilDate.month().prefix(4))!, selected = Int(selection.prefix(4)) ?? current
        if pastOnly { return min(current - 5, selected)...current }
        return min(current, selected)...min(2099, max(current + 20, selected))
    }
    // REVIEW-95C: month names never wrap («Novem-bre»); when the row is too narrow the pickers go under the title.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: NativeDesign.Space.small)
                pickers
            }
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) { Text(title); pickers }
        }
    }
    private var pickers: some View {
        HStack(spacing: NativeDesign.Space.small) {
            Picker("Mese · " + title, selection: month) {
                ForEach(1...12, id: \.self) { value in Text(CivilDate.monthTitle(String(format: "2026-%02d", value)).components(separatedBy: " ")[0]).tag(value) }
            }.labelsHidden().pickerStyle(.menu).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            Picker("Anno · " + title, selection: year) { ForEach(Array(years), id: \.self) { Text(String($0)).tag($0) } }
                .labelsHidden().pickerStyle(.menu).lineLimit(1).fixedSize(horizontal: true, vertical: false)
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
            if store.plansBusy || store.plansError != nil {
                Section {
                    if store.plansBusy { ProgressView("Aggiorno i piani…") }
                    if let error = store.plansError {
                        NativeInlineMessage(text: error)
                        if let server = store.server { Text(server.host ?? "").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                        Button("Riprova") { Task { await store.loadFinancePlans() } }
                    }
                }
            }
            // BUDGET-MAP-97: the month at a glance first (map and final budget); the rows stay below for detail.
            Section {
                NativeBudgetMapCard(flow: flow, month: store.financeMonth, plans: plans, categories: store.finance.records("categories"), hidden: hidden)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            // Build 93 Budget: salary, plans and commitments, budget of the month; then the plans.
            Section {
                LabeledContent("Stipendio", value: money(flow.salaryCents)).monospacedDigit().accessibilityIdentifier("budget-salary-reference")
                LabeledContent("Piani e impegni", value: money(-flow.rows.reduce(0) { $0 + $1.amountCents })).monospacedDigit()
                LabeledContent("Budget del mese") {
                    Text(money(flow.salaryCents - flow.rows.reduce(0) { $0 + $1.amountCents })).foregroundStyle(.primary)
                }.font(.headline).monospacedDigit()
                    .accessibilityIdentifier("budget-month-total")
            } footer: {
                if store.isDemo { Text("Piani demo · nessuna modifica al server") }
            }
            // FINANCE-ENTRY-SIMPLIFY-2026-11-24: instalments are expenses split over months, not plans. Same rows
            // and amounts as before (the server computes them); only shown apart, as «Spese a rate».
            let instalments = flow.rows.filter { NativeInstalments.isInstalment($0, plans: plans) }
            let planRows = flow.rows.filter { !NativeInstalments.isInstalment($0, plans: plans) }
            if !instalments.isEmpty {
                Section("Spese a rate") {
                    ForEach(instalments) { row in
                        if let id = row.planID {
                            NavigationLink { NativePlanDetail(planID: id) } label: { instalmentRow(row) }.accessibilityIdentifier("instalment-" + id)
                        } else { instalmentRow(row) }
                    }
                }
            }
            Section("Piani del mese") {
                if planRows.isEmpty { Text("Nessun piano per questo mese").foregroundStyle(NativeDesign.secondary) }
                ForEach(planRows) { row in
                    if let id = row.planID {
                        NavigationLink { NativePlanDetail(planID: id) } label: { budgetRow(row) }.accessibilityIdentifier("plan-" + id)
                    } else { budgetRow(row) }
                }
                LabeledContent("Spese non già coperte dai piani", value: money(-flow.spentCents))
                LabeledContent("Budget finale", value: money(flow.remainingCents)).font(.headline).accessibilityIdentifier("budget-final-remaining")
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
                    ForEach(Array(Dictionary(grouping: store.allocations, by: { $0.integer("cycle_id") }).values.compactMap(\.first)).sorted { $0.text("name") < $1.text("name") }.map { DisplayRecord($0, key: "cycle_id") }) { item in
                        Button { router.sheet = .extra(item.value) } label: { NativeRowText(title: item.value.text("name"), subtitle: NativeExtraState.title(item.value.text("status"))) }.buttonStyle(NativePressStyle())
                    }
                }
            }
            NativeSavingsSection()
        }.modifier(NativeListAppearance()).navigationTitle("Budget").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // REVIEW-95: the month chip sits next to the title, no row of its own.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: NativeDesign.Space.small) {
                        Text("Budget").font(.headline).accessibilityAddTraits(.isHeader)
                        NativeFinanceMonthChip()
                    }
                }
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
    private func instalmentRow(_ row: NativeBudgetFlow.Row) -> some View {
        let text = NativeInstalments.title(row, plans: plans, month: store.financeMonth)
        return HStack(spacing: NativeDesign.Space.medium) {
            Circle().fill(NativeDesign.financeGroups[2]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(text.name)
                if !text.detail.isEmpty { Text(text.detail).font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit() }
            }
            Spacer(minLength: NativeDesign.Space.small)
            Text(money(row.amountCents)).monospacedDigit()
        }
        .padding(.vertical, NativeDesign.Space.xs)
        .accessibilityElement(children: .combine)
    }
    private func budgetRow(_ row: NativeBudgetFlow.Row) -> some View {
        let plan = row.planID.flatMap { id in plans.first { $0.text("id") == id } }
        let kinds = ["advance": "anticipo", "goal": "obiettivo", "fund": "fondo", "fixed": "ricorrente", "estimated": "ricorrente stimata", "recovery": "spesa a rate"]
        let kind = plan.flatMap { kinds[$0.text("kind")] } ?? ""
        return HStack(spacing: NativeDesign.Space.medium) {
            Circle().fill(NativeDesign.financeGroups[plan == nil ? 0 : 1]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(row.name)
                Text([kind, "rimane " + money(row.remainingCents)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit()
            }
            Spacer(minLength: NativeDesign.Space.small)
            Text(money(row.amountCents)).monospacedDigit()
        }
        .padding(.vertical, NativeDesign.Space.xs)
        .accessibilityElement(children: .combine)
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
    /// REFERENCE-GAPS-95 «Da dove arrivano le quote»: part of a goal paid from savings; the budget quotes cover the rest.
    @State private var fromSavings = 0
    private var totalCents: Int { Input.cents(draft.amount) ?? 0 }
    private var offersSavings: Bool { draft.kind == .goal && totalCents > 0 }
    /// The draft the server receives: the amount covered by the budget quotes.
    private var budgetDraft: NativePlanDraft {
        guard offersSavings, fromSavings > 0 else { return draft }
        var copy = draft; copy.amount = String(format: "%.2f", Double(max(0, totalCents - fromSavings)) / 100); return copy
    }
    private var preview: [Record] { (try? budgetDraft.preview()) ?? [] }
    private var validationIssue: String? {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !draft.amount.isEmpty else { return nil }
        do { _ = try budgetDraft.payload(requestID: requestID); return nil } catch { return error.localizedDescription }
    }
    var body: some View {
        Form {
            // FINANCE-ENTRY-SIMPLIFY-2026-11-24: three kinds only. Obiettivo is gone (a Fondo closed later does the same);
            // instalments are made from Nuova spesa; «Ricorrente» covers fixed and estimated amounts.
            Section("Cosa vuoi fare?") {
                ForEach([NativePlanKind.advance, .fund, .fixed]) { kind in
                    let selected = kind == .fixed ? [.fixed, .estimated].contains(draft.kind) : draft.kind == kind
                    Button { if !(kind == .fixed && selected) { draft.kind = kind } } label: {
                        HStack(spacing: NativeDesign.Space.medium) {
                            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                                Text(kind == .fixed ? "Ricorrente" : kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                                Text(kind == .fixed ? "Una spesa che torna: affitto, assicurazione, bollette" : NativePlanKindText.detail(kind)).font(.footnote).foregroundStyle(NativeDesign.secondary)
                            }
                            Spacer(minLength: NativeDesign.Space.small)
                            if selected { Image(systemName: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(NativeDesign.financeTitle) }
                        }
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel((kind == .fixed ? "Ricorrente" : kind.title) + ", " + NativePlanKindText.detail(kind))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("plan-kind-" + kind.rawValue)
                }
            }.disabled(submitted)
            Section("Dettagli") {
                if [.fixed, .estimated].contains(draft.kind) {
                    Picker("Importo", selection: $draft.kind) { Text("Importo fisso").tag(NativePlanKind.fixed); Text("Stimato").tag(NativePlanKind.estimated) }
                        .pickerStyle(.segmented).accessibilityIdentifier("plan-recurring-amount")
                }
                LabeledContent("Nome") {
                    TextField("es. Bolletta luce", text: $draft.name).multilineTextAlignment(.trailing).focused($editing).accessibilityIdentifier("plan-name")
                }
                if draft.kind != .advance {
                    Picker("Categoria della spesa", selection: $draft.category) { ForEach(Input.categories, id: \.self) { Text($0) } }
                }
                LabeledContent(draft.kind == .estimated ? "Accantonamento al mese" : draft.kind == .fund ? "Quota al mese" : draft.kind == .fixed ? "Importo per scadenza" : "Importo totale") {
                    TextField("0 €", text: $draft.amount).multilineTextAlignment(.trailing).keyboardType(.decimalPad).focused($editing).accessibilityIdentifier("plan-amount").disabled(draft.kind == .recovery && usesExisting)
                }
            }.disabled(submitted)
            Section("Mesi del piano") {
                if draft.kind == .advance { NativeMonthPicker(title: "Mese beneficiario", selection: $draft.beneficiaryMonth) }
                NativeMonthPicker(title: draft.kind == .advance ? "Recupera da" : "Primo mese", selection: $draft.startMonth)
                if draft.kind.finite { NativeMonthPicker(title: "Ultimo mese", selection: $draft.endMonth) }
                else { Text("Senza scadenza · continua finché interrompi il piano").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                if draft.kind == .fixed { Stepper("Pagamento ogni \(draft.intervalMonths) mesi", value: $draft.intervalMonths, in: 1...12) }
                if draft.kind == .estimated { Text("La quota verrà aggiornata dai pagamenti e dai mesi coperti, a partire dal mese successivo. Le quote passate restano invariate.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
            }.disabled(submitted)
            if draft.kind == .recovery {
                Section("Pagamento già effettuato") {
                    Picker("Movimento bancario", selection: $usesExisting) { Text("Da registrare").tag(false); Text("Già registrato").tag(true) }.pickerStyle(.segmented)
                    if usesExisting { NativePlanMovementPicker(selection: $movement) }
                    else { DatePicker("Giorno del pagamento", selection: paymentDate, in: ...Date(), displayedComponents: .date) }
                    Text(usesExisting ? "Collega il movimento esistente: il saldo non cambia. Sono disponibili le spese dai risparmi e quelle del mese corrente non già collegate." : "Registra una sola spesa dai risparmi e recupera l’importo nei budget scelti.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                }.disabled(submitted)
            }
            if offersSavings {
                Section("Da dove arrivano le quote") {
                    HStack(spacing: NativeDesign.Space.small) {
                        Text("Risparmi")
                        Spacer(minLength: NativeDesign.Space.small)
                        NativeIconButton(symbol: "minus", label: "Meno dai risparmi") { fromSavings = max(0, fromSavings - NativeExpenseSplit.step) }
                            .disabled(fromSavings <= 0).accessibilityIdentifier("plan-savings-less")
                        Text((Double(min(fromSavings, totalCents)) / 100).euro).monospacedDigit().frame(minWidth: NativeDesign.Layout.actionCircle)
                            .accessibilityIdentifier("plan-savings")
                        NativeIconButton(symbol: "plus", label: "Più dai risparmi") { fromSavings = min(totalCents - 1, fromSavings + NativeExpenseSplit.step) }
                            .disabled(fromSavings >= totalCents - 1).accessibilityIdentifier("plan-savings-more")
                    }
                    LabeledContent("Budget, divisi sui mesi", value: (Double(max(0, totalCents - fromSavings)) / 100).euro)
                    Text("La parte dai risparmi non diventa quote: al pagamento la copre il fondo dei risparmi.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                }.disabled(submitted)
            }
            Section(draft.kind.finite ? "Anteprima budget" : "Anteprima · primi tre mesi") {
                ForEach(Array(preview.enumerated()), id: \.offset) { _, row in
                    LabeledContent(CivilDate.monthTitle(row.text("month")), value: (Double(row.integer("deltaCents")) / 100).euro)
                }
                Text(draft.kind == .recovery ? "Il saldo diminuisce una sola volta, dell’importo pagato. Le quote future modificano solo il budget." : "Queste quote modificano il budget, senza creare un’uscita dal conto.")
                    .font(.footnote).foregroundStyle(NativeDesign.secondary)
                if preview.isEmpty { Text(validationIssue ?? "Completa nome, importo e mesi per visualizzare l’anteprima.").foregroundStyle(NativeDesign.secondary) }
            }
            if !store.isDemo && store.finance.record("plansV2").integer("version") != 2 {
                Section { Text("Per salvare serve l’aggiornamento del server al sistema Piani. I dati e i piani precedenti rimangono conservati.").foregroundStyle(NativeDesign.secondary) }
            }
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Nuovo piano").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    NativeSheetConfirm(retry: submitted) { Task { await save() } }.disabled(saving || preview.isEmpty || (draft.kind == .recovery && usesExisting && movement == nil) || store.busy || (!store.isDemo && store.finance.record("plansV2").integer("version") != 2)).accessibilityIdentifier("plan-save")
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
            .onAppear { if [.goal, .recovery].contains(draft.kind) { draft.kind = .fund } }
    }
    private var paymentDate: Binding<Date> { Binding(get: { CivilDate.date(draft.paymentDate) }, set: { draft.paymentDate = CivilDate.day($0) }) }
    private func save() async {
        saving = true; editing = false; defer { saving = false }
        do {
            var payload = try budgetDraft.payload(requestID: requestID)
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
    @State private var renaming = false
    @State private var stopping = false
    @State private var working = false
    @State private var error: String?
    @State private var stopID = UUID().uuidString
    private var plan: Record { store.finance.record("plansV2").records("plans").first { $0.text("id") == planID } ?? [:] }
    private var payments: [Record] { store.finance.record("plansV2").records("payments").filter { $0.text("planId") == planID }.sorted { $0.text("date") > $1.text("date") } }
    var body: some View {
        List {
            Section {
                // RENAME-EVERYWHERE-2026-11-26: the name is changed where it is shown.
                NativePlanNameHeader(name: plan.text("name")) { renaming = true }
                LabeledContent("Tipo", value: NativePlanKind(rawValue: plan.text("kind"))?.title ?? "Piano")
                LabeledContent("Stato") { Text(NativePlanRules.stateTitle(plan.text("status"))).accessibilityIdentifier("plan-status") }
                LabeledContent("Primo mese", value: CivilDate.monthTitle(plan.text("startMonth")))
                if !plan.text("endMonth").isEmpty { LabeledContent("Ultimo mese", value: CivilDate.monthTitle(plan.text("endMonth"))) }
                else { Text("Senza scadenza").font(.footnote).foregroundStyle(NativeDesign.secondary) }
                if plan.text("kind") == "advance" { LabeledContent("Mese beneficiario", value: CivilDate.monthTitle(plan.text("beneficiaryMonth"))) }
                LabeledContent((NativeUtilityPeriodDraft.isCostFund(plan) ? "Accantonato in " : "Budget di ") + CivilDate.monthTitle(store.financeMonth), value: (Double(plan.integer("contributionCents")) * (NativeUtilityPeriodDraft.isCostFund(plan) ? 1 : -1) / 100).euro)
                if plan.text("kind") == "estimated", plan.text("status") == "active", !plan.record("levelling").isEmpty {
                    NativeLevellingNote(levelling: plan.record("levelling"))
                }
                if !["advance", "recovery"].contains(plan.text("kind")) {
                    LabeledContent("Disponibile nel fondo", value: (Double(plan.integer("fundCents")) / 100).euro)
                    if plan.integer("fromGeneralSavingsCents") > 0 { LabeledContent("Pagato dagli altri risparmi", value: (Double(plan.integer("fromGeneralSavingsCents")) / 100).euro) }
                }
                if plan.text("status") == "active", plan.text("startMonth") <= CivilDate.month(), NativePlanKind(rawValue: plan.text("kind"))?.payable == true {
                    if NativePlanRules.isPaid(plan, payments: payments, month: store.financeMonth) { Text("Pagamento registrato").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
                    else {
                    if plan.text("kind") == "goal" {
                        Button("Paga dai risparmi e chiudi il piano") { paying = true }.accessibilityIdentifier("plan-record-payment")
                    } else {
                        // FINANCE-ENTRY-SIMPLIFY-2026-11-24: one way for money going out, Nuova spesa with this plan chosen.
                        Button("Paga con Nuova spesa") {
                            router.sheet = .movement(["type": .string("Spesa"), "category": .string(plan.text("category", fallback: "Altro")),
                                                      "description": .string(plan.text("name")), "planPreset": .string(planID)])
                        }.accessibilityIdentifier("plan-record-payment")
                    }
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
                        Text(payment.text("status") == "posted" ? "Pagato · movimento collegato" : payment.text("status") == "deleting" ? "Eliminazione da completare" : "Da completare · non registrare una nuova spesa").font(.footnote).foregroundStyle(NativeDesign.secondary).accessibilityIdentifier("plan-payment-status")
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
            // PLAN-DETAIL-RICH-2026-11-26: fund and forecast, month by month, linked movements, below the
            // status and the actions so those stay at the top.
            NativePlanRichSections(plan: plan, payments: payments)
            NativePlanLinkedMovements(payments: payments)
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Dettagli piano").navigationBarTitleDisplayMode(.inline)
            .onAppear { router.financeSection = "Budget" }
            .sheet(isPresented: $editingPlan) { NavigationStack { NativePlanQuotaEditor(plan: plan) } }
            .sheet(isPresented: $renaming) { NavigationStack { NativePlanRenameSheet(planID: planID, current: plan.text("name")) } }
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

struct NativePlanPaymentEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let plan: Record
    /// FINANCE-ENTRY-SIMPLIFY-2026-11-24: opened from Nuova spesa › Piano › «Già registrato».
    var startsWithExisting = false
    var onSaved: () -> Void = {}
    @State private var amount = ""
    @State private var date = Date()
    @State private var cycleMonth = CivilDate.month()
    @State private var competenceMonths = 1
    @State private var bill = NativeUtilityPeriodDraft()
    @State private var difference = NativeExpenseSplit()
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
                if plan.text("kind") == "fixed" && !NativeUtilityPeriodDraft.isCostFund(plan) { NativeMonthPicker(title: "Scadenza pagata", selection: $cycleMonth) }
                if NativeUtilityPeriodDraft.isCostFund(plan) { NativeUtilityPeriodFields(period: $bill, amountCents: amountCents ?? 0) }
                Text(usesExisting ? "Collega una spesa esistente senza un secondo addebito. Le quote del piano restano distinte dal saldo." : "Un unico movimento dai risparmi. L’intero pagamento non verrà sottratto una seconda volta dal budget.").font(.footnote).foregroundStyle(NativeDesign.secondary)
            }.disabled(submitted)
            if extra > 0 && !usesExisting {
                // REFERENCE-GAPS-95 «Registra pagamento»: the difference between savings and open budget months.
                Section("Differenza rispetto al previsto") {
                    LabeledContent("In più", value: (Double(extra) / 100).euro)
                    NativeExpenseSplitRows(split: $difference, amount: extra, day: CivilDate.day(Date()), allowsAll: true,
                                           showsMonths: !bill.enabled, budgetTitle: bill.enabled ? "Sui mesi di competenza" : "Budget")
                    Text("Quello che resta sui risparmi non pesa sul budget; la parte sul budget si divide sui mesi scelti.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                }.disabled(submitted)
            }
            Section {
                Text(plan.text("kind") == "goal" ? "Il piano si chiude e le quote future si annullano. Il denaro non utilizzato rimane nei risparmi." : "Il piano rimane attivo dopo il pagamento. Il fondo residuo e le quote future continuano.").font(.footnote).foregroundStyle(NativeDesign.secondary)
            }
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle(startsWithExisting ? "Spesa già registrata" : "Registra pagamento").navigationBarTitleDisplayMode(.inline)
            .onAppear { if startsWithExisting { usesExisting = true } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { NativeSheetConfirm(title: "Conferma", retry: submitted) { Task { await save() } }.disabled(saving || amountCents == nil || (usesExisting && movement == nil) || (NativeUtilityPeriodDraft.isCostFund(plan) && bill.months == nil)).accessibilityIdentifier("plan-payment-confirm") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { editing = false } }
            }
            .task { amount = String(format: "%.2f", Double(expectedCents) / 100); competenceMonths = max(1, plan.integer("intervalMonths")); bill.prepare(day: CivilDate.day(date), required: NativeUtilityPeriodDraft.isCostFund(plan)) }
            .onChange(of: movement) { _, value in
                if let value { amount = String(format: "%.2f", Double(value.integer("amountCents")) / 100); date = CivilDate.date(value.text("date")) }
            }
            .interactiveDismissDisabled(saving)
            // The difference starts all on savings; the user moves part of it to budget months.
            .onChange(of: extra, initial: true) { _, value in difference = NativeExpenseSplit(savings: value) }
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

            if usesExisting {
                guard let movement else { throw Message(text: "Scegli il movimento già registrato.") }
                payload["movementId"] = movement["row"]
            }
            submitted = true
            try await store.perform(bill.enabled ? "recordUtilityPlanPayment" : "recordFinancePlanPayment", payload)
            await store.loadFinancePlans()
            defer { onSaved() }
            var part = difference; part.savings = min(part.savings, extra)
            if !usesExisting, bill.enabled, extra > 0 {
                // A bill: the savings part of the difference; the rest stays on its competence months.
                let paid = store.finance.record("plansV2").records("payments").first { $0.text("requestId") == requestID || $0.text("id") == requestID }
                guard let movementID = paid?.integer("movementId"), movementID > 0 else { throw Message(text: "Pagamento registrato. Riapri il piano per indicare la parte dai risparmi.") }
                if part.savings > 0 {
                    try await store.perform("changeExpenseDestination", ["requestId": .string(requestID + "-savings"), "movementId": .int(movementID),
                                                                         "expenseDestination": .string("billSavings"), "utilitySavingsCents": .int(part.savings)])
                }
            } else if !usesExisting, let split = part.planPayload(uncovered: extra, day: CivilDate.day(Date())) {
                let paid = store.finance.record("plansV2").records("payments").first { $0.text("requestId") == requestID || $0.text("id") == requestID }
                guard let movementID = paid?.integer("movementId"), movementID > 0 else { throw Message(text: "Pagamento registrato. Riapri il piano per dividere la differenza sul budget.") }
                var change: Record = ["requestId": .string(requestID + "-split"), "movementId": .int(movementID), "expenseDestination": .string("budgetSplit")]
                change.merge(split) { _, value in value }
                try await store.perform("changeExpenseDestination", change)
            }
            dismiss()
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
            if !loading, rows.isEmpty { Text("Nessun movimento collegabile in questo mese.").font(.footnote).foregroundStyle(NativeDesign.secondary) }
            ForEach(rows.map { DisplayRecord($0, key: "row") }) { item in
                Button {
                    selection = item.value
                } label: {
                    HStack {
                        NativeRowText(title: item.value.text("name"), subtitle: CivilDate.label(item.value.text("date")))
                        Spacer()
                        Text((Double(item.value.integer("amountCents")) / 100).euro).monospacedDigit()
                        if selection?.integer("row") == item.value.integer("row") { Image(systemName: "checkmark") }
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).padding(.vertical, NativeDesign.Space.xxs).contentShape(Rectangle()) // 44 pt minimum even after pixel rounding (start 3: 43.67)
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
                Text("I mesi precedenti alla decorrenza e i pagamenti restano invariati. Per un obiettivo, il nuovo totale viene distribuito sui mesi futuri dopo le quote già maturate.").font(.footnote).foregroundStyle(NativeDesign.secondary)
            }.disabled(submitted)
            if let error { Section { NativeInlineMessage(text: error) } }
        }.modifier(NativeListAppearance()).navigationTitle("Modifica piano").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { NativeSheetConfirm(retry: submitted) { Task { await save() } }.disabled(saving || Input.cents(amount) == nil).accessibilityIdentifier("plan-edit-save") }
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


/// One line under each kind of plan, as in the build 93 preview.
enum NativePlanKindText {
    static func detail(_ kind: NativePlanKind) -> String {
        switch kind {
        case .fixed: return "Affitto e utenze: importo fisso a ogni scadenza"
        case .estimated: return "Bollette: quota stimata, divisa su più mesi"
        case .fund: return "Metti da parte ogni mese, per esempio per l'auto"
        case .goal: return "Una cifra da raggiungere entro una data"
        case .advance: return "Usa ora il budget di un mese futuro"
        case .recovery: return "Una spesa già fatta, recuperata nei mesi"
        }
    }
}

/// FINANCE-ENTRY-SIMPLIFY-2026-11-24: which budget rows are instalments and how they read («rata 2 di 6»).
enum NativeInstalments {
    static let movementPrefix = "Recupero · "
    static func isInstalment(_ row: NativeBudgetFlow.Row, plans: [Record]) -> Bool {
        if let id = row.planID { return plans.first { $0.text("id") == id }?.text("kind") == "recovery" }
        return row.name.hasPrefix(movementPrefix)
    }
    /// «Recupero · 3/3 Rata Divano Klarna» → («Rata Divano Klarna», «rata 3 di 3»); a plan → its name and the rata of this month.
    static func title(_ row: NativeBudgetFlow.Row, plans: [Record], month: String) -> (name: String, detail: String) {
        if let id = row.planID, let plan = plans.first(where: { $0.text("id") == id }) {
            let total = count(plan.text("startMonth"), plan.text("endMonth")), index = count(plan.text("startMonth"), month)
            return (plan.text("name"), total > 0 && index >= 1 && index <= total ? "rata " + String(index) + " di " + String(total) : "")
        }
        guard row.name.hasPrefix(movementPrefix) else { return (row.name, "") }
        let rest = String(row.name.dropFirst(movementPrefix.count))
        let parts = rest.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, parts[0].range(of: "^[0-9]+/[0-9]+$", options: .regularExpression) != nil {
            let n = parts[0].split(separator: "/")
            return (parts[1], "rata " + n[0] + " di " + n[1])
        }
        return (rest, "")
    }
    /// Months from `first` to `last` included (0 when unreadable).
    static func count(_ first: String, _ last: String) -> Int {
        func index(_ m: String) -> Int? { let p = m.split(separator: "-").compactMap { Int($0) }; return p.count == 2 ? p[0] * 12 + p[1] : nil }
        guard let a = index(first), let b = index(last), b >= a else { return 0 }
        return b - a + 1
    }
}

/// BILL-PAST-MONTHS-2026-11-24: after each bill the estimated quota follows the 12-month average.
struct NativeLevellingNote: View {
    let levelling: Record

    var body: some View {
        LabeledContent("Quota da " + CivilDate.monthTitle(levelling.text("fromMonth")) + ": media delle bollette", value: (Double(levelling.integer("quotaCents")) / 100).euro)
            .accessibilityIdentifier("plan-levelling")
        Text("Dopo ogni bolletta la quota segue la media degli ultimi 12 mesi. I soldi restano nei risparmi e la bolletta si paga da lì; la parte che il piano non copre la scegli quando paghi.")
            .font(.footnote).foregroundStyle(NativeDesign.secondary)
    }
}
