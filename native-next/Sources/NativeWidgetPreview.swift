#if DEBUG
import SwiftUI

/// Runs the same read-only view shipped in the extension, using explicit demo fixtures.
struct NativeWidgetPreview: View {
    private var snapshot: LifeOSWidgetSnapshot {
        let now = Date(), today = CivilDate.day(now)
        var life = DemoData.make().life
        life["shifts"] = .array((0..<14).map { offset in
            .object(["day": .string(CivilDate.adding(offset, to: today)), "kind": .string(["morning", "morning", "afternoon", "afternoon", "night", "rest", "holiday"][offset % 7])])
        })
        return NativeWidgetBridge.snapshot(life: life, demo: true, now: now)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NativeDesign.Space.section) {
                    preview(size: 170).accessibilityIdentifier("widget-preview-small")
                    preview(size: 141).accessibilityIdentifier("widget-preview-compact")
                }.padding(NativeDesign.Space.large)
            }.background(NativeDesign.canvas).navigationTitle("Anteprima widget")
        }.preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : .light)
    }
    private func preview(size: CGFloat) -> some View {
        LifeOSWidgetView(entry: LifeOSEntry(date: Date(), snapshot: snapshot))
            .padding(NativeDesign.Space.large).frame(width: size, height: size)
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius))
            .accessibilityElement(children: .contain)
    }
}
#endif
