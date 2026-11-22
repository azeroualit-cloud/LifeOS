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
    func testGoogleMapsLinks() {
        XCTAssertEqual(NativeBloomDirections.googleMapsApp(latitude: 43.7228, longitude: 10.9466)?.absoluteString,
                       "comgooglemaps://?daddr=43.722800,10.946600&directionsmode=driving")
        XCTAssertEqual(NativeBloomDirections.googleMapsWeb(latitude: 43.7228, longitude: 10.9466)?.absoluteString,
                       "https://www.google.com/maps/dir/?api=1&destination=43.722800,10.946600")
        XCTAssertNil(NativeBloomDirections.googleMapsApp(latitude: 100, longitude: 0))
    }
}
