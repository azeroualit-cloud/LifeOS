import SwiftUI
import WidgetKit

enum LifeOSWidgetLayout {
    static let gap: CGFloat = 4
    static let tightGap: CGFloat = 3
    static let summaryGap: CGFloat = 6
    static let touchTarget: CGFloat = 44
    static let badgeHeight: CGFloat = 18
    static let badgeRadius: CGFloat = 3
}

struct LifeOSEntry: TimelineEntry {
    let date: Date
    let snapshot: LifeOSWidgetSnapshot?
}

struct LifeOSWidgetView: View {
    let entry: LifeOSEntry
    private func count(_ value: Int) -> String { value > 9 ? "9+" : String(value) }
    private var header: String {
        if entry.snapshot?.demo == true { return "Demo" }
        if let snapshot = entry.snapshot, snapshot.isStale(at: entry.date) {
            guard let updatedAt = snapshot.updatedAt else { return "Da aggiornare" }
            return "Agg. " + LifeOSWidgetCalendar.label(updatedAt, format: "d/M")
        }
        return LifeOSWidgetCalendar.label(entry.date, format: "EEE d").capitalized
    }
    private var week: [LifeOSWidgetDay] { entry.snapshot?.week(at: entry.date) ?? [] }
    var body: some View {
        ViewThatFits(in: .vertical) {
            content(showsNext: true)
            content(showsNext: false)
        }.privacySensitive().widgetURL(URL(string: "lifeos://calendar"))
    }
    private func content(showsNext: Bool) -> some View {
        VStack(alignment: .leading, spacing: LifeOSWidgetLayout.gap) {
            HStack(spacing: .zero) {
                Text(header)
                    .font(.caption.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 0)
                Link(destination: URL(string: "lifeos://task")!) {
                    Image(systemName: "plus.circle").font(.title3).frame(width: LifeOSWidgetLayout.touchTarget, height: LifeOSWidgetLayout.touchTarget).contentShape(Rectangle())
                }.accessibilityLabel("Aggiungi attività o evento").accessibilityIdentifier("widget-add")
            }
            if entry.snapshot?.ready == true && week.count >= 7 {
                HStack(spacing: LifeOSWidgetLayout.tightGap) {
                    ForEach(week) { item in
                        VStack(spacing: LifeOSWidgetLayout.tightGap) {
                            Text(String(LifeOSWidgetCalendar.label(LifeOSWidgetCalendar.date(item.day)!, format: "EEEEE").uppercased().prefix(1)))
                                .font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                            Text(LifeOSShiftPalette.letter(item.shift)).font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity).frame(height: LifeOSWidgetLayout.badgeHeight)
                                .foregroundStyle(item.shift == nil ? Color.secondary : Color.black.opacity(0.85))
                                .background(item.shift.map { LifeOSShiftPalette.color($0) } ?? Color.clear, in: RoundedRectangle(cornerRadius: LifeOSWidgetLayout.badgeRadius))
                        }.frame(maxWidth: .infinity)
                    }
                }.frame(minHeight: LifeOSWidgetLayout.touchTarget).accessibilityElement(children: .ignore)
                    .accessibilityLabel(week.map { $0.day + ": " + LifeOSShiftPalette.letter($0.shift) }.joined(separator: ", "))
                if let today = week.first {
                    HStack(spacing: LifeOSWidgetLayout.summaryGap) {
                        metric("\(count(today.checked))/\(count(today.routines))", symbol: "circle.dotted.circle", label: "Abitudini: \(today.checked) completate su \(today.routines)")
                        Spacer(minLength: 0)
                        metric(count(today.tasks), symbol: "checklist", label: "\(today.tasks) attività")
                        metric(count(today.events), symbol: "calendar", label: "\(today.events) eventi")
                    }.font(.caption2).monospacedDigit()

                    if showsNext && entry.snapshot?.isStale(at: entry.date) == true {
                        Text("Apri per aggiornare").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    } else if showsNext, let next = today.nextTitle, !next.isEmpty {
                        Text(next).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            } else {
                Text("Apri Life OS").font(.subheadline.weight(.medium))
                Text("Collega i dati del widget").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }
    private func metric(_ text: String, symbol: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
            Text(text).fixedSize(horizontal: true, vertical: false)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label)
    }

}
