import SwiftUI

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

/// Keeps every visited destination mounted in one SwiftUI hierarchy, so each
/// NavigationStack, scroll position and draft survives tab changes. There are no
/// nested hosting controllers: sheets, safe areas and keyboard state belong to the
/// single root, and the content closure is re-evaluated on every update.
/// Hidden destinations are removed from hit testing and accessibility.
struct NativeTabContainer: View {
    let selection: NativeTab
    let content: (NativeTab) -> AnyView
    @State private var visited: Set<NativeTab> = []

    var body: some View {
        ZStack {
            ForEach(NativeTab.allCases) { tab in
                if tab == selection || visited.contains(tab) {
                    content(tab)
                        .opacity(tab == selection ? 1 : 0)
                        .allowsHitTesting(tab == selection)
                        .accessibilityHidden(tab != selection)
                        .zIndex(tab == selection ? 1 : 0)
                }
            }
        }
        .onAppear { visited.insert(selection) }
        .onChange(of: selection) { _, current in visited.insert(current) }
    }
}
