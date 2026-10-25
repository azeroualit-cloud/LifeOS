import XCTest
@testable import LifeOSProbe
final class NativeServerFeaturePolicyTests: XCTestCase {
    func testLegacyServerCannotSilentlyDiscardReminderTime() {
        XCTAssertThrowsError(try NativeServerFeaturePolicy.validate("saveTask",payload:["scheduled_time":.string("16:30")],life:[:]))
        XCTAssertNoThrow(try NativeServerFeaturePolicy.validate("saveTask",payload:["scheduled_time":.null],life:[:]))
        XCTAssertNoThrow(try NativeServerFeaturePolicy.validate("saveTask",payload:["scheduled_time":.string("16:30")],life:["capabilities":.object(["taskNotificationTimes":.bool(true)])]))
    }
    func testLegacyDailyHabitCanBeRenamedButNewScheduleRequiresSupport() {
        let daily: Record = ["schedule":.object(["mode":.string("daily")])]
        let interval: Record = ["schedule":.object(["mode":.string("interval"),"intervalDays":.int(2),"startDate":.string("2026-10-25")])]
        XCTAssertNoThrow(try NativeServerFeaturePolicy.validate("saveRoutine",payload:daily,life:[:]))
        XCTAssertThrowsError(try NativeServerFeaturePolicy.validate("saveRoutine",payload:interval,life:[:]))
        XCTAssertNoThrow(try NativeServerFeaturePolicy.validate("saveRoutine",payload:interval,life:["capabilities":.object(["routineSchedules":.bool(true)])]))
    }
}
