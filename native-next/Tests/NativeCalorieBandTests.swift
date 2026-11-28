import XCTest
@testable import LifeOSProbe

final class NativeCalorieBandTests: XCTestCase {
    func testBandAroundTheGoal() {
        XCTAssertEqual(NativeCalorieBand.of(nil, goal: 2000), .none)
        XCTAssertEqual(NativeCalorieBand.of(0, goal: 2000), .none)
        XCTAssertEqual(NativeCalorieBand.of(1700, goal: 2000), .under)
        XCTAssertEqual(NativeCalorieBand.of(1800, goal: 2000), .within)
        XCTAssertEqual(NativeCalorieBand.of(2200, goal: 2000), .within)
        // NUTRITION-TOLERANT-2026-11-24: a little over is still fine; the warning starts above +25 %.
        XCTAssertEqual(NativeCalorieBand.of(2500, goal: 2000), .within)
        XCTAssertEqual(NativeCalorieBand.of(2501, goal: 2000), .over)
        XCTAssertEqual(NativeCalorieBand.of(1500, goal: nil), .within)
    }
    func testMacroColourIsFitiaGreenYellowAndOrangeOnlyFarAbove() {
        // CALORIE-CARD-FITIA-97: yellow while below the range, green once reached (a gram over changes nothing),
        // orange only far above (NUTRITION-TOLERANT limits kept).
        let base = NativeDesign.nutritionFill
        XCTAssertEqual(NativeCalorieBand.macroColor(80, goal: 100, base: base), NativeDesign.nutritionUnder)
        XCTAssertEqual(NativeCalorieBand.macroColor(90, goal: 100, base: base), NativeDesign.nutritionFill)
        XCTAssertEqual(NativeCalorieBand.macroColor(127, goal: 126, base: base), NativeDesign.nutritionFill)
        XCTAssertEqual(NativeCalorieBand.macroColor(150, goal: 100, base: base), NativeDesign.nutritionFill)
        XCTAssertEqual(NativeCalorieBand.macroColor(151, goal: 100, base: base), NativeDesign.overGoal)
        XCTAssertEqual(NativeCalorieBand.macroColor(190, goal: 100, base: base, limit: NativeNutritionLimits.protein), NativeDesign.nutritionFill)
        XCTAssertEqual(NativeCalorieBand.macroColor(50, goal: nil, base: base), base)
        XCTAssertEqual(NativeCalorieBand.within.color, NativeDesign.nutritionFill)
        XCTAssertEqual(NativeCalorieBand.under.color, NativeDesign.nutritionUnder)
    }
    func testGaugeFractionIsClamped() {
        // The arc runs to twice the goal: the goal sits in the middle (build 95).
        XCTAssertEqual(NativeCalorieBand.fraction(2000, goal: 2000), 0.5, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(4000, goal: 2000), 1, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(5000, goal: 2000), 1, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(1000, goal: 2000), 0.25, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(100, goal: 0), 0)
    }
}
