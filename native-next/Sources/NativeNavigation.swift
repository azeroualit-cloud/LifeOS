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
        Button(action: action) { NativeToolbarIcon(symbol: symbol) }.buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}

struct NativeToolbarIcon: View {
    let symbol: String
    var body: some View {
        materialIcon
            .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
            .contentShape(Rectangle())
    }
    @ViewBuilder private var materialIcon: some View {
        if #available(iOS 26.0, *) { icon.glassEffect(.regular.interactive(), in: Circle()) }
        else { icon.background(.thinMaterial, in: Circle()) }
    }
    private var icon: some View {
        NativeSymbol(symbol: symbol).font(NativeDesign.symbol)
            .symbolRenderingMode(.monochrome).foregroundStyle(NativeDesign.accent)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: NativeDesign.Layout.toolbarVisual, height: NativeDesign.Layout.toolbarVisual)
    }
}

/// Apple Health's apple.slice is a private asset on this runtime, not a public
/// SF Symbol. Draw an original fruit glyph instead of silently showing cutlery.
struct NativeSymbol: View {
    let symbol: String
    @ScaledMetric(relativeTo: .body) private var appleWidth = NativeDesign.Layout.nutritionGlyphWidth
    @ScaledMetric(relativeTo: .body) private var appleHeight = NativeDesign.Layout.nutritionGlyphHeight
    var body: some View {
        if symbol == "lifeos.nutrition.apple" {
            if UIImage(systemName: "apple.slice") != nil { Image(systemName: "apple.slice") }
            else {
                NativeNutritionAppleGlyph().stroke(style: StrokeStyle(lineWidth: NativeDesign.Layout.nutritionGlyphStroke, lineCap: .round, lineJoin: .round))
                    .frame(width: appleWidth, height: appleHeight)
            }
        } else { Image(systemName: symbol) }
    }
}

private struct NativeNutritionAppleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var p = Path()
        p.move(to: point(0.5, 0.29))
        p.addCurve(to: point(0.13, 0.31), control1: point(0.32, 0.16), control2: point(0.2, 0.2))
        p.addCurve(to: point(0.29, 0.94), control1: point(-0.05, 0.53), control2: point(0.11, 0.9))
        p.addCurve(to: point(0.5, 0.9), control1: point(0.38, 0.99), control2: point(0.43, 0.89))
        p.addCurve(to: point(0.71, 0.94), control1: point(0.57, 0.89), control2: point(0.62, 0.99))
        p.addCurve(to: point(0.87, 0.31), control1: point(0.89, 0.9), control2: point(1.05, 0.53))
        p.addCurve(to: point(0.5, 0.29), control1: point(0.8, 0.2), control2: point(0.68, 0.16))
        p.closeSubpath()
        p.move(to: point(0.5, 0.22))
        p.addCurve(to: point(0.76, 0.02), control1: point(0.52, 0.05), control2: point(0.65, 0.01))
        p.addCurve(to: point(0.5, 0.22), control1: point(0.75, 0.17), control2: point(0.64, 0.22))
        p.closeSubpath()
        p.move(to: point(0.39, 0.46))
        p.addQuadCurve(to: point(0.38, 0.68), control: point(0.33, 0.57))
        p.move(to: point(0.61, 0.46))
        p.addQuadCurve(to: point(0.62, 0.68), control: point(0.67, 0.57))
        return p
    }
}
