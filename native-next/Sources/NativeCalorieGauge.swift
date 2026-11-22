import SwiftUI

/// Where the day's calories sit against the goal (Fitia-like card, user request 22/11/2026).
/// The goal band is ±10 % of the target; the scale runs to 130 % of it.
enum NativeCalorieBand: Equatable {
    case none, under, within, over

    static func of(_ calories: Double?, goal: Double?) -> NativeCalorieBand {
        guard let calories, calories > 0 else { return .none }
        guard let goal, goal > 0 else { return .within }
        if calories < goal * 0.9 { return .under }
        if calories > goal * 1.1 { return .over }
        return .within
    }
    var color: Color {
        switch self {
        case .none: Color(uiColor: .tertiaryLabel)
        case .under: NativeDesign.nutritionTitle.opacity(0.55)
        case .within: NativeDesign.nutritionTitle
        case .over: NativeDesign.overGoal
        }
    }
    static let scale = 1.3
    static func fraction(_ value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value / (goal * scale), 0), 1)
    }
}

/// Shallow arc used as the calorie track; its top touches the frame's top edge.
private struct NativeCalorieArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return path
    }
}

/// Arc gauge: grey track, the goal band as a lighter stretch of the arc, the eaten calories
/// as a gradient stroke ending in a knob (a check inside the band), band limits underneath.
struct NativeCalorieGauge: View {
    let calories: Double?
    let goal: Double?
    private let lineWidth: CGFloat = 10
    private let knob: CGFloat = 20

    var body: some View {
        let band = NativeCalorieBand.of(calories, goal: goal)
        let value = goal.map { NativeCalorieBand.fraction(calories ?? 0, goal: $0) } ?? 0
        let low = goal.map { NativeCalorieBand.fraction($0 * 0.9, goal: $0) } ?? 0
        let high = goal.map { NativeCalorieBand.fraction($0 * 1.1, goal: $0) } ?? 0
        GeometryReader { proxy in
            let inset = knob / 2
            let arcRect = CGRect(x: inset, y: inset, width: proxy.size.width - knob, height: proxy.size.height - knob - NativeDesign.Space.medium)
            let local = NativeCalorieArcShape().path(in: CGRect(origin: .zero, size: arcRect.size))
            let point: (Double) -> CGPoint = { t in
                let p = local.trimmedPath(from: 0, to: max(t, 0.0001)).currentPoint ?? .zero
                return CGPoint(x: p.x + arcRect.minX, y: p.y + arcRect.minY)
            }
            ZStack(alignment: .topLeading) {
                arc(arcRect).stroke(Color(uiColor: .tertiarySystemFill), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if goal != nil {
                    arc(arcRect, from: low, to: high)
                        .stroke(NativeDesign.nutritionTitle.opacity(0.28), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                if value > 0 {
                    arc(arcRect, from: 0, to: value)
                        .stroke(LinearGradient(colors: [band.color.opacity(0.55), band.color], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    let end = point(value)
                    ZStack {
                        Circle().fill(band.color)
                        Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 3)
                        if band == .within {
                            Image(systemName: "checkmark").font(.caption2.weight(.heavy)).imageScale(.small).foregroundStyle(Color(uiColor: .systemBackground))
                        }
                    }
                    .frame(width: knob, height: knob)
                    .position(end)
                }
                if let goal, goal > 0 {
                    ForEach([(low, goal * 0.9), (high, goal * 1.1)], id: \.0) { item in
                        Text(item.1.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2.weight(.medium)).foregroundStyle(NativeDesign.secondary).monospacedDigit()
                            .fixedSize()
                            .position(x: point(item.0).x, y: proxy.size.height - NativeDesign.Space.xs)
                    }
                }
            }
        }
        .frame(height: NativeDesign.Space.section + NativeDesign.Space.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.map { "Fascia obiettivo da " + ($0 * 0.9).formatted(.number.precision(.fractionLength(0))) + " a " + ($0 * 1.1).formatted(.number.precision(.fractionLength(0))) + " kcal" } ?? "Nessun obiettivo")
    }

    private func arc(_ rect: CGRect, from: Double = 0, to: Double = 1) -> some Shape {
        NativeCalorieArcShape().trim(from: from, to: to).offset(x: rect.minX, y: rect.minY).size(width: rect.width, height: rect.height)
    }
}
