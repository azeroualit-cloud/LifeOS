import XCTest
import UIKit
@testable import LifeOSProbe

@MainActor final class NativeRevision72Tests: XCTestCase {
    private func event(_ id: Int, _ start: String, _ end: String = "") -> Record {
        ["id": .int(id), "day": .string("2026-10-31"), "start_time": .string(start), "end_time": .string(end)]
    }
    func testEightHourEventContainsTheInnerEventWithoutCreatingHourlyRows() {
        let nodes = NativeCalendarTimeline.agenda(events: [event(1, "06:00", "14:00"), event(2, "08:00", "09:00"), event(3, "15:00")], tasks: [], shift: nil)
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes[0].entry.start, 360)
        XCTAssertEqual(nodes[0].entry.end, 840)
        XCTAssertEqual(nodes[0].children.map(\.entry.start), [480])
        XCTAssertEqual(nodes[1].entry.start, 900)
        XCTAssertNil(nodes[1].entry.end, "No invented end time for a start-only activity")
    }
    func testSmallestContainingEventIsTheParentAndEveryRecordAppearsOnce() {
        let nodes = NativeCalendarTimeline.agenda(events: [event(1, "06:00", "18:00"), event(2, "08:00", "12:00"), event(3, "09:00", "10:00")], tasks: [], shift: .afternoon)
        func flatten(_ nodes: [NativeCalendarAgendaNode]) -> [String] { nodes.flatMap { [$0.id] + flatten($0.children) } }
        let ids = flatten(nodes)
        XCTAssertEqual(ids.count, 4); XCTAssertEqual(Set(ids).count, 4)
        let long = nodes.first { $0.entry.source == "event" }!
        // The shift crosses this event, so it is a sibling, not a false container.
        XCTAssertEqual(long.children.first?.entry.start, 480)
        XCTAssertEqual(long.children.first?.children.first?.entry.start, 540)
    }
    func testEqualIntervalsRemainSiblingsAndCrossingOverlapDoesNotDisappear() {
        let nodes = NativeCalendarTimeline.agenda(events: [event(1, "08:00", "10:00"), event(2, "08:00", "10:00"), event(3, "09:00", "11:00")], tasks: [], shift: nil)
        XCTAssertEqual(nodes.count, 3); XCTAssertTrue(nodes.allSatisfy { $0.children.isEmpty })
    }
    func testMidnightCarryAndNightShiftPreserveActualEndLabels() {
        let nodes = NativeCalendarTimeline.agenda(events: [event(1, "23:59")], tasks: [], shift: .night, previousShift: .night, previousEvents: [event(2, "23:00", "02:00")])
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.first?.entry.start, 0)
        XCTAssertEqual(nodes.first?.children.first?.entry.end, 120)
        XCTAssertEqual(nodes.last?.entry.end, 1800)
        XCTAssertEqual(nodes.last?.children.first?.entry.start, 1439)
        XCTAssertEqual(NativeCalendarTimeline.clock(1800), "06:00 +1")
    }
    func testAllDayAndMalformedTimesStayOutOfTheTimedAgenda() {
        XCTAssertTrue(NativeCalendarTimeline.agenda(events: [event(1, ""), event(2, "25:00"), event(3, "9:00")], tasks: [], shift: .rest).isEmpty)
    }
    func testTimedTaskIsNestedWithinShiftAndRetainsIdentityAndCompletion() {
        let task: Record = ["id": .int(9), "scheduled_time": .string("10:30"), "status": .string("done")]
        let nodes = NativeCalendarTimeline.agenda(events: [], tasks: [task], shift: .morning)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].entry.source, "shift")
        XCTAssertEqual(nodes[0].children.first?.entry.record.integer("id"), 9)
        XCTAssertEqual(nodes[0].children.first?.entry.completed, true)
    }
    func testCalendarAccentIsBlueInBothThemesWithoutChangingDashboardAccent() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let color = UIColor(NativeDesign.calendarAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
            XCTAssertGreaterThan(b - r, 0.25)
        }
    }
}
