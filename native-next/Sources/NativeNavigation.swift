import SwiftUI

/// Keep native tab geometry and Liquid Glass interaction under system control.
struct NativeTabBarAppearance: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.tabBarMinimizeBehavior(.never) }
        else { content }
    }
}

/// Use an explicit hit region and Apple's interactive material. The enclosing
/// ToolbarItem opts out of the shared bar-item capsule, which can clip touches.
struct NativeToolbarButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) { icon.glassEffect(.regular.interactive(), in: Circle()) }.buttonStyle(.plain)
                .accessibilityLabel(label)
        } else {
            Button(action: action) { icon.background(.thinMaterial, in: Circle()) }.buttonStyle(.plain)
                .accessibilityLabel(label)
        }
    }
    private var icon: some View {
        Image(systemName: symbol).font(NativeDesign.symbol)
            .symbolRenderingMode(.monochrome).foregroundStyle(NativeDesign.accent)
            .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
            .contentShape(Rectangle())
    }
}
