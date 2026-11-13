import SwiftUI
import UIKit

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
            items.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            items.background(.regularMaterial, in: Capsule())
        }
    }

    private var items: some View {
        HStack(spacing: NativeDesign.Space.none) {
            ForEach(NativeTab.allCases) { tab in
                Button {
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
        // Hosting controllers start a separate SwiftUI root. Forward the complete
        // inherited environment, including Dynamic Type, locale and accessibility.
        let inherited = context.environment
        controller.show(selection) { tab in
            AnyView(content(tab).environment(\.self, inherited))
        }
    }
}

final class NativeTabContainerController: UIViewController {
    private var hosts: [NativeTab: UIHostingController<AnyView>] = [:]
    private var selected: NativeTab?

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
    }

    func show(_ tab: NativeTab, content: (NativeTab) -> AnyView) {
        loadViewIfNeeded()
        for (key, host) in hosts { host.rootView = content(key) }
        guard selected != tab else { return }
        let forwardsAppearance = view.window != nil
        let old = selected.flatMap { hosts[$0] }
        if let old {
            if forwardsAppearance { old.beginAppearanceTransition(false, animated: false) }
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        let host: UIHostingController<AnyView>
        if let existing = hosts[tab] { host = existing }
        else {
            host = UIHostingController(rootView: content(tab))
            host.view.backgroundColor = .clear
            hosts[tab] = host
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

