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

/// Shallow arc used as the calorie track.
private struct NativeCalorieArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return path
    }
}

/// Arc with the eaten calories, the goal band markers and their values underneath.
struct NativeCalorieGauge: View {
    let calories: Double?
    let goal: Double?
    private let lineWidth: CGFloat = 8

    var body: some View {
        let band = NativeCalorieBand.of(calories, goal: goal)
        let value = goal.map { NativeCalorieBand.fraction(calories ?? 0, goal: $0) } ?? 0
        VStack(spacing: NativeDesign.Space.xxs) {
            GeometryReader { proxy in
                let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
                ZStack {
                    NativeCalorieArcShape().stroke(Color(uiColor: .tertiarySystemFill), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: rect.width, height: rect.height).position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    NativeCalorieArcShape().trim(from: 0, to: value)
                        .stroke(band.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: rect.width, height: rect.height).position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    if let goal, goal > 0 {
                        ForEach([0.9, 1.1], id: \.self) { share in
                            // Same arc-length measure as `trim`, so markers and progress agree.
                            let local = NativeCalorieArcShape().path(in: CGRect(origin: .zero, size: rect.size))
                                .trimmedPath(from: 0, to: NativeCalorieBand.fraction(goal * share, goal: goal)).currentPoint ?? .zero
                            Capsule().fill(Color.primary.opacity(0.55))
                                .frame(width: 3, height: lineWidth + NativeDesign.Space.small)
                                .position(x: local.x + rect.minX, y: local.y + rect.minY)
                        }
                    }
                }
            }
            .frame(height: NativeDesign.Space.xLarge + NativeDesign.Space.small)
            if let goal, goal > 0 {
                GeometryReader { proxy in
                    ForEach([0.9, 1.1], id: \.self) { share in
                        Text((goal * share).formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2).foregroundStyle(NativeDesign.secondary).monospacedDigit()
                            .fixedSize()
                            .position(x: proxy.size.width * NativeCalorieBand.fraction(goal * share, goal: goal), y: proxy.size.height / 2)
                    }
                }
                .frame(height: NativeDesign.Space.medium)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.map { "Fascia obiettivo da " + ($0 * 0.9).formatted(.number.precision(.fractionLength(0))) + " a " + ($0 * 1.1).formatted(.number.precision(.fractionLength(0))) + " kcal" } ?? "Nessun obiettivo")
    }
}
