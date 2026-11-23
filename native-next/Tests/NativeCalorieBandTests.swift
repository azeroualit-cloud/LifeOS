import XCTest
@testable import LifeOSProbe

final class NativeCalorieBandTests: XCTestCase {
    func testBandAroundTheGoal() {
        XCTAssertEqual(NativeCalorieBand.of(nil, goal: 2000), .none)
        XCTAssertEqual(NativeCalorieBand.of(0, goal: 2000), .none)
        XCTAssertEqual(NativeCalorieBand.of(1700, goal: 2000), .under)
        XCTAssertEqual(NativeCalorieBand.of(1800, goal: 2000), .within)
        XCTAssertEqual(NativeCalorieBand.of(2200, goal: 2000), .within)
        XCTAssertEqual(NativeCalorieBand.of(2201, goal: 2000), .over)
        XCTAssertEqual(NativeCalorieBand.of(1500, goal: nil), .within)
    }
    func testMacroColourIsWarmUnderAndGreenAtGoal() {
        XCTAssertEqual(NativeCalorieBand.macroColor(90, goal: 100), NativeDesign.overGoal)
        XCTAssertEqual(NativeCalorieBand.macroColor(100, goal: 100), NativeDesign.goalMet)
        XCTAssertEqual(NativeCalorieBand.macroColor(150, goal: 100), NativeDesign.goalMet)
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
