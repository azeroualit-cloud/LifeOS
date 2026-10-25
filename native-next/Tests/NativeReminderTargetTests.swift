import XCTest
@testable import LifeOSProbe
final class NativeReminderTargetTests: XCTestCase {
    func testNotificationRoutesKeepItemIdentity() {
        for target in [NativeReminderTarget(kind: .task,id: 2), NativeReminderTarget(kind: .event,id: 3,day: "2026-10-26"), NativeReminderTarget(kind: .day,day:"2026-10-26")] {
            XCTAssertEqual(NativeReminderTarget(URL(string:"lifeos://"+target.route)!), target)
        }
        for url in ["lifeos://calendar?event=-1&day=2026-10-26", "lifeos://calendar?day=2026-02-30", "lifeos://activities?task=1&task=2", "https://activities?task=1"] { XCTAssertNil(NativeReminderTarget(URL(string:url)!)) }
    }
}
