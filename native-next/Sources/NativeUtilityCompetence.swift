import Foundation

struct NativeUtilityShare: Identifiable {
    let month: String
    let cents: Int
    var id: String { month }
}

struct NativeUtilityPeriodDraft: Equatable {
    var enabled = false
    var start = ""
    var end = ""
    static let categories: Set<String> = ["Elettricità", "Gas", "Acqua", "Utenze", "Condominio"]
    var months: [String]? {
        guard NativePlanRules.validMonth(start), NativePlanRules.validMonth(end), start <= end else { return nil }
        var cursor = start, result: [String] = []
        while cursor <= end && result.count < 13 {
            result.append(cursor); cursor = NativePlanRules.adding(1, to: cursor)
        }
        return (1...12).contains(result.count) && result.last == end ? result : nil
    }
    func shares(_ cents: Int) -> [NativeUtilityShare] {
        guard cents > 0, let months else { return [] }
        return months.enumerated().map { NativeUtilityShare(month: $0.element, cents: cents / months.count + ($0.offset < cents % months.count ? 1 : 0)) }
    }
    var payload: Record {
        guard enabled else { return [:] }
        return ["utilityCompetenceVersion": .int(1), "competenceStartMonth": .string(start), "competenceEndMonth": .string(end), "competenceMonths": .int(months?.count ?? 0)]
    }
    mutating func prepare(day: String, required: Bool) {
        enabled = required
        guard required else { return }
        if start.isEmpty { start = String(day.prefix(7)) }
        if end.isEmpty { end = String(day.prefix(7)) }
    }
    init() {}
    init(record: Record) {
        start = record.text("competenceStartMonth", fallback: record.text("utilityCompetenceStartMonth", fallback: record.record("utilityPeriod").text("start")))
        end = record.text("competenceEndMonth", fallback: record.text("utilityCompetenceEndMonth", fallback: record.record("utilityPeriod").text("end")))
        enabled = !start.isEmpty || !end.isEmpty
    }
}
