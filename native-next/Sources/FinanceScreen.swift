import SwiftUI
import Charts

struct FinanceScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @ScaledMetric(relativeTo: .largeTitle) private var budgetAmountSize = NativeDesign.Layout.budgetAmount
    @State private var search = ""
    @State private var account = "Tutti"
    @AppStorage("native-hide-money") private var hidden = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.bottom) {
                VStack(spacing: NativeDesign.Space.none) { Divider(); MonthControl(finance: true).padding(.vertical, NativeDesign.Space.small); Divider() }
                balance
                actions
                recentMovements
                if !store.financialPending.isEmpty {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        Label("\(store.financialPending.count) movimenti salvati sul dispositivo", systemImage: "icloud.and.arrow.up").font(.subheadline)
                        Text("In attesa di sincronizzazione. Il saldo mostra l’ultimo dato del server.").font(.caption).foregroundStyle(NativeDesign.secondary)
                    }
                }
                NativeConnectionBadge()
            }.padding(.horizontal, NativeDesign.Layout.screenInset)
                .padding(.top, NativeDesign.Space.small).padding(.bottom, NativeDesign.Layout.scrollClearance)
        }.background(NativeDesign.canvas).scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("finance-scroll")
        .onAppear { router.financeSection = "Panoramica" }
    }
    private var balance: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                HStack {
                    Text("Budget rimanente").font(.title3).foregroundStyle(NativeDesign.secondary)
                    Spacer()
                    NativeIconButton(symbol: hidden ? "eye.slash" : "eye", label: hidden ? "Mostra importi" : "Nascondi importi") { hidden.toggle() }
                }
                Group {
                    if hidden { Text("•••• €") }
                    else if let remaining = presentation.remaining { Text(remaining.euro).modifier(NativeNumericFeedback(value: remaining)) }
                    else { Text("Da aggiornare") }
                }.font(NativeDesign.budgetValue(size: budgetAmountSize)).monospacedDigit()
                    .minimumScaleFactor(0.7).lineLimit(1).accessibilityIdentifier("finance-budget-value")
                if !hidden, presentation.remaining != nil {
                    if presentation.days > 0 {
                        Text(presentation.daily.euro + " al giorno").font(.title3.weight(.semibold)).monospacedDigit()
                    }
                    Text(presentation.periodLabel).font(.subheadline).foregroundStyle(NativeDesign.secondary)
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("budget-hero")
            Divider()
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                Text("CONTO PRINCIPALE").font(.caption.weight(.medium)).foregroundStyle(NativeDesign.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) { accountName; Spacer(minLength: NativeDesign.Space.small); accountBalance }
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) { accountName; accountBalance }
                }
                if store.financeMonth != CivilDate.month() {
                    Text("Saldo dell’ultima sincronizzazione, distinto dal mese selezionato.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
            }
            Divider()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, NativeDesign.Space.large)
    }
    private var accountName: some View { Text(store.summary.text("account", fallback: "Trade Republic")).font(.title3.weight(.semibold)) }
    private var accountBalance: some View {
        Text(hidden ? "•••• €" : presentation.balance.map(\.euro) ?? "Da aggiornare")
            .font(.title3.weight(.semibold)).monospacedDigit().accessibilityIdentifier("finance-current-balance")
    }
    private var presentation: NativeFinanceOverview { NativeFinanceOverview(summary: store.summary, month: store.financeMonth) }
    private var actions: some View {
        HStack(spacing: NativeDesign.Space.medium) {
            NavigationLink { NativePlansScreen() } label: { financePill("Budget", symbol: "wallet.bifold") }.accessibilityIdentifier("finance-budget")
            NavigationLink { FinanceAnalysisScreen() } label: { financePill("Analisi", symbol: "chart.xyaxis.line") }.accessibilityIdentifier("finance-analysis")
            Spacer(minLength: 0)
            Menu {
                Button("Nuovo piano", systemImage: "folder.badge.plus") { router.sheet = .financePlan }
                Button("Nuova spesa", systemImage: "minus.circle") { router.sheet = .movement([:]) }
            } label: {
                Image(systemName: "ellipsis").frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget).modifier(NativeGlass())
            }.accessibilityLabel("Altre azioni finanziarie").accessibilityIdentifier("finance-more")
        }.buttonStyle(.plain).foregroundStyle(Color.primary)
    }
    private func financePill(_ title: String, symbol: String) -> some View {
        HStack(spacing: NativeDesign.Space.small) {
            Image(systemName: symbol).font(.subheadline.weight(.regular))
            Text(title).font(.subheadline.weight(.medium))
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
        }.padding(.horizontal, NativeDesign.Space.large).frame(minHeight: NativeDesign.Layout.touchTarget)
            .modifier(NativeGlass()).contentShape(Capsule())
    }
    private var recentMovements: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
            NativeSectionHeader("Ultimi movimenti") {
                NavigationLink {
                    List { movements }.modifier(NativeListAppearance()).navigationTitle("Movimenti").navigationBarTitleDisplayMode(.inline)
                } label: { Text("Vedi tutti ›").foregroundStyle(Color.blue).font(.subheadline).frame(minHeight: NativeDesign.Layout.touchTarget) }
                    .accessibilityLabel("Mostra tutti i movimenti").accessibilityIdentifier("all-movements")
            }
            Divider()
            ForEach(store.transactions.prefix(3).map { DisplayRecord($0, key: "row") }) { item in
                Button { router.sheet = .movement(item.value) } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: NativeDesign.Space.medium) {
                            movementDescription(item.value)
                            Spacer(minLength: NativeDesign.Space.small)
                            movementAmount(item.value).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                            movementDescription(item.value)
                            movementAmount(item.value)
                        }
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                        .padding(.vertical, NativeDesign.Space.small).contentShape(Rectangle()).multilineTextAlignment(.leading)
                }.buttonStyle(NativePressStyle())
                Divider().padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.medium)
            }
            if store.transactions.isEmpty { Text("Nessun movimento nel mese").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
        }
    }
    private func movementDescription(_ record: Record) -> some View {
        HStack(spacing: NativeDesign.Space.medium) {
            Image(systemName: NativeCategoryCatalog.symbol(for: record.text("displayCategory", fallback: record.text("category"))))
                .font(.title3.weight(.regular)).foregroundStyle(Color.primary)
                .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                .background(NativeDesign.actionSurface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            NativeRowText(title: record.text("name"), subtitle: CivilDate.label(record.text("date")), titleLineLimit: 2)
        }
    }
    private func movementAmount(_ record: Record) -> some View {
        Text(hidden ? "••••" : record.amount("amount").euro).font(NativeDesign.body).monospacedDigit()
            .foregroundStyle(record.amount("amount") > 0 ? NativeDesign.financialGreen : Color.primary)
    }
    @ViewBuilder private var movements: some View {
        Section {
            TextField("Cerca movimento", text: $search)
            Picker("Conto", selection: $account) { ForEach(["Tutti", "Trade Republic", "Revolut", "IsyBank"], id: \.self) { Text($0) } }
        }
        if !store.financialPending.isEmpty {
            Section("Salvati sul dispositivo") {
                Button("Riprova invio") { Task { await store.sync(scope: .finance) } }.disabled(store.busy || store.syncing)
                ForEach(store.financialPending) { pending in
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                        HStack { VStack(alignment: .leading) { Text(pending.payload.text("name")); Text(pending.accepted ? "Inviato · aggiornamento da completare" : "Conferma del server in attesa").font(.caption).foregroundStyle(NativeDesign.secondary) }; Spacer(); MoneyText(amount: pending.payload.amount("amount")) }
                        if !pending.accepted && pending.payload.integer("expenseRoutingVersion") == 1 {
                            Button("Correggi destinazione") {
                                Task { do { try await store.cancelPendingExpense(pending.id); router.sheet = .movement(pending.payload) } catch { store.error = error.localizedDescription } }
                            }.disabled(store.busy || store.syncing)
                            Text("La correzione conserva i campi e si apre solo se il server non ha ancora iniziato il pagamento.").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                }
            }
        }
        let rows = store.transactions.filter { (account == "Tutti" || $0.text("account") == account) && (search.isEmpty || ($0.text("name") + $0.text("category")).localizedCaseInsensitiveContains(search)) }
        Section("Movimenti del mese") {
            if rows.isEmpty { Text("Nessun movimento").foregroundStyle(NativeDesign.secondary) }
            ForEach(rows.map { DisplayRecord($0, key: "row") }) { item in
                Button { router.sheet = .movement(item.value) } label: {
                    HStack(alignment: .top, spacing: NativeDesign.Space.medium) {
                        NativeIcon(name: NativeCategoryCatalog.symbol(for: item.value.text("displayCategory", fallback: item.value.text("category"))), color: NativeDesign.accent)
                        NativeRowText(title: item.value.text("name"), subtitle: item.value.text("displayCategory", fallback: item.value.text("category")) + " · " + CivilDate.label(item.value.text("date")))
                        Spacer(); MoneyText(amount: item.value.amount("amount")).foregroundStyle(Color.primary)
                    }.padding(.vertical, NativeDesign.Space.xs)
                }
            }
        }
    }

}
struct IndexedRecord: Identifiable { let index: Int; let value: Record; var id: Int { index } }
// Compatibility route: every Budget entry opens the same plan management screen.
struct BudgetDetail: View { var body: some View { NativePlansScreen() } }

struct NativeSavingsSection: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @AppStorage("native-hide-money") private var hidden = false
    var body: some View {
        Section("Obiettivo di risparmio") {
            let progress = NativeSavingsProgress(summary: store.summary, planning: store.finance.record("planning"))
            LabeledContent("Patrimonio totale", value: hidden ? "••••" : progress.assets.euro).accessibilityIdentifier("finance-total-assets")
            LabeledContent("Fondo emergenza", value: hidden ? "••••" : progress.emergency.euro)
            LabeledContent("Fondo emergenza coperto", value: hidden ? "••••" : progress.reserved.euro)
            LabeledContent("Altri risparmi", value: hidden ? "••••" : progress.other.euro)
            LabeledContent("Prossimo traguardo", value: hidden ? "••••" : progress.target.euro)
            LabeledContent("Manca", value: hidden ? "••••" : progress.missing.euro)
            LabeledContent("Da risparmiare al mese", value: hidden ? "••••" : progress.monthly.euro)
            Text("Cifra mancante divisa per \(progress.months) mesi fino a dicembre, incluso quello corrente.").font(.caption).foregroundStyle(NativeDesign.secondary)
            Button("Obiettivo e fondo emergenza") { router.sheet = .planning }
        }
    }
}

struct MovementEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let record: Record
    @State private var detail: Record = [:]
    @State private var destination = ""
    @State private var routeReady = false
    @State private var quotedAvailable = 0
    @State private var changingDestination = false
    private enum InputField { case amount, name, note }
    @FocusState private var editingInput: InputField?
    @State private var name = ""
    @State private var amount = ""
    @State private var type = "Spesa"
    @State private var account = "Trade Republic"
    @State private var category = "Altro"
    @State private var date = Date()
    @State private var note = ""
    @State private var counterpart = "Trade Republic"
    @State private var months = 1
    @State private var treatment = "ordinary"
    @State private var recovery = ""
    @State private var recoveryAmount = ""
    @State private var included = false
    @State private var saving = false
    @State private var loaded = false
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var requestID = UUID().uuidString
    private var linkedPayment: Bool { !detail.text("financePlanPaymentId").isEmpty }
    private var editing: Bool { record.integer("row") > 0 }
    private var options: [String] {
        NativeCategoryCatalog.choices(type: type, current: category)
    }
    private var snapshotChoice: Bool { NativeValidation.canIncludeInSnapshot(store.summary, account: account, type: type, day: CivilDate.day(date), editing: editing) }
    private var editorForm: some View {
        Form {
            if linkedPayment {
                Section {
                    Text("Questo movimento appartiene a un piano.")
                    NavigationLink("Gestisci pagamento collegato") {
                        NativePlanPaymentDetail(planID: detail.text("financePlanId"), paymentID: detail.text("financePlanPaymentId"), onDeleted: { dismiss() })
                    }.accessibilityIdentifier("movement-manage-plan-payment")
                }
            }
            Section {
                Picker("Tipo", selection: Binding(get: { type }, set: { value in
                    type = value
                    let choices = value == "Entrata" ? NativeCategoryCatalog.incomeChoices : Input.categories
                    if !choices.contains(category) { category = "Altro" }
                })) {
                    ForEach(editing ? ["Spesa", "Entrata", "Rimborso", "Trasferimento", "Investimento", "Da verificare"] : ["Spesa", "Entrata", "Rimborso", "Trasferimento"], id: \.self) { Text($0) }
                }
                TextField("Importo €", text: $amount).keyboardType(.decimalPad).focused($editingInput, equals: .amount).accessibilityIdentifier("movement-amount")
                TextField("Descrizione", text: $name).focused($editingInput, equals: .name).accessibilityIdentifier("movement-name")
                DatePicker("Data", selection: $date, in: ...Date(), displayedComponents: .date)
                if editing { Picker("Conto", selection: $account) { ForEach(["Trade Republic", "Revolut", "IsyBank"], id: \.self) { Text($0) } } }
                else { LabeledContent("Conto", value: type == "Trasferimento" ? "Revolut" : "Trade Republic") }
                if type == "Trasferimento" { Picker("Destinazione", selection: $counterpart) { ForEach(editing ? ["Trade Republic", "Revolut", "IsyBank"] : ["Trade Republic"], id: \.self) { Text($0) } } }
                else { Picker("Categoria", selection: $category) { ForEach(options, id: \.self) { Text($0) } }.accessibilityIdentifier("movement-category") }
            }.disabled(linkedPayment)
            if !editing && type == "Spesa" {
                NativeExpenseRouteSection(category: category, day: CivilDate.day(date), amount: Input.cents(amount) ?? 0, selected: $destination, competenceMonths: $months, ready: $routeReady, quotedAvailable: $quotedAvailable)
            }
            if editing && type == "Spesa" && account == "Trade Republic" {
                Section("Destinazione") {
                    Text(detail.text("financePlanId").isEmpty ? "Budget mensile" : "Pagamento collegato a un piano").font(NativeDesign.body)
                    Button("Cambia destinazione della spesa") { changingDestination = true }.accessibilityIdentifier("movement-change-destination")
                        .disabled(!destinationUnchanged)
                    if !destinationUnchanged { Text("Salva le modifiche al movimento prima di cambiare destinazione.").font(NativeDesign.metadata) }
                }
            }
            if snapshotChoice {
                Section {
                    Toggle("Già inclusa nel saldo rilevato", isOn: $included)
                    Text("Usa questa opzione solo se la banca aveva già contabilizzato il movimento nella rilevazione. Il server verifica la data.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }
            }
            Section("Note") { TextField("Note", text: $note, axis: .vertical).focused($editingInput, equals: .note).disabled(linkedPayment) }
            if let error { NativeInlineMessage(text: error) }
            if editing && !linkedPayment { Section { Button("Elimina movimento", role: .destructive) { confirmDelete = true }.disabled(saving || store.busy || !loaded) } }
        }
    }
    var body: some View {
        editorForm.modifier(NativeListAppearance()).navigationTitle(editing ? "Modifica movimento" : "Nuovo movimento").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); NativeIconButton(symbol: "keyboard.chevron.compact.down", label: "Nascondi tastiera") { editingInput = nil }.accessibilityIdentifier("movement-hide-keyboard") }

            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) { Button("Salva") { Task { await save() } }.disabled(linkedPayment || saving || store.busy || !loaded || (!editing && type == "Spesa" && (!routeReady || destination.isEmpty)) || Input.cents(amount) == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .confirmationDialog("Eliminare il movimento? Eventuali collegamenti finanziari saranno aggiornati dal server.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { Task { do { try await store.perform("deleteMovement", args: [.int(record.integer("row"))]); dismiss() } catch { self.error = error.localizedDescription } } }
        }
        .sheet(isPresented: $changingDestination) {
            NavigationStack { NativeExpenseDestinationEditor(record: detail) {
                Task { do { if store.isDemo { if let row = store.transactions.first(where: { $0.integer("row") == record.integer("row") }) { populate(row) } } else { let result = try await store.read("getMovement", args: [.int(record.integer("row"))]); populate(result.object) } } catch { self.error = error.localizedDescription } }
            } }
        }
        .onChange(of: snapshotChoice) { _, visible in if !visible { included = false } }
        .task {
            if editing && !store.isDemo {
                do { let r = try await store.read("getMovement", args: [.int(record.integer("row"))]); populate(r.object); loaded = true }
                catch { self.error = error.localizedDescription }
            } else { populate(record); loaded = true }
        }
    }
    private var destinationUnchanged: Bool {
        name == detail.text("description", fallback: detail.text("name")) && Input.cents(amount) == Int((abs(detail.amount("amount")) * 100).rounded()) && category == detail.text("category") && CivilDate.day(date) == String(detail.text("actual_date", fallback: detail.text("date")).prefix(10)) && note == detail.text("notes", fallback: detail.text("note"))
    }
    private func populate(_ value: Record) {
        var r = value
        if store.isDemo, let payment = store.finance.record("plansV2").records("payments").first(where: { $0.integer("movementId") == r.integer("row") }) {
            r["financePlanId"] = payment["planId"]; r["financePlanPaymentId"] = payment["id"]; r["financePlanCompetenceMonths"] = payment["competenceMonths"]
        }
        included = !editing && r.flag("includedInSnapshot")
        detail = r; name = r.text("description", fallback: r.text("name")); amount = r.isEmpty ? "" : String(format: "%.2f", abs(r.amount("amount"))).replacingOccurrences(of: ".", with: ",")
        type = r.text("movement_type", fallback: r.text("type", fallback: "Spesa"))
        if r.text("notes").hasPrefix("Rimborso / restituzione:") { type = "Rimborso" }
        account = r.text("account", fallback: "Trade Republic"); category = r.text("category", fallback: "Altro")
        date = CivilDate.date(r.text("actual_date", fallback: r.text("date", fallback: CivilDate.day())))
        note = r.text("notes", fallback: r.text("note")); months = NativeExpenseRouting.coveredMonths(r)
        treatment = editing ? r.text("budgetTreatment", fallback: "auto") : "ordinary"; recovery = r.text("recoveryMonths"); recoveryAmount = String(r.amount("recoveryAmount")); counterpart = r.text("counterparty_account", fallback: r.text("counterpart", fallback: "Trade Republic"))
    }
    private func save() async {
        guard let cents = Input.cents(amount) else { return }
        saving = true; defer { saving = false }
        var payload: Record = ["requestId": .string(requestID), "row": .int(record.integer("row")), "name": .string(name), "amount": .number(Double(cents) / 100), "type": .string(type),
            "account": .string(editing ? account : type == "Trasferimento" ? "Revolut" : "Trade Republic"), "category": .string(category), "date": .string(CivilDate.day(date)), "months": .int(months), "note": .string(note),
            "counterpart": .string(counterpart), "includedInSnapshot": .bool(included), "budgetTreatment": .string(type == "Spesa" ? treatment : "auto")]
        if !editing && type == "Spesa" {
            guard routeReady && !destination.isEmpty else { error = "Verifica la destinazione prima di salvare."; return }
            payload.merge(NativeExpenseRouting.destination(destination)) { _, new in new }
            payload["competenceMonths"] = .int(months)
            payload["expectedAvailableCents"] = .int(quotedAvailable)
        }
        if treatment == "recovery" && type == "Spesa" {
            payload["recoveryMonths"] = .string(recovery)
            if !recoveryAmount.isEmpty { guard let recoverCents = Input.cents(recoveryAmount) else { error = "Importo di recupero non valido."; return }; payload["recoveryAmount"] = .number(Double(recoverCents) / 100) }
        }
        do { try await store.perform(editing ? "editMovement" : "saveTransaction", payload); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
