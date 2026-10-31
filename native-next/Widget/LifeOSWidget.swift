import SwiftUI
import WidgetKit

struct LifeOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeOSEntry { LifeOSEntry(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (LifeOSEntry) -> Void) {
        completion(LifeOSEntry(date: .now, snapshot: LifeOSWidgetStorage.read(directory: LifeOSWidgetStorage.container())))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeOSEntry>) -> Void) {
        let now = Date(), snapshot = LifeOSWidgetStorage.read(directory: LifeOSWidgetStorage.container())
        let dates = LifeOSWidgetStorage.timelineDates(now: now, snapshot: snapshot)
        completion(Timeline(entries: dates.map { LifeOSEntry(date: $0, snapshot: snapshot) }, policy: .after(now.addingTimeInterval(3600))))
    }
}
@main struct LifeOSOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LifeOSWidgetStorage.kind, provider: LifeOSProvider()) { entry in LifeOSWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget) }
            .configurationDisplayName("Life OS · Oggi")
            .description("Turni della settimana, abitudini, attività ed eventi. Aggiungi con +.")
            .supportedFamilies([.systemSmall])
    }
}
