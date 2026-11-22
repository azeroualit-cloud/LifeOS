import XCTest
@testable import LifeOSProbe

final class NativeBloomDirectionsTests: XCTestCase {
    func testWazeLinkNavigatesToCoordinates() {
        let url = NativeBloomDirections.waze(latitude: 43.7228, longitude: 10.9466)
        XCTAssertEqual(url?.absoluteString, "https://waze.com/ul?ll=43.722800,10.946600&navigate=yes")
    }
    func testWazeLinkRejectsInvalidCoordinates() {
        XCTAssertNil(NativeBloomDirections.waze(latitude: .nan, longitude: 10))
        XCTAssertNil(NativeBloomDirections.waze(latitude: 91, longitude: 10))
    }
}
