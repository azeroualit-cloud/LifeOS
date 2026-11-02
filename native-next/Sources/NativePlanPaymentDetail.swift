import SwiftUI

struct NativePlanPaymentDetail: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let planID: String
    let paymentID: String
    var onFinished: (() -> Void)? = nil
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var error: String?
    @State private var requestID = UUID().uuidString
    @State private var billRecord: Record = [:]
    @State private var editingBill = false
    @State private var loadingBill = false
    private var payment: Record { store.finance.record("plansV2").records("payments").first { $0.text("id") == paymentID } ?? [:] }
    var body: some View {
        List {
            if !payment.isEmpty {
                Section {
                    LabeledContent("Importo", value: (Double(payment.integer("amountCents")) / 100).euro)
                    LabeledContent("Data", value: CivilDate.label(payment.text("date")))
                    Text("Pagamento collegato al piano. Puoi eliminarlo anche se il piano è interrotto.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
                if !payment.record("utilityPeriod").isEmpty || NativeUtilityPeriodDraft.isCostFund(store.finance.record("plansV2").records("plans").first(where: { $0.text("id") == planID }) ?? [:]) {
                    Section("Periodo della bolletta") {
                        let period = NativeUtilityPeriodDraft(record: payment)
                        if period.enabled {
                            LabeledContent("Da", value: CivilDate.monthTitle(period.start))
                            LabeledContent("A", value: CivilDate.monthTitle(period.end))
                        } else { Text("Periodo non ancora attribuito").foregroundStyle(NativeDesign.secondary) }
                        Button("Modifica periodo") { Task { await openBill() } }
                            .disabled(loadingBill || payment.text("status") != "posted")
                            .accessibilityIdentifier("plan-payment-edit-period")
                        if loadingBill { ProgressView() }
                    }
                }
                Section {
                    Button(payment.text("status") == "deleting" ? "Completa l’eliminazione" : "Elimina pagamento e movimento", role: .destructive) {
                        confirmDelete = true
                    }.disabled(deleting || store.busy || payment.text("status") == "pending").accessibilityIdentifier("plan-payment-delete")
                }
            } else { Text("Pagamento non disponibile. Aggiorna i piani.") }
            if let error { NativeInlineMessage(text: error) }
        }.modifier(NativeListAppearance()).navigationTitle("Pagamento del piano").navigationBarTitleDisplayMode(.inline)
            .task { await store.loadFinancePlans() }
            .sheet(isPresented: $editingBill) {
                NavigationStack { NativeExpenseDestinationEditor(record: billRecord) {
                    Task { await store.loadFinancePlans(); if let onFinished { onFinished() } else { dismiss() } }
                } }
            }
            .confirmationDialog("Eliminare questo pagamento e il movimento collegato? Il saldo verrà aggiornato. Il piano interrotto resterà interrotto; un obiettivo chiuso tornerà aperto.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Elimina pagamento", role: .destructive) { Task { await remove() } }
            }
    }
    @MainActor private func openBill() async {
        loadingBill = true; defer { loadingBill = false }
        do {
            if store.isDemo {
                guard var row = store.finance.records("transactions").first(where: { $0.integer("row") == payment.integer("movementId") }) else { throw Message(text: "Movimento non disponibile.") }
                row["financePlanId"] = .string(planID); row["financePlanPaymentId"] = .string(paymentID)
                row["utilityPeriod"] = payment["utilityPeriod"]; billRecord = row
            } else { billRecord = try await store.read("getMovement", args: [.int(payment.integer("movementId"))]).object }
            editingBill = true
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func remove() async {
        guard !deleting else { return }
        deleting = true; defer { deleting = false }
        do {
            if payment.text("status") == "deleting" {
                try await store.perform("resumeFinancePlanPayment", ["paymentId": .string(paymentID)])
            } else {
                try await store.perform("deleteFinancePlanPayment", ["requestId": .string(requestID), "planId": .string(planID), "paymentId": .string(paymentID)])
            }
            await store.loadFinancePlans()
            if let onFinished { onFinished() } else { dismiss() }
        } catch { self.error = error.localizedDescription }
    }
}
