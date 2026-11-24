import XCTest
@testable import LifeOSProbe

/// FINANCE-ENTRY-SIMPLIFY-2026-11-24: instalments are shown apart, with the same rows and amounts.
final class NativeInstalmentsTests: XCTestCase {
    private let plans: [Record] = [
        ["id": .string("p1"), "kind": .string("recovery"), "name": .string("Proteine"), "startMonth": .string("2026-11"), "endMonth": .string("2027-01")],
        ["id": .string("p2"), "kind": .string("fixed"), "name": .string("Affitto"), "startMonth": .string("2026-10")],
    ]
    func testRowsAndLabels() {
        let plan = NativeBudgetFlow.Row(id: 1, name: "Proteine", planID: "p1", amountCents: 2500, remainingCents: 0)
        let rent = NativeBudgetFlow.Row(id: 2, name: "Affitto", planID: "p2", amountCents: 55000, remainingCents: 0)
        let movement = NativeBudgetFlow.Row(id: 3, name: "Recupero · 3/3 Rata Divano Klarna", planID: nil, amountCents: 4259, remainingCents: 0)
        let other = NativeBudgetFlow.Row(id: 4, name: "Condominio", planID: nil, amountCents: 2000, remainingCents: 0)
        XCTAssertEqual([plan, rent, movement, other].map { NativeInstalments.isInstalment($0, plans: plans) }, [true, false, true, false])
        XCTAssertEqual(NativeInstalments.title(plan, plans: plans, month: "2026-12").detail, "rata 2 di 3")
        XCTAssertEqual(NativeInstalments.title(movement, plans: plans, month: "2026-11").name, "Rata Divano Klarna")
        XCTAssertEqual(NativeInstalments.title(movement, plans: plans, month: "2026-11").detail, "rata 3 di 3")
        XCTAssertEqual(NativeInstalments.count("2026-11", "2027-01"), 3)
        XCTAssertEqual(NativeInstalments.count("2027-01", "2026-11"), 0)
    }
}
