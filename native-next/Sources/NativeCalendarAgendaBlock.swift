import SwiftUI

/// A long event stays compact; contained events remain independently tappable.
struct NativeCalendarAgendaBlock: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let node: NativeCalendarAgendaNode
    let onOpen: (NativeCalendarAgendaEntry) -> Void
    var depth = 0
    @ScaledMetric(relativeTo: .caption) private var timeColumn = NativeDesign.Layout.touchTarget
    private var entry: NativeCalendarAgendaEntry { node.entry }
    private var shift: ShiftKind? { entry.source == "shift" ? ShiftKind(rawValue: entry.record.text("kind")) : nil }
    private var color: Color { shift?.color ?? NativeCalendarEventStyle.color(for: entry) }
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NativeDesign.Space.xxs))
                : AnyLayout(HStackLayout(alignment: .center, spacing: NativeDesign.Space.small))
            layout {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(NativeCalendarTimeline.clock(entry.start)).fontWeight(.semibold)
                    if let end = entry.end {
                        Text(NativeCalendarTimeline.clock(end))
                            .accessibilityLabel("Fine " + NativeCalendarTimeline.clock(end))
                    }
                }
                .font(.caption).monospacedDigit().foregroundStyle(NativeDesign.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: typeSize.isAccessibilitySize ? nil : timeColumn, alignment: .leading)
                if entry.source == "shift" {
                    Label(entry.record.text("title"), systemImage: shift?.symbol ?? "calendar")
                        .font(.subheadline.weight(.medium)).foregroundStyle(color)
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                } else {
                    Button { onOpen(entry) } label: {
                        NativeCalendarAgendaTitle(entry: entry, color: color)
                            .padding(.leading, typeSize.isAccessibilitySize ? NativeDesign.Space.none : NativeDesign.Layout.agendaIndent * CGFloat(min(depth, 2)))
                            .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle()).accessibilityIdentifier("calendar-timeline-" + entry.id)
                        .accessibilityValue(entry.completed ? "Completata" : "Da completare")
                }
            }
            ForEach(node.children) { child in
                NativeCalendarAgendaBlock(node: child, onOpen: onOpen, depth: depth + 1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendar-agenda-block-" + entry.id)
    }
}

struct NativeCalendarAgendaTitle: View {
    let entry: NativeCalendarAgendaEntry
    let color: Color

    var body: some View {
        HStack(spacing: NativeDesign.Space.small) {
            if entry.completed {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(color)
                    .accessibilityHidden(true)
            } else {
                Circle().fill(color)
                    .frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                    .accessibilityHidden(true)
            }
            Text(entry.record.text("title"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(entry.completed ? NativeDesign.secondary : Color.primary)
                .strikethrough(entry.completed)
                .multilineTextAlignment(.leading)
        }
    }
}
