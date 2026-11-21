import SwiftUI

// Bars and steppers of the build 93 preview (golden-ratio sizes: 5, 8, 13, 21 pt).

/// Thin rounded bar: `value` over `total`, coloured fill on the neutral track.
/// Beyond the total the fill turns orange and stays full.
struct LOProgressBar: View {
    let value: Double
    let total: Double?
    var color: Color = .primary
    var height: CGFloat = NativeDesign.Space.small

    var body: some View {
        let fraction = total.map { $0 > 0 ? value / $0 : 0 } ?? 0
        let over = fraction > 1
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(NativeDesign.barTrack)
                Capsule().fill(over ? NativeDesign.overGoal : color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// One horizontal bar split into coloured parts (calories by macro, budget by group).
/// The parts are proportional to `scale`; the rest of the bar stays track.
struct LOSegment: Identifiable {
    let id: String
    let value: Double
    let color: Color
}

struct LOSplitBar: View {
    let segments: [LOSegment]
    let scale: Double
    var height: CGFloat = NativeDesign.Space.xLarge
    var accessibilityText: String

    var body: some View {
        let total = segments.map(\.value).reduce(0, +)
        let shown = scale > 0 ? min(total / scale, 1) : 0
        GeometryReader { proxy in
            let width = proxy.size.width * shown
            let gaps = CGFloat(max(segments.filter { $0.value > 0 }.count - 1, 0)) * NativeDesign.Space.xxs
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous).fill(NativeDesign.barTrack)
                HStack(spacing: NativeDesign.Space.xxs) {
                    ForEach(segments.filter { $0.value > 0 }) { segment in
                        Rectangle().fill(segment.color)
                            .frame(width: total > 0 ? max(0, (width - gaps) * segment.value / total) : 0)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }
}

/// Macro value with its goal and a 5 pt bar under it: "P 151 / 160 g".
struct LOMacroValue: View {
    let title: String
    let value: Double?
    let goal: Double?
    let unit: String
    let color: Color
    var identifier: String

    var body: some View {
        let shown: String = value.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—"
        let goalText: String? = goal.map { $0.formatted(.number.precision(.fractionLength(0))) }
        let suffix: String = goalText.map { "/ " + $0 + " " + unit } ?? unit
        var spoken: String = title + ", " + (value == nil ? "nessun dato" : shown + " " + unit)
        if let goalText { spoken += " di " + goalText }
        return VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            Text(title).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                Text(shown).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(suffix)
                    .font(.footnote).foregroundStyle(NativeDesign.secondary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            }
            // Without a goal the track stays empty: a full bar would suggest a target met.
            LOProgressBar(value: value ?? 0, total: goal, color: color, height: NativeDesign.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }
}

/// "Label    −  value  +" row with two 44 pt glass buttons (preview `.step`).
struct LOStepperRow: View {
    let title: String
    let value: String
    var detail: String? = nil
    let decrement: (() -> Void)?
    let increment: (() -> Void)?
    var identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.small))
            : AnyLayout(HStackLayout(spacing: NativeDesign.Space.small))
        layout {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(title).font(.body)
                if let detail { Text(detail).font(.footnote).foregroundStyle(NativeDesign.secondary) }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: NativeDesign.Space.small) }
            HStack(spacing: NativeDesign.Space.small) {
                stepButton("minus", label: "Meno " + title.lowercased(), action: decrement)
                    .accessibilityIdentifier(identifier + "-minus")
                Text(value).font(.body.weight(.semibold)).monospacedDigit()
                    .frame(minWidth: NativeDesign.Layout.categoryWidth)
                    .accessibilityIdentifier(identifier + "-value")
                stepButton("plus", label: "Più " + title.lowercased(), action: increment)
                    .accessibilityIdentifier(identifier + "-plus")
            }
        }
        .frame(minHeight: NativeDesign.Layout.rowHeight)
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, label: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                .contentShape(Circle())
                .modifier(NativeGlass())
        }
        .buttonStyle(NativePressStyle())
        .disabled(action == nil)
        .accessibilityLabel(label)
    }
}

/// Section title of grouped content: "CALORIE", "MACRO", "DIARIO" (footnote, caps).
struct LOSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.footnote).foregroundStyle(NativeDesign.secondary)
            .padding(.horizontal, NativeDesign.Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Grouped list card: rows separated by hairlines, 21 pt corners (preview `.list`).
struct LOListCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: NativeDesign.Space.none) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
    }
}

/// One row inside LOListCard: 55 pt minimum, 16 pt sides, hairline below unless last.
struct LOListRow<Content: View>: View {
    var isLast = false
    var leadingInset: CGFloat = NativeDesign.Space.large
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: NativeDesign.Space.medium) { content() }
            .padding(.horizontal, NativeDesign.Space.large)
            .padding(.vertical, NativeDesign.Space.small)
            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.rowHeight, alignment: .leading)
            .overlay(alignment: .bottom) {
                if !isLast { Divider().padding(.leading, leadingInset) }
            }
    }
}

/// Small value card of the "Andamento" grid: coloured title, 22 pt value, unit, caption.
/// Padding 13 x 21 as the preview. Tappable when `action` is set.
struct LOStatCard: View {
    let title: String
    let value: String
    let unit: String
    var caption: String? = nil
    var color: Color = .primary
    var identifier: String
    var accessibilityHint: String? = nil
    var action: (() -> Void)? = nil

    private var spoken: String {
        var text: String = title + ", " + value
        if !unit.isEmpty { text += " " + unit }
        if let caption { text += ", " + caption }
        return text
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            HStack {
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(color).lineLimit(1)
                Spacer(minLength: NativeDesign.Space.xs)
                if action != nil { NativeDisclosureIndicator() }
            }
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                Text(value).font(.title2.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(1)
            }
            if let caption { Text(caption).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(1) }
        }
        .padding(.vertical, NativeDesign.Space.medium)
        .padding(.horizontal, NativeDesign.Space.xLarge)
        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
        .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
        .contentShape(Rectangle())
        if let action {
            Button(action: action) { content }
                .buttonStyle(NativePressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
                .accessibilityHint(accessibilityHint ?? "Apre il dettaglio")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(identifier)
        } else {
            content.accessibilityElement(children: .ignore).accessibilityLabel(spoken).accessibilityIdentifier(identifier)
        }
    }
}

/// Tappable card with a coloured header (title, optional trailing text, chevron) and content.
/// Used where the whole card opens a detail (Peso e simulazione, Calorie per giorno).
struct LOLinkCard<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var color: Color = .primary
    var identifier: String
    var accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                    Text(title).font(.headline).foregroundStyle(color)
                    Spacer(minLength: NativeDesign.Space.small)
                    if let trailing { Text(trailing).font(.subheadline).foregroundStyle(NativeDesign.secondary).monospacedDigit() }
                    NativeDisclosureIndicator()
                }
                content()
            }
            .padding(NativeDesign.Layout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Apre il dettaglio")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// Tappable stacked columns (Cronologia): each column is bottom-up segments, an
/// optional dashed goal line across, the selected column fully opaque.
struct LOStackedColumn: Identifiable {
    let id: String
    let label: String
    let segments: [LOSegment]
    let accessibilityLabel: String
    var total: Double { segments.map(\.value).reduce(0, +) }
}

struct LOStackedColumns: View {
    let columns: [LOStackedColumn]
    var goal: Double? = nil
    @Binding var selection: String?
    var height: CGFloat = NativeDesign.Layout.healthChartHeight * 0.7
    var identifierPrefix = "column-"

    var body: some View {
        let top = max(goal ?? 0, columns.map(\.total).max() ?? 0, 1) * 1.06
        let gap = columns.count > 6 ? NativeDesign.Space.small : NativeDesign.Space.medium
        VStack(spacing: NativeDesign.Space.xs) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(columns) { column in
                        let selected = selection == column.id
                        let over = goal.map { column.total > $0 } ?? false
                        Button { selection = column.id } label: {
                            VStack(spacing: NativeDesign.Space.xxs) {
                                if column.total <= 0 {
                                    Capsule().fill(NativeDesign.barTrack).frame(height: NativeDesign.Space.xs)
                                } else {
                                    ForEach(column.segments.reversed()) { segment in
                                        Rectangle().fill(segment.color)
                                            .frame(height: max(0, height * segment.value / top))
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous))
                            .overlay {
                                if over && selected {
                                    RoundedRectangle(cornerRadius: NativeDesign.Space.small, style: .continuous)
                                        .strokeBorder(NativeDesign.overGoal, lineWidth: NativeDesign.Layout.selectionLine)
                                }
                            }
                            .opacity(selected || selection == nil ? 1 : 0.62)
                            .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NativePressStyle())
                        .accessibilityLabel(column.accessibilityLabel)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier(identifierPrefix + column.id)
                    }
                }
                if let goal, goal > 0 {
                    Line().stroke(Color.primary.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(height: 1)
                        .offset(y: -height * goal / top)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: height, alignment: .bottom)
            HStack(spacing: gap) {
                ForEach(columns) { column in
                    Text(column.label).font(.caption).monospacedDigit()
                        .foregroundStyle(selection == column.id ? Color.primary : NativeDesign.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return path
        }
    }
}

extension View {
    /// Hairline under a row of a grouped card, inset like iOS lists; none after the last row.
    func loRowSeparator(hidden: Bool, leadingInset: CGFloat = NativeDesign.Space.large) -> some View {
        overlay(alignment: .bottom) {
            if !hidden { Divider().padding(.leading, leadingInset) }
        }
    }
}
