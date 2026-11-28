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
        // NUTRITION-TOLERANT-2026-11-24: a little over the range is fine; the warning starts at +25 %.
        if value > goal * NativeNutritionLimits.calories { return .over }
        return .within
    }
    /// CALORIE-CARD-FITIA-97: Fitia's green inside the range, Fitia's yellow while still below it, orange only far above.
    var color: Color {
        switch self {
        case .none: NativeDesign.nutritionTrack
        case .within: NativeDesign.nutritionFill
        case .under: NativeDesign.nutritionUnder
        case .over: NativeDesign.overGoal
        }
    }
    /// Macros: green when reached, yellow while below, orange only when really excessive (NUTRITION-TOLERANT).
    static func macroColor(_ value: Double?, goal: Double?, base: Color, limit: Double = NativeNutritionLimits.macro) -> Color {
        guard let goal, goal > 0, let value, value > 0 else { return base }
        if value > goal * limit { return NativeDesign.overGoal }
        return value < goal * low ? NativeDesign.nutritionUnder : NativeDesign.nutritionFill
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

/// Almost straight arc (CALORIE-CARD-FITIA-97): the middle rises a little above the ends.
private struct NativeCalorieArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return path
    }
}

/// Fitia-like gauge: thin grey track without borders, the progress in Fitia's green or yellow ending in a solid
/// knob (white check inside the range), the two range limits on the bar with their values right under them.
struct NativeCalorieGauge: View {
    let calories: Double?
    let goal: Double?
    private let lineWidth: CGFloat = 8
    private let knob: CGFloat = 20

    var body: some View {
        let band = NativeCalorieBand.of(calories, goal: goal)
        let value = goal.map { NativeCalorieBand.fraction(calories ?? 0, goal: $0) } ?? 0
        GeometryReader { proxy in
            let rect = CGRect(x: knob / 2, y: knob / 2, width: proxy.size.width - knob, height: NativeDesign.Space.large)
            ZStack(alignment: .topLeading) {
                arc(rect).stroke(NativeDesign.nutritionTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if value > 0 {
                    arc(rect, to: value).stroke(band.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                if let goal, goal > 0 {
                    let low = point(NativeCalorieBand.fraction(goal * NativeCalorieBand.low, goal: goal), in: rect)
                    let high = point(NativeCalorieBand.fraction(goal * NativeCalorieBand.high, goal: goal), in: rect)
                    tick(at: low, color: Color.primary)
                    tick(at: high, color: NativeDesign.secondary)
                    limit(goal * NativeCalorieBand.low).position(x: low.x, y: low.y + NativeDesign.Space.large)
                    limit(goal * NativeCalorieBand.high).position(x: high.x, y: high.y + NativeDesign.Space.large)
                }
                if value > 0 { knobView(band).position(point(value, in: rect)) }
            }
        }
        .frame(height: NativeDesign.Space.large * 2 + knob)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.map { goal -> String in
            let range = NativeCalorieBand.range(goal: goal)
            return "Range consigliato da " + whole(range.lowerBound) + " a " + whole(range.upperBound) + " kcal"
        } ?? "Nessun obiettivo")
    }

    private func whole(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func limit(_ value: Double) -> some View {
        Text(whole(value)).font(.caption2.weight(.medium)).foregroundStyle(NativeDesign.secondary).monospacedDigit().fixedSize()
    }
    private func arc(_ rect: CGRect, to: Double = 1) -> some Shape {
        NativeCalorieArcShape().trim(from: 0, to: to).offset(x: rect.minX, y: rect.minY).size(width: rect.width, height: rect.height)
    }
    /// Point at a fraction of the arc length (the same measure `trim` uses).
    private func point(_ fraction: Double, in rect: CGRect) -> CGPoint {
        let local = NativeCalorieArcShape().path(in: CGRect(origin: .zero, size: rect.size))
            .trimmedPath(from: 0, to: max(fraction, 0.0001)).currentPoint ?? .zero
        return CGPoint(x: local.x + rect.minX, y: local.y + rect.minY)
    }
    private func tick(at point: CGPoint, color: Color) -> some View {
        Capsule().fill(color)
            .frame(width: NativeDesign.Space.xs - 1, height: NativeDesign.Space.medium + NativeDesign.Space.xs)
            .position(point)
    }
    private func knobView(_ band: NativeCalorieBand) -> some View {
        ZStack {
            Circle().fill(band.color)
            if band == .within {
                Image(systemName: "checkmark").font(.caption2.weight(.heavy)).imageScale(.small).foregroundStyle(.white)
            }
        }
        .frame(width: knob, height: knob)
    }
}

/// NUTRITION-TOLERANT-2026-11-24: colours change only for values far from the goal (non-optimal or harmful),
/// never for a few grams. Calories +25 %, protein double the goal, other macros +50 %.
enum NativeNutritionLimits {
    static let calories = 1.25
    static let protein = 2.0
    static let macro = 1.5
}
