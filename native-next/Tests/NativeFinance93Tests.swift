import XCTest
@testable import LifeOSProbe

/// Build 93 Finanza data (BUILD93-PREVIEW-FINAL-2026-11-21, FINANCE-ALERTS-2026-11-21).
final class NativeFinance93Tests: XCTestCase {
    private func row(_ name: String, _ amount: Double) -> Record { ["name": .string(name), "amount": .number(amount)] }

    func testSalaryMapGroupsCommitmentsSavingsSpendingAndFree() {
        let summary: Record = ["monthlySalary": .number(1850), "monthlyRemaining": .number(210),
                               "monthlyBudgetBreakdown": .array([.object(row("Affitto", 450)), .object(row("Accantonamenti", 200))])]
        let categories = [row("Spesa", 260), row("Ristoranti", 120), row("Carburante", 90), row("Svago", 40), row("Farmaci", 30), row("Regali", 0)]
        let items = NativeSalaryMap.items(summary: summary, categories: categories)
        XCTAssertEqual(items.first { $0.name == "Affitto" }?.group, 0)
        XCTAssertEqual(items.first { $0.name == "Accantonamenti" }?.group, 1)
        XCTAssertEqual(items.filter { $0.group == 2 }.map(\.name), ["Spesa", "Ristoranti", "Carburante", "Svago", "Altro"])
        let other = try? XCTUnwrap(items.first { $0.name == "Altro" })
        XCTAssertEqual(other?.value, 30)
        XCTAssertEqual(other?.rows.map(\.label), ["Farmaci"])
        XCTAssertEqual(items.first { $0.group == 3 }?.value, 210)
        XCTAssertEqual(NativeSalaryMap.salary(summary: summary, items: items), 1850)
        XCTAssertEqual(NativeSalaryMap.percent(450, of: 1850), "24%")
        XCTAssertEqual(NativeSalaryMap.percent(30, of: 1850).replacingOccurrences(of: ",", with: "."), "1.6%")
    }

    func testSquarifyFillsTheRectangleWithProportionalAreas() {
        let rect = CGRect(x: 0, y: 0, width: 326, height: 220)
        let values: [Double] = [450, 260, 200, 120, 90, 30]
        let rects = NativeSalaryMap.squarify(values, in: rect)
        let total = values.reduce(0, +)
        for (index, value) in values.enumerated() {
            let area = Double(rects[index].width * rects[index].height)
            XCTAssertEqual(area, value / total * Double(rect.width * rect.height), accuracy: 1)
            XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(rects[index]))
        }
        let tiles = NativeSalaryMap.tiles([NativeSalaryItem(name: "A", group: 0, value: 3), NativeSalaryItem(name: "B", group: 1, value: 1)], in: rect)
        XCTAssertEqual(tiles.count, 2)
        XCTAssertEqual(Double(tiles[0].rect.width * tiles[0].rect.height), 0.75 * Double(rect.width * rect.height), accuracy: 1)
    }

    private var finance: Record {
        let yearly: [JSONValue] = [("2026-07", 1600.0), ("2026-08", 1500.0), ("2026-09", 1700.0), ("2026-10", 1900.0), ("2026-11", 400.0), ("2026-12", 0.0)].map { month, spent in
            .object(["month": .string(month), "income": .number(month == "2026-12" ? 0 : 1850), "spent": .number(spent), "hasRecords": .bool(month < "2026-12")])
        }
        return ["yearly": .array(yearly),
                "forecastHistory": .array([.object(["observed": .bool(true), "ordinaryNet": .number(20)]), .object(["observed": .bool(true), "ordinaryNet": .number(50)])]),
                "planning": .object(["now": .number(3900)]),
                "recurring": .array([.object(["name": .string("Gas"), "estimate": .number(40)]), .object(["name": .string("Acqua"), "estimate": .number(25)])]),
                "summary": .object(["monthlyRemaining": .number(210)])]
    }

    func testRhythmNormAndPaceUseCompleteMonthsOnly() throws {
        let flows = NativeFinanceAnalysis93.flows(finance, before: "2026-11")
        XCTAssertEqual(flows.map(\.month), ["2026-07", "2026-08", "2026-09", "2026-10"])
        XCTAssertEqual(try XCTUnwrap(NativeFinanceAnalysis93.norm(flows)), 1675, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(NativeFinanceAnalysis93.pace(flows, months: 1)), 1900.0 / 1675 - 1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(NativeFinanceAnalysis93.pace(flows, months: 3)), 1700.0 / 1675 - 1, accuracy: 0.0001)
        XCTAssertNil(NativeFinanceAnalysis93.pace(flows, months: 5))
        XCTAssertEqual(NativeFinanceAnalysis93.percent(0.08), "+8%")
        XCTAssertEqual(NativeFinanceAnalysis93.percent(-0.01), "−1%")
        XCTAssertEqual(flows.last?.saved, -50)
    }

    func testFundRunwayAndSurplus() throws {
        XCTAssertEqual(NativeFinanceAnalysis93.fund(finance), 3900)
        XCTAssertEqual(try XCTUnwrap(NativeFinanceAnalysis93.surplus(finance)), 35, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(NativeFinanceAnalysis93.runway(fund: 3900, monthly: 1300)), 3, accuracy: 0.001)
        XCTAssertNil(NativeFinanceAnalysis93.runway(fund: 3900, monthly: 0))
        XCTAssertNil(NativeFinanceAnalysis93.fund(["planning": .object([:])]))
    }

    func testDailySpendingCountsOutflowsOfTheMonth() {
        let rows: [Record] = [
            ["date": .string("2026-11-03"), "amount": .number(-12.5), "type": .string("Spesa")],
            ["date": .string("2026-11-03"), "amount": .number(-7.5), "type": .string("Spesa")],
            ["date": .string("2026-11-04"), "amount": .number(1850), "type": .string("Entrata")],
            ["date": .string("2026-10-30"), "amount": .number(-9), "type": .string("Spesa")]
        ]
        XCTAssertEqual(NativeFinanceAnalysis93.daily(rows, month: "2026-11"), [3: 20])
        XCTAssertEqual(NativeFinanceAnalysis93.shortMonth("2026-07"), "lug")
    }

    func testAlertsRespectThresholdsAndSwitches() {
        var settings = NativeFinanceAlertSettings()
        let gas: Record = ["date": .string("2026-11-10"), "amount": .number(-58), "category": .string("Gas")]
        let water: Record = ["date": .string("2026-11-10"), "amount": .number(-31), "category": .string("Acqua")]
        var keys = NativeFinanceAlertRules.candidates(finance: finance, transactions: [gas, water], settings: settings, month: "2026-11").map(\.key)
        // Pace +1.5% is under 10%; gas +45% and +18 € passes; water +24% fails the 25% threshold.
        XCTAssertEqual(keys, ["recurring-Gas"])
        settings.rhythmThreshold = 5; settings.recurringEuro = 20
        keys = NativeFinanceAlertRules.candidates(finance: finance, transactions: [gas, water], settings: settings, month: "2026-11").map(\.key)
        XCTAssertEqual(keys, [], "1.5% is still under 5%; 18 € is under 20 €")
        settings.recurringOn = false; settings.rhythmOn = false
        XCTAssertTrue(NativeFinanceAlertRules.candidates(finance: finance, transactions: [gas], settings: settings, month: "2026-11").isEmpty)
        var wild = NativeFinanceAlertSettings(); wild.rhythmThreshold = 99; wild.weeklyHour = 3; wild.frequency = 7
        XCTAssertEqual(wild.clamped.rhythmThreshold, 30); XCTAssertEqual(wild.clamped.weeklyHour, 6); XCTAssertEqual(wild.clamped.frequency, 2)
    }

    func testAlertLimitsAndQuietHours() throws {
        let calendar = CivilDate.calendar
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 23)))
        let earlier = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10)))
        let lastMonth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10)))
        XCTAssertFalse(NativeFinanceAlertRules.allowed("x", now: now, log: ["y": earlier], frequency: 0))
        XCTAssertTrue(NativeFinanceAlertRules.allowed("x", now: now, log: ["x": lastMonth], frequency: 0))
        XCTAssertTrue(NativeFinanceAlertRules.allowed("x", now: now, log: ["y": earlier], frequency: 1))
        XCTAssertFalse(NativeFinanceAlertRules.allowed("y", now: now, log: ["y": earlier], frequency: 1))
        XCTAssertFalse(NativeFinanceAlertRules.allowed("x", now: now, log: ["y": earlier], frequency: 2))
        let delivery = NativeFinanceAlertRules.delivery(after: now)
        XCTAssertEqual(calendar.component(.hour, from: delivery), 8)
        XCTAssertEqual(calendar.component(.day, from: delivery), 21)
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)))
        XCTAssertLessThan(NativeFinanceAlertRules.delivery(after: noon).timeIntervalSince(noon), 10)
    }

    func testWeeklySummaryText() {
        let rows: [Record] = [
            ["date": .string("2026-11-20"), "amount": .number(-68), "category": .string("Ristoranti"), "type": .string("Spesa")],
            ["date": .string("2026-11-18"), "amount": .number(-146), "category": .string("Spesa"), "type": .string("Spesa")],
            ["date": .string("2026-11-01"), "amount": .number(-500), "category": .string("Affitto"), "type": .string("Spesa")]
        ]
        let text = NativeFinanceAlertRules.weekly(transactions: rows, today: "2026-11-21")
        XCTAssertTrue(text.hasPrefix("Spesi " + 214.0.euro), text)
        XCTAssertTrue(text.contains("Spesa la voce più alta"), text)
    }
}
