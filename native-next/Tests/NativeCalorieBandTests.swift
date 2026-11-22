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
    func testGaugeFractionIsClamped() {
        XCTAssertEqual(NativeCalorieBand.fraction(2600, goal: 2000), 1, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(5000, goal: 2000), 1, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(1300, goal: 2000), 0.5, accuracy: 0.0001)
        XCTAssertEqual(NativeCalorieBand.fraction(100, goal: 0), 0)
    }
}
