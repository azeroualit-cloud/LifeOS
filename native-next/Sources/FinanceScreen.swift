import SwiftUI
import Charts

struct FinanceScreen: View {
    @EnvironmentObject var store: NativeStore
    @EnvironmentObject var router: NativeRouter
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var budgetAmountSize = NativeDesign.Layout.budgetAmount
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var search = ""
    @State private var account = "Tutti"
    @AppStorage("native-hide-money") private var hidden = false
    var body: some View {
        VStack(spacing: NativeDesign.Space.none) {
            HStack {
                Button { if router.tab == .finance { router.tab = .dashboard } else { dismiss() } } label: { Image(systemName: "chevron.left").frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget) }.accessibilityLabel("Torna alla Dashboard").accessibilityIdentifier("other-back")
                Text("Finanza").font(.largeTitle.bold()).lineLimit(1).minimumScaleFactor(0.75).accessibilityAddTraits(.isHeader).accessibilityIdentifier("finance-heading")
                Spacer()
                NativeToolbarButton(symbol: hidden ? "eye.slash" : "eye", label: hidden ? "Mostra importi" : "Nascondi importi") { hidden.toggle() }
                    .accessibilityIdentifier("finance-hide-amounts")
                NativeToolbarButton(symbol: "gearshape", label: "Impostazioni") { router.sheet = .settings }
                    .contextMenu { Button("Sincronizza", systemImage: "arrow.triangle.2.circlepath") { Task { await store.sync() } }.disabled(store.busy || store.syncing) }
            }.padding(.horizontal, NativeDesign.Layout.screenInset).padding(.top, NativeDesign.Space.small).padding(.bottom, NativeDesign.Space.large)
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                MonthControl(finance: true)
                NativeBudgetHero93(summary: store.summary, categories: monthCategories, month: store.financeMonth, hidden: hidden)
                accountCard
                actions
                recentMovements
                NativeSalaryMapCard(summary: store.summary, categories: monthCategories, hidden: hidden)
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
        // UX-REACH-01: the action used many times a day stays within thumb reach,
        // in Liquid Glass with no band behind it (UI-LOOK-92).
        .loBottomActions {
            Button { router.sheet = .movement([:]) } label: {
                LOActionLabel(title: "Aggiungi spesa", systemImage: "plus", section: .finance)
            }
            .buttonStyle(LOGlassButtonStyle(fillsWidth: true))
            .accessibilityIdentifier("primary-add")
        }
        }.background(NativeDesign.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { router.financeSection = "Panoramica" }
    }
    /// Spending by category in the selected month (server snapshot, else the month's movements).
    private var monthCategories: [Record] {
        if case .array(let rows)? = store.finance["categories"], !rows.isEmpty { return rows.map(\.object) }
        var totals: [String: Double] = [:]
        for row in store.transactions where row.amount("amount") < 0 && row.text("type") != "Entrata" {
            totals[row.text("displayCategory", fallback: row.text("category", fallback: "Altro")), default: 0] += -row.amount("amount")
        }
        return totals.map { ["name": .string($0.key), "amount": .number($0.value)] }
    }
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            LOSectionLabel(title: "Conto principale")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { accountName; Spacer(minLength: NativeDesign.Space.small); accountBalance }
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) { accountName; accountBalance }
            }
            .padding(NativeDesign.Layout.compactCardInset)
            .loCardSurface()
            if store.financeMonth != CivilDate.month() {
                Text("Saldo dell’ultima sincronizzazione").font(.caption).foregroundStyle(NativeDesign.secondary)
            }
        }
    }
    private var accountName: some View { Text(store.summary.text("account", fallback: "Trade Republic")).font(.headline) }
    private var accountBalance: some View {
        Text(hidden ? "•••• €" : presentation.balance.map(\.euro) ?? "Da aggiornare")
            .font(.headline).monospacedDigit().accessibilityIdentifier("finance-current-balance")
    }
    private var presentation: NativeFinanceOverview { NativeFinanceOverview(summary: store.summary, month: store.financeMonth) }
    // FINANCE-SCREEN-REDESIGN-2026-11-16: four visible actions of equal weight, no overflow menu.
    private var actions: some View {
        // Four fixed tiles in plain stacks: a lazy grid did not push «Movimenti» from its
        // second row with accessibility text (gate 91 run 43999971306).
        let spacing = NativeDesign.Space.small
        let budget = NavigationLink { NativePlansScreen().toolbar(.visible, for: .navigationBar) } label: { financeTile("Budget", symbol: "wallet.bifold") }.accessibilityIdentifier("finance-budget")
        let analysis = NavigationLink { FinanceAnalysisScreen().toolbar(.visible, for: .navigationBar) } label: { financeTile("Analisi", symbol: "chart.xyaxis.line") }.accessibilityIdentifier("finance-analysis")
        let plan = Button { router.sheet = .financePlan } label: { financeTile("Nuovo piano", symbol: "folder.badge.plus") }.accessibilityIdentifier("finance-new-plan")
        let all = NavigationLink {
            List { movements }.modifier(NativeListAppearance()).navigationTitle("Movimenti").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        } label: { financeTile("Movimenti", symbol: "list.bullet") }
            .accessibilityLabel("Mostra tutti i movimenti").accessibilityIdentifier("all-movements")
        // One compact row in a single card (mockup build 92): four equal shortcuts.
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: spacing) {
                    HStack(alignment: .top, spacing: spacing) { budget; analysis }
                    HStack(alignment: .top, spacing: spacing) { plan; all }
                }
            } else {
                HStack(alignment: .top, spacing: NativeDesign.Space.none) { budget; analysis; plan; all }
            }
        }.buttonStyle(.plain).foregroundStyle(Color.primary)
            .padding(NativeDesign.Space.xs)
            .loCardSurface()
    }
    private func financeTile(_ title: String, symbol: String) -> some View {
        VStack(spacing: NativeDesign.Space.xs) {
            Image(systemName: symbol).font(.title3.weight(.regular)).foregroundStyle(NativeDesign.financeTitle)
            Text(title).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.quickRow)
            .contentShape(Rectangle())
    }
    private var recentMovements: some View {
        let rows = Array(store.transactions.prefix(3))
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Ultimi movimenti").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                Text("Nessun movimento nel mese").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                LOListCard {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, record in
                        Button { router.sheet = .movement(record) } label: {
                            LOListRow(isLast: index == rows.count - 1) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: NativeDesign.Space.medium) {
                                        movementDescription(record)
                                        Spacer(minLength: NativeDesign.Space.small)
                                        movementAmount(record).fixedSize()
                                    }
                                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                                        movementDescription(record)
                                        movementAmount(record)
                                    }
                                }
                                .multilineTextAlignment(.leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NativePressStyle())
                    }
                }
            }
        }
    }
    private func movementDescription(_ record: Record) -> some View {
        HStack(spacing: NativeDesign.Space.medium) {
            Image(systemName: NativeCategoryCatalog.symbol(for: record.text("displayCategory", fallback: record.text("category"))))
                .font(.body).foregroundStyle(NativeDesign.financeTitle)
                .frame(width: NativeDesign.Layout.iconTile, height: NativeDesign.Layout.iconTile)
                .loTileSurface()
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
    @State private var bill = NativeUtilityPeriodDraft()
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
                        NativePlanPaymentDetail(planID: detail.text("financePlanId"), paymentID: detail.text("financePlanPaymentId"), onFinished: { dismiss() })
                    }.accessibilityIdentifier("movement-manage-plan-payment")
                }
            }
            Section {
                Picker("Tipo", selection: Binding(get: { type }, set: { value in
                    type = value
                    bill = NativeUtilityPeriodDraft()
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
                else { Picker("Categoria", selection: Binding(get: { category }, set: { category = $0; bill = NativeUtilityPeriodDraft() })) { ForEach(options, id: \.self) { Text($0) } }.accessibilityIdentifier("movement-category") }
            }.disabled(linkedPayment)
            if !editing && type == "Spesa" {
                NativeExpenseRouteSection(category: category, day: CivilDate.day(date), amount: Input.cents(amount) ?? 0, selected: $destination, competenceMonths: $months, ready: $routeReady, quotedAvailable: $quotedAvailable, bill: $bill)
            }
            if editing && type == "Spesa" && account == "Trade Republic" {
                Section("Destinazione") {
                    Text(detail.text("financePlanId").isEmpty ? "Budget mensile" : "Pagamento collegato a un piano").font(NativeDesign.body)
                    let period = NativeUtilityPeriodDraft(record: detail)
                    if period.enabled, period.months != nil { LabeledContent("Competenza", value: CivilDate.monthTitle(period.start) + " – " + CivilDate.monthTitle(period.end)) }
                    Button(NativeUtilityPeriodDraft.categories.contains(category) || !detail.text("utilityCompetenceStartMonth").isEmpty ? "Modifica periodo o destinazione" : "Cambia destinazione della spesa") { changingDestination = true }.accessibilityIdentifier("movement-change-destination")
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
        if store.isDemo { r = NativeUtilityDemo.enriched(r, state: store.state) }
        if store.isDemo, let payment = store.finance.record("plansV2").records("payments").first(where: { $0.integer("movementId") == r.integer("row") }) {
            r["financePlanId"] = payment["planId"]; r["financePlanPaymentId"] = payment["id"]; r["financePlanCompetenceMonths"] = payment["competenceMonths"]
        }
        included = !editing && r.flag("includedInSnapshot")
        detail = r; bill = NativeUtilityPeriodDraft(record: r); name = r.text("description", fallback: r.text("name")); amount = r.isEmpty ? "" : String(format: "%.2f", abs(r.amount("amount"))).replacingOccurrences(of: ".", with: ",")
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
            payload.merge(bill.payload) { _, value in value }
        }
        if treatment == "recovery" && type == "Spesa" {
            payload["recoveryMonths"] = .string(recovery)
            if !recoveryAmount.isEmpty { guard let recoverCents = Input.cents(recoveryAmount) else { error = "Importo di recupero non valido."; return }; payload["recoveryAmount"] = .number(Double(recoverCents) / 100) }
        }
        do { try await store.perform(editing ? "editMovement" : type == "Spesa" && bill.enabled ? "saveUtilityBill" : "saveTransaction", payload); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
