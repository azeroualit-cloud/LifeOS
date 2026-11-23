import XCTest
@testable import LifeOSProbe

/// Guards the measurements the user approved (DESIGN-PASS-94, SPACING-SYSTEM-2026-11-23, REVIEW-95).
/// Build 95 shipped 21 pt pills because a control height was derived from a spacing token that
/// later changed; every control size here is fixed and checked on its own.
final class NativeDesignTokensTests: XCTestCase {
    func testControlSizesAreTheApprovedOnes() {
        XCTAssertEqual(NativeDesign.Layout.compactControl, 34, "pills, chips, in-card buttons: 34 pt visible")
        XCTAssertEqual(NativeDesign.Layout.touchTarget, 44)
        XCTAssertEqual(NativeDesign.Layout.bottomAction, 44)
        XCTAssertEqual(NativeDesign.Layout.rowHeight, 44)
        XCTAssertEqual(NativeDesign.Layout.actionCircle, 55)
        XCTAssertEqual(NativeDesign.Layout.segmentHeight + 4, NativeDesign.Layout.compactControl, "the switch with its rim matches the pills (Oggi | Mese/Agenda)")
    }
    func testCardsHaveTheSameInsetOnEverySide() {
        XCTAssertEqual(NativeDesign.Layout.cardInset, 16)
        XCTAssertEqual(NativeDesign.Layout.cardInsetVertical, NativeDesign.Layout.cardInset, "SPACING-SYSTEM-2026-11-23: 16 on every side")
        XCTAssertEqual(NativeDesign.Layout.screenInset, 16)
        XCTAssertEqual(NativeDesign.Layout.tabBarInset, 21)
    }
    func testSpacingScale() {
        XCTAssertEqual([NativeDesign.Space.xxs, NativeDesign.Space.xs, NativeDesign.Space.small, NativeDesign.Space.medium, NativeDesign.Space.large, NativeDesign.Space.xLarge],
                       [2, 5, 8, 13, 16, 21])
        XCTAssertEqual(NativeDesign.Space.section, 21)
    }
    func testCategoryChoice() {
        let rows: [Record] = [["name": .string("Spesa"), "amount": .number(10)], ["name": .string("Svago"), "amount": .number(5)]]
        XCTAssertEqual(NativeCategoryChoice.filter(rows, chosen: []).count, 2)
        let chosen = NativeCategoryChoice.toggle("Svago", in: [])
        XCTAssertEqual(NativeCategoryChoice.filter(rows, chosen: chosen).map { $0.text("name") }, ["Svago"])
        XCTAssertEqual(NativeCategoryChoice.decode(NativeCategoryChoice.encode(["A", "B"])), ["A", "B"])
        XCTAssertEqual(NativeCategoryChoice.label(["A", "B"]), "2 categorie")
    }
}
