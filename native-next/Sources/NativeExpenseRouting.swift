import SwiftUI

struct NativeExpenseRouteSection: View {
    @EnvironmentObject private var store: NativeStore
    let category: String
    let day: String
    let amount: Int
    var movementID = 0
    @Binding var selected: String
    @Binding var competenceMonths: Int
    @Binding var ready: Bool
    @Binding var quotedAvailable: Int
    @Binding var bill: NativeUtilityPeriodDraft
    /// REVIEW-95: savings / budget months chosen by the user for an ordinary expense.
    var split: Binding<NativeExpenseSplit> = .constant(NativeExpenseSplit())
    @State private var plans: [Record] = []
    @State private var splitSupported = false
    @State private var planSplitSupported = false
    @State private var billSavingsSupported = false
    private var billSavingsPart: Int {
        guard offersBillSplit || (bill.enabled && offersPlanSplit) else { return 0 }
        let limit = chosen == nil ? amount - 1 : min(amount - 1, uncovered)
        return min(max(0, split.wrappedValue.savings), max(0, limit))
    }
    private var offersBillSplit: Bool { billSavingsSupported && bill.enabled && movementID == 0 && amount > 1 }
    private var uncovered: Int { chosen.map { NativeExpenseRouting.split(amount: amount, plan: $0).savings } ?? 0 }
    private var offersPlanSplit: Bool { (bill.enabled ? billSavingsSupported : planSplitSupported) && movementID == 0 && chosen != nil && chosen?.flag("retained") == false && uncovered > 0 }
    private var offersSplit: Bool { splitSupported && movementID == 0 && !bill.enabled && amount > 1 }
    @State private var loading = false
    @State private var issue: String?
    @State private var retry = 0
    // Offered only when the connected server declares it, never for bills with a period or existing movements.
    @State private var savingsSupported = false
    private var offersSavings: Bool { savingsSupported && movementID == 0 && !bill.enabled }
    private var query: String { category + day + String(movementID) + String(bill.enabled) + String(retry) }
    private var chosen: Record? { plans.first { $0.text("id") == selected } }
    var body: some View {
        Group {
            // FUNDING-BLOCK-2026-11-21: "Da dove arrivano i soldi" with the split between plan, savings and budget.
            Section {
                if loading { ProgressView("Verifico fondi e piani…") }
                if let issue {
                    NativeInlineMessage(text: issue)
                    Button("Riprova") { retry += 1 }
                } else {
                    Picker("Destinazione", selection: $selected) {
                        if selected.isEmpty { Text("Scegli un piano o il budget").tag("") }
                        Text("Budget mensile").tag(NativeExpenseRouting.ordinary)
                        if offersSavings || selected == NativeExpenseRouting.savings { Text("Risparmi").tag(NativeExpenseRouting.savings) }
                        ForEach(plans.indices, id: \.self) { index in Text("Piano · " + plans[index].text("name")).tag(plans[index].text("id")) }
                    }.accessibilityIdentifier("expense-destination")
                    if !selected.isEmpty && amount > 0 { fundingBar }
                    if let chosen {
                    if chosen.flag("retained") {
                        Text("Mantieni il collegamento esistente. Cambiare il periodo non sposta denaro.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    } else {
                        let split = NativeExpenseRouting.split(amount: amount, plan: chosen)
                        LabeledContent("Dal fondo " + chosen.text("name"), value: (Double(split.fund) / 100).euro)
                        if offersPlanSplit {
                            // REFERENCE-GAPS-95 «Bolletta con piano»: the uncovered part between savings and budget months.
                            NativeExpenseSplitRows(split: self.split, amount: split.savings, day: day, allowsAll: true, savingsTitle: "Dagli altri risparmi",
                                                   showsMonths: !bill.enabled, budgetTitle: bill.enabled ? "Sui mesi di competenza" : "Budget")
                        } else {
                            LabeledContent("Dagli altri risparmi", value: (Double(split.savings) / 100).euro).accessibilityIdentifier("expense-savings-preview")
                        }
                    }
                    } else if selected == NativeExpenseRouting.savings {
                        LabeledContent("Dai risparmi", value: (Double(amount) / 100).euro).accessibilityIdentifier("expense-direct-savings-preview")
                    } else if selected == NativeExpenseRouting.ordinary {
                        if offersSplit { NativeExpenseSplitRows(split: split, amount: amount, day: day) }
                        else if offersBillSplit {
                            // FUNDING-BLOCK: a bill without a plan, savings part and the rest on its competence months.
                            NativeExpenseSplitRows(split: split, amount: amount, day: day, showsMonths: false, budgetTitle: "Sui mesi di competenza")
                        }
                        else { LabeledContent(bill.enabled ? "Pagamento bancario" : "Dal budget mensile", value: (Double(amount) / 100).euro).accessibilityIdentifier("expense-budget-preview") }
                    } else { Text("Scegli il piano").font(NativeDesign.metadata) }
                }
            } header: {
                HStack {
                    Text("Da dove arrivano i soldi")
                    Spacer()
                    Text((Double(amount) / 100).euro).monospacedDigit().foregroundStyle(Color.primary)
                }
            }
            if bill.enabled { Section("Periodo di competenza") {
                // The competence months carry the bill minus the part kept on savings (same as the server).
                NativeUtilityPeriodFields(period: $bill, amountCents: max(1, amount - billSavingsPart))
            } }
        }.task(id: query) { await load() }
            .onChange(of: selected) { _, value in
                updateReady()
                if let plan = plans.first(where: { $0.text("id") == value }) { split.wrappedValue = NativeExpenseSplit(savings: NativeExpenseRouting.split(amount: amount, plan: plan).savings) }
                else if value == NativeExpenseRouting.ordinary { split.wrappedValue = NativeExpenseSplit() }
            }
            .onChange(of: bill) { _, value in
                if let months = value.months { competenceMonths = months.count }
                if value.enabled && selected == NativeExpenseRouting.savings { selected = NativeExpenseRouting.ordinary }
                updateReady()
            }
            .onChange(of: category + day) { _, _ in selected = ""; ready = false }
            .onChange(of: category) { _, _ in plans = []; selected = ""; ready = false }
    }
    /// Plan, savings and budget parts of the amount, as the selected destination pays it.
    private var funding: (plan: Int, savings: Int, budget: Int) {
        if let chosen, !chosen.flag("retained") {
            let split = NativeExpenseRouting.split(amount: amount, plan: chosen); return (split.fund, split.savings, 0)
        }
        if chosen != nil { return (amount, 0, 0) }
        if selected == NativeExpenseRouting.savings { return (0, amount, 0) }
        if offersSplit { let savings = min(split.wrappedValue.savings, amount); return (0, savings, amount - savings) }
        return (0, 0, amount)
    }
    private var fundingBar: some View {
        let parts = funding
        let euro: (Int) -> String = { (Double($0) / 100).euro }
        return LOSplitBar(segments: [
            LOSegment(id: "plan", value: Double(parts.plan), color: NativeDesign.financeGroups[1]),
            LOSegment(id: "savings", value: Double(parts.savings), color: NativeDesign.salaryGroups[1]),
            LOSegment(id: "budget", value: Double(parts.budget), color: NativeDesign.salaryGroups[3])
        ], scale: Double(max(amount, 1)), height: NativeDesign.Space.medium,
           accessibilityText: "Piano " + euro(parts.plan) + ", risparmi " + euro(parts.savings) + ", budget " + euro(parts.budget))
        .accessibilityIdentifier("expense-funding-bar")
    }
    private func updateReady() {
        bill.prepare(day: day, required: NativeUtilityPeriodDraft.categories.contains(category) || chosen?.text("kind") == "estimated" || bill.enabled)
        quotedAvailable = chosen.map(NativeExpenseRouting.available) ?? 0
        ready = !loading && issue == nil && (!bill.enabled || bill.months != nil) && (selected == NativeExpenseRouting.ordinary || (selected == NativeExpenseRouting.savings && offersSavings) || chosen != nil)
    }
    private func load() async {
        loading = true; ready = false; issue = nil
        do {
            try await Task.sleep(nanoseconds: NativeDesign.Motion.calendarDebounce)
            let rows: [Record]
            if store.isDemo {
                rows = NativeExpenseDemo.preview(state: store.state, category: category, day: day, movementID: movementID, bill: bill.enabled)
                savingsSupported = true
                splitSupported = true
                planSplitSupported = true
                billSavingsSupported = true
            } else {
                var payload: Record = ["category": .string(category), "date": .string(day), "amountCents": .int(max(1, amount))]
                if movementID > 0 { payload["movementId"] = .int(movementID) }
                if bill.enabled {
                    payload["competenceStartMonth"] = .string(bill.months == nil ? String(day.prefix(7)) : bill.start)
                    payload["competenceEndMonth"] = .string(bill.months == nil ? String(day.prefix(7)) : bill.end)
                }
                let result = try await store.read("getExpenseRouting", args: [.object(payload)]).object
                guard result.integer("version") == 1 else { throw NativeExpenseCapabilityError.routing }
                if NativeUtilityPeriodDraft.categories.contains(category) || bill.enabled {
                    guard result.integer("utilityCompetenceVersion") == 1 else { throw NativeExpenseCapabilityError.utilityCompetence }
                }
                if movementID > 0 && (result.integer("amountCents") != amount || result.text("date") != day || result.text("category") != category) { throw Message(text: "Il movimento è cambiato. Chiudi e riaprilo.") }
                rows = result.records("plans")
                savingsSupported = result.flag("savingsDestination")
                splitSupported = result.flag("splitDestination")
                planSplitSupported = result.flag("planSplitDestination")
                billSavingsSupported = result.flag("billSavingsDestination")
            }
            try Task.checkCancellation()
            plans = rows
            if selected.isEmpty { selected = NativeExpenseRouting.suggestion(rows) }
            // A plan payment starts with all the uncovered part on savings, as before.
            if let plan = rows.first(where: { $0.text("id") == selected }) { split.wrappedValue = NativeExpenseSplit(savings: NativeExpenseRouting.split(amount: amount, plan: plan).savings) }
            else if selected == NativeExpenseRouting.savings { if !offersSavings { selected = NativeExpenseRouting.suggestion(rows) } }
            else if selected != NativeExpenseRouting.ordinary && !rows.contains(where: { $0.text("id") == selected }) { selected = NativeExpenseRouting.suggestion(rows) }
            loading = false; updateReady()
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            loading = false; ready = false
            issue = NativeExpenseCapabilityError.message(for: error)
        }
    }
}

struct NativeExpenseDestinationEditor: View {
    @EnvironmentObject private var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let record: Record
    var onSaved: () -> Void
    @State private var selected = ""
    @State private var months = 1
    @State private var bill = NativeUtilityPeriodDraft()
    @State private var ready = false
    @State private var quotedAvailable = 0
    @State private var quoteGeneration = 0
    @State private var saving = false
    @State private var submitted = false
    @State private var requestID = UUID().uuidString
    @State private var issue: String?
    private var amount: Int { Int((abs(record.amount("amount")) * 100).rounded()) }
    var body: some View {
        Form {
            Section {
                LabeledContent(record.text("description", fallback: record.text("name")), value: (Double(amount) / 100).euro)
                Text("Modifica il periodo o la provenienza del pagamento. Il movimento bancario rimane unico.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
            }
            NativeExpenseRouteSection(category: record.text("category"), day: String(record.text("actual_date", fallback: record.text("date")).prefix(10)), amount: amount, movementID: record.integer("source_row") == 0 ? record.integer("row") : record.integer("source_row"), selected: $selected, competenceMonths: $months, ready: $ready, quotedAvailable: $quotedAvailable, bill: $bill).id(quoteGeneration).disabled(submitted)
            if let issue { NativeInlineMessage(text: issue) }
        }.modifier(NativeListAppearance()).navigationTitle(bill.enabled ? "Bolletta" : "Destinazione").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { NativeSheetCancel(title: "Chiudi") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { NativeSheetConfirm(title: "Conferma", retry: submitted) { Task { await save() } }.disabled(!ready || selected.isEmpty || saving).accessibilityIdentifier("expense-destination-confirm") }
            }
            .onAppear { months = NativeExpenseRouting.coveredMonths(record); bill = NativeUtilityPeriodDraft(record: record); selected = record.text("financePlanId").isEmpty ? NativeExpenseRouting.ordinary : record.text("financePlanId") }
    }
    private func save() async {
        saving = true; submitted = true; defer { saving = false }
        var payload = NativeExpenseRouting.destination(selected)
        payload["expectedAvailableCents"] = .int(quotedAvailable)
        payload["expectedAmountCents"] = .int(amount); payload["expectedCategory"] = record["category"]; payload["expectedDate"] = .string(String(record.text("actual_date", fallback: record.text("date")).prefix(10)))
        payload["requestId"] = .string(requestID); payload["expectedPaymentId"] = .string(record.text("financePlanPaymentId")); payload["movementId"] = .int(record.integer("source_row") == 0 ? record.integer("row") : record.integer("source_row")); payload["competenceMonths"] = .int(months)
        payload.merge(bill.payload) { _, value in value }
        if bill.enabled {
            let previous = NativeUtilityPeriodDraft(record: record)
            payload["expectedCompetenceStartMonth"] = .string(previous.start); payload["expectedCompetenceEndMonth"] = .string(previous.end)
        }
        do { try await store.perform(bill.enabled ? "changeUtilityBill" : "changeExpenseDestination", payload); onSaved(); dismiss() }
        catch {
            issue = error.localizedDescription
            if error is NativeRequestRejected, let status = try? await store.read("getExpenseRequestStatus", args: [.object(["requestId": .string(requestID)])]), !status.object.flag("started") {
                submitted = false; requestID = UUID().uuidString; quoteGeneration += 1
            }
        }
    }
}
