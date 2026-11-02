import SwiftUI

struct NativeUtilityPeriodFields: View {
    @Binding var period: NativeUtilityPeriodDraft
    let amountCents: Int
    var body: some View {
        NativeUtilityMonthPicker(title: "Mese iniziale", selection: $period.start)
            .accessibilityIdentifier("utility-period-start")
        NativeUtilityMonthPicker(title: "Mese finale", selection: $period.end)
            .accessibilityIdentifier("utility-period-end")
        if period.months == nil {
            Text("Scegli un periodo da 1 a 12 mesi, con la fine successiva o uguale all’inizio.")
                .font(NativeDesign.metadata).foregroundStyle(NativeDesign.warning)
        } else {
            ForEach(period.shares(amountCents)) { share in
                LabeledContent(CivilDate.monthTitle(share.month), value: (Double(share.cents) / 100).euro)
                    .accessibilityIdentifier("utility-share-" + share.month)
            }
            Text("Le quote sostituiscono le stime nei mesi indicati, anche passati. Il pagamento resta un’unica uscita alla data effettiva; gli accantonamenti del fondo rimangono separati.")
                .font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
        }
    }
}

private struct NativeUtilityMonthPicker: View {
    let title: String
    @Binding var selection: String
    private var month: Binding<Int> {
        Binding(get: { Int(selection.suffix(2)) ?? 1 }, set: { selection = String(selection.prefix(4)) + String(format: "-%02d", $0) })
    }
    private var year: Binding<Int> {
        Binding(get: { Int(selection.prefix(4)) ?? 2026 }, set: { selection = String($0) + "-" + String(selection.suffix(2)) })
    }
    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: NativeDesign.Space.small)
            Picker("Mese · " + title, selection: month) {
                ForEach(1...12, id: \.self) { value in
                    Text(CivilDate.monthTitle(String(format: "2026-%02d", value)).components(separatedBy: " ")[0]).tag(value)
                }
            }.labelsHidden().pickerStyle(.menu).accessibilityIdentifier("utility-month-" + title)
            Picker("Anno · " + title, selection: year) {
                ForEach(2000...2099, id: \.self) { Text(String($0)).tag($0) }
            }.labelsHidden().pickerStyle(.menu).accessibilityIdentifier("utility-year-" + title)
        }
    }
}
