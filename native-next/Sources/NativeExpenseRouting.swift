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
    @State private var plans: [Record] = []
    @State private var loading = false
    @State private var issue: String?
    @State private var retry = 0
    private var query: String { category + day + String(movementID) + String(bill.enabled) + String(retry) }
    private var chosen: Record? { plans.first { $0.text("id") == selected } }
    var body: some View {
        Group {
            Section("Da dove viene pagata") {
                if loading { ProgressView("Verifico fondi e piani…") }
                if let issue {
                    NativeInlineMessage(text: issue)
                    Button("Riprova") { retry += 1 }
                } else {
                    Picker("Destinazione", selection: $selected) {
                        if selected.isEmpty { Text("Scegli un piano o il budget").tag("") }
                        Text("Budget mensile").tag(NativeExpenseRouting.ordinary)
                        ForEach(plans.indices, id: \.self) { index in Text("Piano · " + plans[index].text("name")).tag(plans[index].text("id")) }
                    }.accessibilityIdentifier("expense-destination")
                    if let chosen {
                    if chosen.flag("retained") {
                        Text("Mantieni il collegamento esistente. Cambiare il periodo non sposta denaro.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    } else {
                        let split = NativeExpenseRouting.split(amount: amount, plan: chosen)
                        LabeledContent("Dal fondo " + chosen.text("name"), value: (Double(split.fund) / 100).euro)
                        LabeledContent("Dagli altri risparmi", value: (Double(split.savings) / 100).euro).accessibilityIdentifier("expense-savings-preview")
                        Text("Il pagamento non viene sottratto di nuovo dal budget. Disponibilità verificata nuovamente al salvataggio.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    }
                    } else if selected == NativeExpenseRouting.ordinary {
                        LabeledContent(bill.enabled ? "Pagamento bancario" : "Dal budget mensile", value: (Double(amount) / 100).euro).accessibilityIdentifier("expense-budget-preview")
                        Text(plans.isEmpty ? "Nessun piano compatibile con questa categoria e data." : "Hai scelto di non usare il fondo del piano.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    } else { Text("Ci sono più piani compatibili: scegli quale utilizzare.").font(NativeDesign.metadata) }
                }
            }
            if bill.enabled { Section("Periodo di competenza") {
                NativeUtilityPeriodFields(period: $bill, amountCents: amount)
            } }
        }.task(id: query) { await load() }
            .onChange(of: selected) { _, _ in updateReady() }
            .onChange(of: bill) { _, value in
                if let months = value.months { competenceMonths = months.count }
                updateReady()
            }
            .onChange(of: category + day) { _, _ in selected = ""; ready = false }
            .onChange(of: category) { _, _ in plans = []; selected = ""; ready = false }
    }
    private func updateReady() {
        bill.prepare(day: day, required: NativeUtilityPeriodDraft.categories.contains(category) || chosen?.text("kind") == "estimated" || bill.enabled)
        quotedAvailable = chosen.map(NativeExpenseRouting.available) ?? 0
        ready = !loading && issue == nil && (!bill.enabled || bill.months != nil) && (selected == NativeExpenseRouting.ordinary || chosen != nil)
    }
    private func load() async {
        loading = true; ready = false; issue = nil
        do {
            try await Task.sleep(nanoseconds: NativeDesign.Motion.calendarDebounce)
            let rows: [Record]
            if store.isDemo {
                rows = NativeExpenseDemo.preview(state: store.state, category: category, day: day, movementID: movementID, bill: bill.enabled)
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
            }
            try Task.checkCancellation()
            plans = rows
            if selected.isEmpty { selected = NativeExpenseRouting.suggestion(rows) }
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
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button(submitted ? "Riprova" : "Conferma") { Task { await save() } }.disabled(!ready || selected.isEmpty || saving).accessibilityIdentifier("expense-destination-confirm") }
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
