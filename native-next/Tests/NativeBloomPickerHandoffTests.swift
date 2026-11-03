import XCTest
@testable import LifeOSProbe

final class NativeBloomPickerHandoffTests: XCTestCase {
    func testResultBeforeDismissalIsDeliveredOnlyAfterDismissal() {
        var handoff = NativeBloomPickerHandoff()
        let bytes = Data("backup".utf8)
        handoff.begin(); handoff.picked(bytes)
        XCTAssertNil(handoff.takeReadyData())
        handoff.didDismiss()
        XCTAssertEqual(handoff.takeReadyData(), bytes)
        XCTAssertNil(handoff.takeReadyData())
    }
    func testDismissalBeforeResultStillDeliversSelectionExactlyOnce() {
        var handoff = NativeBloomPickerHandoff()
        let bytes = Data("backup".utf8)
        handoff.begin(); handoff.didDismiss()
        XCTAssertNil(handoff.takeReadyData())
        handoff.picked(bytes)
        XCTAssertEqual(handoff.takeReadyData(), bytes)
        handoff.picked(Data("duplicate".utf8))
        XCTAssertNil(handoff.takeReadyData())
    }
    func testCancelDiscardsLateResultAndAllowsAnotherAttempt() {
        var handoff = NativeBloomPickerHandoff()
        let bytes = Data("backup".utf8)
        handoff.begin(); handoff.cancel(); handoff.didDismiss(); handoff.picked(bytes)
        XCTAssertNil(handoff.takeReadyData())
        handoff.begin(); handoff.picked(bytes); handoff.didDismiss()
        XCTAssertEqual(handoff.takeReadyData(), bytes)
    }
}
