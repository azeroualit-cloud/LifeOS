import SwiftUI

/// Where a value sits against its goal (Fitia-like card, user request 23/11/2026).
/// The recommended range is ±10 % of the goal; colour carries the meaning:
/// green inside the range, amber below, orange above, grey with nothing logged.
enum NativeCalorieBand: Equatable {
    case none, under, within, over

    static let low = 0.9, high = 1.1

    static func of(_ value: Double?, goal: Double?) -> NativeCalorieBand {
        guard let value, value > 0 else { return .none }
        guard let goal, goal > 0 else { return .within }
        if value < goal * low { return .under }
        if value > goal * high { return .over }
        return .within
    }
    /// Two colours only (user, 23/11/2026): green inside the range, warm below it or well above it.
    var color: Color {
        switch self {
        case .none: NativeDesign.emptyMark
        case .within: NativeDesign.goalMet
        case .under, .over: NativeDesign.overGoal
        }
    }
    /// Macros: warm below the goal, green once it is reached or passed.
    static func macroColor(_ value: Double?, goal: Double?) -> Color {
        guard let goal, goal > 0 else { return NativeDesign.emptyMark }
        guard let value, value > 0 else { return NativeDesign.emptyMark }
        return value >= goal ? NativeDesign.goalMet : NativeDesign.overGoal
    }
    /// The arc runs to twice the goal, so the recommended range sits in the middle.
    static let scale = 2.0
    static func fraction(_ value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value / (goal * scale), 0), 1)
    }
    /// Recommended calorie range for a goal, e.g. 1787–2185 for 1986.
    static func range(goal: Double) -> ClosedRange<Double> { (goal * low)...(goal * high) }
}

/// Wide, shallow arc whose top touches the frame's top edge.
private struct NativeCalorieArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return path
    }
}

/// Fitia-like gauge: thin grey track, solid progress in the meaning colour ending in a knob
/// (check inside the range), two range ticks with the recommended limits underneath.
struct NativeCalorieGauge: View {
    let calories: Double?
    let goal: Double?
    private let lineWidth: CGFloat = 6
    private let knob: CGFloat = 20

    var body: some View {
        let band = NativeCalorieBand.of(calories, goal: goal)
        let value = goal.map { NativeCalorieBand.fraction(calories ?? 0, goal: $0) } ?? 0
        VStack(spacing: NativeDesign.Space.xxs) {
            GeometryReader { proxy in
                let rect = CGRect(x: knob / 2, y: knob / 2, width: proxy.size.width - knob, height: proxy.size.height - knob)
                ZStack(alignment: .topLeading) {
                    arc(rect).stroke(Color(uiColor: .tertiarySystemFill), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    if value > 0 {
                        arc(rect, to: value).stroke(band.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    }
                    if let goal, goal > 0 {
                        tick(at: point(NativeCalorieBand.fraction(goal * NativeCalorieBand.low, goal: goal), in: rect), filled: true)
                        tick(at: point(NativeCalorieBand.fraction(goal * NativeCalorieBand.high, goal: goal), in: rect), filled: false)
                    }
                    if value > 0 { knobView(band).position(point(value, in: rect)) }
                }
            }
            // A taller frame makes a rounder arc, closer to Fitia's.
            .frame(height: NativeDesign.Space.section + NativeDesign.Space.xLarge + NativeDesign.Space.small)
            if let goal, goal > 0 { rangeLabels(goal) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.map { goal -> String in
            let range = NativeCalorieBand.range(goal: goal)
            return "Range consigliato da " + whole(range.lowerBound) + " a " + whole(range.upperBound) + " kcal"
        } ?? "Nessun obiettivo")
    }

    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }

    private func arc(_ rect: CGRect, to: Double = 1) -> some Shape {
        NativeCalorieArcShape().trim(from: 0, to: to).offset(x: rect.minX, y: rect.minY).size(width: rect.width, height: rect.height)
    }
    /// Point at a fraction of the arc length (the same measure `trim` uses).
    private func point(_ fraction: Double, in rect: CGRect) -> CGPoint {
        let local = NativeCalorieArcShape().path(in: CGRect(origin: .zero, size: rect.size))
            .trimmedPath(from: 0, to: max(fraction, 0.0001)).currentPoint ?? .zero
        return CGPoint(x: local.x + rect.minX, y: local.y + rect.minY)
    }
    private func tick(at point: CGPoint, filled: Bool) -> some View {
        Capsule()
            .fill(filled ? Color.primary : Color(uiColor: .systemGray3))
            .overlay(Capsule().strokeBorder(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
            .frame(width: NativeDesign.Space.small - 1, height: NativeDesign.Space.medium + NativeDesign.Space.xs)
            .position(point)
    }
    private func knobView(_ band: NativeCalorieBand) -> some View {
        ZStack {
            Circle().fill(band.color)
            Circle().strokeBorder(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2)
            if band == .within {
                Image(systemName: "checkmark").font(.caption2.weight(.heavy)).imageScale(.small).foregroundStyle(Color(uiColor: .systemBackground))
            }
        }
        .frame(width: knob, height: knob)
    }
    /// The recommended range under the two ticks, centred on each tick.
    private func rangeLabels(_ goal: Double) -> some View {
        GeometryReader { proxy in
            let rect = CGRect(x: knob / 2, y: knob / 2, width: proxy.size.width - knob, height: 1)
            ForEach([NativeCalorieBand.low, NativeCalorieBand.high], id: \.self) { share in
                let fraction = NativeCalorieBand.fraction(goal * share, goal: goal)
                Text(whole(goal * share))
                    .font(.caption2.weight(.medium)).foregroundStyle(NativeDesign.secondary).monospacedDigit()
                    .fixedSize()
                    .position(x: rect.minX + rect.width * fraction, y: proxy.size.height / 2)
            }
        }
        .frame(height: NativeDesign.Space.medium)
    }
}
