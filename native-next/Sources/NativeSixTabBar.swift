import SwiftUI
import UIKit
import Combine

/// Six destinations remain visible even on compact iPhones; no More controller.
struct NativeSixTabBar: View {
    @Binding var selection: NativeTab
    var onReselect: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        bar
            .padding(.horizontal, NativeDesign.Space.small)
            .padding(.top, NativeDesign.Space.xs)
            .padding(.bottom, NativeDesign.Space.xs)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Navigazione principale")
            .accessibilityIdentifier("lifeos-main-tabs")
            .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder private var bar: some View {
        if #available(iOS 26.0, *) {
            // Keep one decorative glass surface; individual Buttons own taps.
            // This isolates whole-container interaction from six adjacent targets.
            items.glassEffect(.regular, in: Capsule())
        } else {
            items.background(.regularMaterial, in: Capsule())
        }
    }

    private var items: some View {
        HStack(spacing: NativeDesign.Space.none) {
            ForEach(NativeTab.allCases) { tab in
                Button {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--visual-test") {
                        print("NATIVE_TAB_ACTION target=\(tab.rawValue) previous=\(selection.rawValue)")
                    }
                    #endif
                    if selection == tab { onReselect() }
                    else { selection = tab }
                } label: {
                    VStack(spacing: NativeDesign.Space.xs) {
                        Image(systemName: tab.symbol)
                            .font(.body.weight(selection == tab ? .semibold : .regular))
                        if !typeSize.isAccessibilitySize {
                            Text(tab.title).font(.caption2)
                                .lineLimit(1).minimumScaleFactor(0.65)
                        }
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(selection == tab ? NativeDesign.accent : NativeDesign.secondary)
                    .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.tabHeight)
                    .contentShape(Rectangle())
                    .background {
                        if selection == tab {
                            Capsule().fill(NativeDesign.inset)
                                .padding(NativeDesign.Space.xs)
                        }
                    }
                    // Apply the interaction region to the completed label, after
                    // the conditional selected background, including blank gaps.
                    .contentShape(.interaction, Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("main-tab-" + String(tab.rawValue))
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
    }
}

/// Cache each navigation stack while forwarding real appearance lifecycles only
/// to the selected destination. Hidden screens do not remain mounted in a ZStack.
struct NativeTabContainer: UIViewControllerRepresentable {
    let selection: NativeTab
    let content: (NativeTab) -> AnyView

    func makeUIViewController(context: Context) -> NativeTabContainerController {
        NativeTabContainerController()
    }
    func updateUIViewController(_ controller: NativeTabContainerController, context: Context) {
        // Hosting roots inherit public display preferences, not the parent's
        // private presentation/dismiss context. Each host owns its own sheets.
        controller.show(selection, environment: context.environment, content: content)
    }
}

private struct NativeTabInheritedEnvironment: Equatable {
    let dynamicTypeSize: DynamicTypeSize
    let locale: Locale
    let layoutDirection: LayoutDirection
    let colorScheme: ColorScheme
    let calendar: Calendar
    let timeZone: TimeZone
    let forceReduceMotion: Bool

    init(_ environment: EnvironmentValues) {
        dynamicTypeSize = environment.dynamicTypeSize
        locale = environment.locale
        layoutDirection = environment.layoutDirection
        colorScheme = environment.colorScheme
        calendar = environment.calendar
        timeZone = environment.timeZone
        forceReduceMotion = environment.nativeForceReduceMotion
    }
}

private struct NativeTabPresentationSnapshot {
    let content: AnyView
    let environment: NativeTabInheritedEnvironment
}

/// Updating observable content preserves SwiftUI's presentation identity. The
/// hosting controller's root is installed only once, including while typing.
@MainActor private final class NativeTabPresentationModel: ObservableObject {
    @Published private(set) var snapshot: NativeTabPresentationSnapshot
    private var generation: UInt = 0

    init(snapshot: NativeTabPresentationSnapshot) { self.snapshot = snapshot }

    func update(_ next: NativeTabPresentationSnapshot) {
        // Even returning to the current value invalidates an older queued value:
        // A -> queued B -> A must not publish stale B on the next main turn.
        generation &+= 1
        guard next.environment != snapshot.environment else { return }
        let requestedGeneration = generation
        // Representable updates occur inside a SwiftUI render. Publish on the
        // next main turn, coalescing superseded environment/content snapshots.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == requestedGeneration else { return }
            self.snapshot = NativeTabPresentationSnapshot(content: self.snapshot.content, environment: next.environment)
        }
    }
}

@MainActor private struct NativeStableTabRoot: View {
    @ObservedObject var presentation: NativeTabPresentationModel

    var body: some View {
        // Never copy EnvironmentValues.self across hosting roots: it also
        // carries SwiftUI's private presentation/focus state. System read-only
        // accessibility preferences are resolved by each host from UIKit.
        presentation.snapshot.content
            .environment(\.dynamicTypeSize, presentation.snapshot.environment.dynamicTypeSize)
            .environment(\.locale, presentation.snapshot.environment.locale)
            .environment(\.layoutDirection, presentation.snapshot.environment.layoutDirection)
            .environment(\.colorScheme, presentation.snapshot.environment.colorScheme)
            .environment(\.calendar, presentation.snapshot.environment.calendar)
            .environment(\.timeZone, presentation.snapshot.environment.timeZone)
            .environment(\.nativeForceReduceMotion, presentation.snapshot.environment.forceReduceMotion)
    }
}

final class NativeTabContainerController: UIViewController {
    private struct Host {
        let controller: UIHostingController<NativeStableTabRoot>
        let presentation: NativeTabPresentationModel
    }
    private var hosts: [NativeTab: Host] = [:]
    private var selected: NativeTab?

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
    }

    func show(_ tab: NativeTab, environment: EnvironmentValues, content: (NativeTab) -> AnyView) {
        loadViewIfNeeded()
        let inherited = NativeTabInheritedEnvironment(environment)
        for (key, host) in hosts {
            host.presentation.update(NativeTabPresentationSnapshot(content: content(key), environment: inherited))
        }
        guard selected != tab else { return }
        let forwardsAppearance = view.window != nil
        let old = selected.flatMap { hosts[$0]?.controller }
        if let old {
            if forwardsAppearance { old.beginAppearanceTransition(false, animated: false) }
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        let host: UIHostingController<NativeStableTabRoot>
        if let existing = hosts[tab] { host = existing.controller }
        else {
            let presentation = NativeTabPresentationModel(snapshot: NativeTabPresentationSnapshot(content: content(tab), environment: inherited))
            host = UIHostingController(rootView: NativeStableTabRoot(presentation: presentation))
            host.view.backgroundColor = .clear
            hosts[tab] = Host(controller: host, presentation: presentation)
        }
        selected = tab
        addChild(host)
        if forwardsAppearance { host.beginAppearanceTransition(true, animated: false) }
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        if forwardsAppearance {
            old?.endAppearanceTransition()
            host.endAppearanceTransition()
        }
    }
}
