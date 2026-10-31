import SwiftUI

/// A long event stays compact; contained events remain independently tappable.
struct NativeCalendarAgendaBlock: View {
    let node: NativeCalendarAgendaNode
    let onOpen: (NativeCalendarAgendaEntry) -> Void
    var depth = 0
    private var entry: NativeCalendarAgendaEntry { node.entry }
    private var shift: ShiftKind? { entry.source == "shift" ? ShiftKind(rawValue: entry.record.text("kind")) : nil }
    private var color: Color { shift?.color ?? NativeDesign.calendarAccent }
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text(NativeCalendarTimeline.clock(entry.start)).font(.caption).monospacedDigit().foregroundStyle(color)
            if entry.source == "shift" {
                Label(entry.record.text("title"), systemImage: shift?.symbol ?? "calendar")
                    .font(.subheadline.weight(.medium)).foregroundStyle(color)
                    .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
            } else {
                Button { onOpen(entry) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                        if entry.completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(color) }
                        Text(entry.record.text("title")).font(.subheadline.weight(.medium))
                            .foregroundStyle(entry.completed ? NativeDesign.secondary : Color.primary).strikethrough(entry.completed)
                            .multilineTextAlignment(.leading)
                    }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("calendar-timeline-" + entry.id)
                    .accessibilityValue(entry.completed ? "Completata" : "Da completare")
            }
            if !node.children.isEmpty {
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    ForEach(node.children) { child in
                        NativeCalendarAgendaBlock(node: child, onOpen: onOpen, depth: depth + 1)
                    }
                }.padding(.leading, depth < 3 ? NativeDesign.Layout.agendaIndent : NativeDesign.Space.none)
            }
            if let end = entry.end {
                Text(NativeCalendarTimeline.clock(end)).font(.caption).monospacedDigit().foregroundStyle(color)
                    .accessibilityLabel("Fine " + NativeCalendarTimeline.clock(end))
            }
        }.padding(NativeDesign.Space.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shift == nil ? NativeDesign.actionSurface : color.opacity(0.10), in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: NativeDesign.progressRadius).fill(color.opacity(entry.completed ? 0.45 : 1)).frame(width: NativeDesign.Layout.calendarMarker) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendar-agenda-block-" + entry.id)
    }
}
