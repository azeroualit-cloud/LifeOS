import Foundation

// Preserve unknown API fields: the Worker remains the authority for money and planning.
enum JSONValue: Codable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var object: Record { if case .object(let v) = self { return v }; return [:] }
    var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    var string: String { if case .string(let v) = self { return v }; return "" }
    var number: Double { if case .number(let v) = self { return v }; return 0 }
    var bool: Bool { if case .bool(let v) = self { return v }; return number != 0 }
    static func int(_ n: Int) -> JSONValue { .number(Double(n)) }
}
typealias Record = [String: JSONValue]
extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String, fallback: String = "") -> String { self[key]?.string.isEmpty == false ? self[key]!.string : fallback }
    func amount(_ key: String) -> Double { self[key]?.number ?? 0 }
    func integer(_ key: String) -> Int {
        let n = amount(key)
        guard n.isFinite, n >= Double(Int.min), n < Double(Int.max) else { return 0 }
        return Int(n)
    }
    func flag(_ key: String) -> Bool { self[key]?.bool ?? false }
    func record(_ key: String) -> Record { self[key]?.object ?? [:] }
    func records(_ key: String) -> [Record] { self[key]?.array.map(\.object) ?? [] }
}
struct DisplayRecord: Identifiable {
    let value: Record
    let id: String
    init(_ value: Record, key: String = "id") {
        self.value = value
        if key == "key" || key == "day" { id = value.text(key) }
        else { id = String(value.integer(key)) + (value.text("day").isEmpty ? "" : ":" + value.text("day")) }
    }
}
struct PendingWrite: Codable, Identifiable {
    let id: String
    let method: String
    let payload: Record
    var accepted = false
}
struct NativeArchive: Codable {
    var life: Record = [:]
    var finance: Record = [:]
    var plan: Record = [:]
    var pending: [PendingWrite] = []
    var demo = true
    var imported = false
    var refreshedAt: Date?
    var endpoint: String?
    var routineDay = ""
    var financeMonth = CivilDate.month()
    var calendarMonth = CivilDate.month()
    var financeRefreshedAt: Date?
    var lifeRefreshedAt: Date?
}
extension NativeArchive {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        life = try c.decode(Record.self, forKey: .life)
        finance = try c.decode(Record.self, forKey: .finance)
        plan = try c.decode(Record.self, forKey: .plan)
        pending = try c.decode([PendingWrite].self, forKey: .pending)
        demo = try c.decode(Bool.self, forKey: .demo)
        imported = try c.decode(Bool.self, forKey: .imported)
        refreshedAt = try c.decodeIfPresent(Date.self, forKey: .refreshedAt)
        endpoint = try c.decodeIfPresent(String.self, forKey: .endpoint)
        routineDay = try c.decode(String.self, forKey: .routineDay)
        financeMonth = try c.decodeIfPresent(String.self, forKey: .financeMonth) ?? CivilDate.month()
        calendarMonth = try c.decodeIfPresent(String.self, forKey: .calendarMonth) ?? CivilDate.month()
        financeRefreshedAt = try c.decodeIfPresent(Date.self, forKey: .financeRefreshedAt) ?? refreshedAt
        lifeRefreshedAt = try c.decodeIfPresent(Date.self, forKey: .lifeRefreshedAt) ?? refreshedAt
    }
}
enum CivilDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Rome")!; c.firstWeekday = 2; return c
    }()
    // Immutable after initialization; Foundation DateFormatter supports concurrent reads.
    private static func formatter(_ format: String, locale: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: locale); f.calendar = calendar
        f.timeZone = calendar.timeZone; f.dateFormat = format; return f
    }
    private static let civilFormatter = formatter("yyyy-MM-dd", locale: "en_US_POSIX")
    private static let monthFormatter = formatter("MMMM yyyy", locale: "it_IT")
    private static let labelFormatter = formatter("EEE d MMM", locale: "it_IT")
    private static let shortMonthFormatter = formatter("LLL", locale: "it_IT")
    static func day(_ date: Date = Date()) -> String { civilFormatter.string(from: date) }
    static func date(_ day: String) -> Date { civilFormatter.date(from: String(day.prefix(10))) ?? Date() }
    static func month(_ date: Date = Date()) -> String { String(day(date).prefix(7)) }
    static func adding(_ count: Int, to day: String, component: Calendar.Component = .day) -> String {
        self.day(calendar.date(byAdding: component, value: count, to: date(day)) ?? date(day))
    }
    static func monthTitle(_ month: String) -> String { monthFormatter.string(from: date(month + "-01")).capitalized }
    static func label(_ day: String) -> String { label(date(day)) }
    static func label(_ date: Date) -> String { labelFormatter.string(from: date) }
    static func monthAbbreviation(_ month: String) -> String {
        shortMonthFormatter.string(from: date(month + "-01")).replacingOccurrences(of: ".", with: "").capitalized
    }
    static func grid(_ month: String) -> [String] { gridDates(month).map { day($0) } }
    static func gridDates(_ month: String) -> [Date] {
        let first = date(month + "-01"), weekday = calendar.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let cells = ((count + offset + 6) / 7) * 7
        return (0..<cells).map { calendar.date(byAdding: .day, value: $0 - offset, to: first)! }
    }
    static func occurrenceDays(start: String, frequency: String, until: String, low: String, high: String) -> [String] {
        var result: [String] = []
        let base = date(start)
        for index in 0..<12000 {
            var current = start
            if index > 0 {
                if frequency == "none" || frequency.isEmpty { break }
                if frequency == "weekly" { current = adding(index * 7, to: start) }
                else {
                    let parts = calendar.dateComponents([.year, .month, .day], from: base)
                    let first = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))!
                    let next = calendar.date(byAdding: .month, value: index * (frequency == "yearly" ? 12 : 1), to: first)!
                    let last = calendar.range(of: .day, in: .month, for: next)!.count
                    current = day(calendar.date(byAdding: .day, value: min(parts.day!, last) - 1, to: next)!)
                }
            }
            if current >= high || (!until.isEmpty && current > until) { break }
            if current >= low { result.append(current) }
        }
        return result
    }
}
enum ShiftKind: String, CaseIterable, Identifiable {
    case morning, afternoon, night, rest, holiday, erase
    var id: String { rawValue }
    var title: String { switch self { case .morning: return "Mattina"; case .afternoon: return "Pomeriggio"; case .night: return "Notte"; case .rest: return "Riposo"; case .holiday: return "Ferie"; case .erase: return "Cancella" } }
    var letter: String { switch self { case .morning: return "M"; case .afternoon: return "P"; case .night: return "N"; case .rest: return "R"; case .holiday: return "F"; case .erase: return "" } }
    var time: String { switch self { case .morning: return "06:00–14:00"; case .afternoon: return "14:00–22:00"; case .night: return "22:00–06:00"; default: return "" } }
}
enum NativeValidation {
    static func canIncludeInSnapshot(_ summary: Record, account: String, type: String, day: String, editing: Bool) -> Bool {
        let anchor = summary.text(account == "Revolut" ? "balanceDate" : "assetDate")
        return !editing && type != "Trasferimento" && !anchor.isEmpty && !day.isEmpty && day <= anchor
    }
    static func dailyBudget(_ summary: Record, day: String = CivilDate.day(), month: String? = nil) -> (days: Int, low: Double, high: Double) {
        let selected = month ?? String(day.prefix(7))
        let count = CivilDate.calendar.range(of: .day, in: .month, for: CivilDate.date(selected + "-01"))?.count ?? 30
        let days = selected < String(day.prefix(7)) ? 0 : selected > String(day.prefix(7)) ? count : max(1, count - CivilDate.calendar.component(.day, from: CivilDate.date(day)) + 1)
        guard days > 0 else { return (0, 0, 0) }
        return (days, summary.amount("monthlyRemaining") / Double(days), (summary.amount("monthlySalary") - summary.amount("monthlySpent")) / Double(days))
    }
    static func snapshot(_ data: Data) throws -> Record {
        guard data.count <= 5_000_000 else { throw Message(text: "Il file è troppo grande.") }
        return try financeResponse(JSONDecoder().decode(JSONValue.self, from: data))
    }
    /// Network responses have already been decoded. Keep import-file size limits
    /// separate, and avoid encoding and decoding a large API response a second time.
    static func financeResponse(_ value: JSONValue) throws -> Record {
        guard case .object(let object) = value else { throw Message(text: "Risposta finanziaria non valida.") }
        let summary = object.record("summary")
        for key in ["budget", "committedCurrent", "remainingFree"] {
            guard case .number(let n)? = summary[key], n.isFinite else { throw Message(text: "Il JSON non è uno snapshot finanziario valido.") }
        }
        guard case .array(let rows)? = object["transactions"] else { throw Message(text: "Nel JSON manca l’elenco movimenti.") }
        var ids = Set<Int>()
        for row in rows {
            let r = row.object
            guard case .number(let amount)? = r["amount"], amount.isFinite,
                  r.integer("row") > 0, r.amount("row") == Double(r.integer("row")), ids.insert(r.integer("row")).inserted,
                  !r.text("name").isEmpty, r.text("date").range(of: #"^20\d\d-(0[1-9]|1[0-2])-([0-2]\d|3[01])$"#, options: .regularExpression) != nil,
                  CivilDate.day(CivilDate.date(r.text("date"))) == r.text("date") else {
                throw Message(text: "Il JSON contiene un movimento non valido.")
            }
        }
        return object
    }
    static func shares(cents: Int, months: Int) -> [Int] {
        guard cents > 0, (1...60).contains(months) else { return [] }
        return (0..<months).map { cents / months + ($0 < cents % months ? 1 : 0) }
    }
}

struct NativeSavingsProgress {
    let assets: Double
    let emergency: Double
    let target: Double
    let months: Int
    init(summary: Record, planning: Record, day: String = CivilDate.day()) {
        assets = summary.amount("budget")
        emergency = max(0, planning.amount("goal"))
        // The existing shared setting is the emergency reserve. The next savings
        // milestone is only a fallback for old archives; explicit targets stay fixed.
        let base = max(assets, emergency)
        target = planning.amount("savingsTarget") > 0 ? planning.amount("savingsTarget") : max(5000, (floor(base / 5000) + 1) * 5000)
        months = max(1, 13 - (Int(day.dropFirst(5).prefix(2)) ?? 12))
    }
    var reserved: Double { min(max(0, assets), emergency) }
    var other: Double { max(0, assets - reserved) }
    var missing: Double { max(0, target - assets) }
    var monthly: Double { missing / Double(months) }
}

struct NativeWeather: Equatable {
    let temperature: Double
    let low: Double
    let high: Double
    let code: Int
    let change: String
    static func group(_ code: Int) -> String {
        if code == 0 { return "Sereno" }; if code < 4 { return "Nuvoloso" }
        if code < 50 { return "Nebbia" }; if code < 70 { return "Pioggia" }
        if code < 80 { return "Neve" }; if code < 95 { return "Rovesci" }; return "Temporale"
    }
    static func parse(_ root: Record) -> NativeWeather? {
        let current = root.record("current"), daily = root.record("daily"), hourly = root.record("hourly")
        guard case .number(let temperature)? = current["temperature_2m"], temperature.isFinite,
              case .number(let low)? = daily["temperature_2m_min"]?.array.first,
              case .number(let high)? = daily["temperature_2m_max"]?.array.first, low.isFinite, high.isFinite else { return nil }
        let now = current.text("time"), code = current.integer("weather_code")
        let times = hourly["time"]?.array ?? [], codes = hourly["weather_code"]?.array ?? []
        var change = "Nessun cambio nelle prossime ore"
        for (index, time) in times.enumerated() where index < codes.count && time.string > now {
            let next = Int(codes[index].number)
            if group(next) != group(code) {
                let tomorrow = String(time.string.prefix(10)) != String(now.prefix(10))
                change = group(next) + (tomorrow ? " domani alle " : " dalle ") + String(time.string.suffix(5)); break
            }
        }
        return NativeWeather(temperature: temperature, low: low, high: high, code: code, change: change)
    }
}

enum NativeExtraState {
    static func title(_ status: String) -> String {
        switch status { case "Programmato", "Previsto": return "In corso"; case "Pagato": return "Pagata"; case "Annullato": return "Annullata"; default: return status }
    }
    // A settlement closes the entire cycle, including previous months. Allocate
    // the actual paid total in exact cents for display; do not rewrite the plan.
    static func displayedCents(_ row: Record, plan: Record) -> Int {
        guard row.text("status") == "Pagato",
              let settled = plan.records("settlements").first(where: { $0.integer("cycle_id") == row.integer("cycle_id") }) else { return row.integer("amount_cents") }
        let start = row.text("start_month"), end = row.text("end_month"), month = row.text("month")
        func ordinal(_ key: String) -> Int { (Int(key.prefix(4)) ?? 0) * 12 + (Int(key.suffix(2)) ?? 0) }
        let count = ordinal(end) - ordinal(start) + 1, index = ordinal(month) - ordinal(start)
        let shares = NativeValidation.shares(cents: max(0, row.integer("total_cents") - settled.integer("planned_cents") + settled.integer("actual_cents")), months: count)
        return shares.indices.contains(index) ? shares[index] : row.integer("amount_cents")
    }
}
