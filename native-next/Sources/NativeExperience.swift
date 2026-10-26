import SwiftUI

struct NativeShiftBadge: View {
    let shift: ShiftKind?
    var body: some View {
        Text(shift?.letter ?? " ").font(.caption2.weight(.bold))
            .foregroundStyle(shift == .night ? Color.black : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 20)
            .background(shift?.color ?? Color.clear, in: RoundedRectangle(cornerRadius: NativeDesign.badgeRadius))
            .padding(.horizontal, NativeDesign.Space.xs).accessibilityLabel(shift?.title ?? "Nessun turno")
    }
}
struct NativeDueBadge: View {
    let day: String
    private var title: String {
        if day == CivilDate.day() { return "Oggi" }
        if day == CivilDate.adding(1, to: CivilDate.day()) { return "Domani" }
        if day < CivilDate.day() { return "Scaduta · " + CivilDate.label(day) }
        return CivilDate.label(day)
    }
    private var urgent: Bool { day <= CivilDate.adding(1, to: CivilDate.day()) }
    var body: some View {
        NativeStatusBadge(title: title, symbol: urgent ? "exclamationmark.circle" : "calendar", tone: urgent ? .warning : .neutral)
    }
}
struct NativeCategoryChart: View {
    let rows: [Record]
    private func color(_ name: String) -> Color {
        // Explicit exception for category composition: the ring and its legend use
        // the same distinct swatches. Financial direction keeps its existing colours.
        if name == "Altre categorie" { return Color.secondary }
        let palette: [Color] = [.blue, .orange, .teal, .purple, .pink, .indigo]
        let rank = compact.firstIndex { $0.text("name") == name } ?? 0
        return palette[rank % palette.count]
    }

    private var compact: [Record] {
        if rows.count <= 6 { return rows }
        return Array(rows.prefix(5)) + [["name": .string("Altre categorie"), "amount": .number(rows.dropFirst(5).reduce(0) { $0 + $1.amount("amount") })]]
    }
    var body: some View {
        let total = rows.reduce(0) { $0 + $1.amount("amount") }
        HStack(spacing: NativeDesign.Space.large) {
            ZStack {
                ForEach(Array(compact.enumerated()), id: \.offset) { index, row in
                    let start = compact.prefix(index).reduce(0) { $0 + $1.amount("amount") } / max(Double.leastNonzeroMagnitude, total)
                    Circle().trim(from: start, to: min(1, start + row.amount("amount") / max(Double.leastNonzeroMagnitude, total)))
                        .stroke(color(row.text("name")), style: StrokeStyle(lineWidth: 18, lineCap: .butt)).rotationEffect(.degrees(-90))
                }
                Text(total.euro).font(.caption.weight(.semibold)).minimumScaleFactor(0.5).lineLimit(1).padding(NativeDesign.Space.medium)
            }.frame(width: 108, height: 108).padding(NativeDesign.Space.small).accessibilityLabel("Spese totali " + total.euro)
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                ForEach(Array(compact.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                        Circle().fill(color(row.text("name"))).frame(width: 6, height: 6)
                        Text(row.text("name")).lineLimit(2)
                        Spacer(minLength: 2)
                        Text("\(Int((row.amount("amount") / max(Double.leastNonzeroMagnitude, total) * 100).rounded()))%").monospacedDigit()
                    }.font(.caption2)
                }
            }.frame(maxWidth: .infinity)
        }.padding(.vertical, NativeDesign.Space.small)
        DisclosureGroup("Tutte le categorie") {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LabeledContent {
                    Text(row.amount("amount").euro).monospacedDigit()
                } label: {
                    HStack(spacing: NativeDesign.Space.small) {
                        Circle().fill(compact.contains { $0.text("name") == row.text("name") } ? color(row.text("name")) : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(row.text("name"))
                    }
                }.font(.subheadline)
            }
        }.font(.subheadline)
    }
}
