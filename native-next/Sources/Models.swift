import Foundation

struct Finance: Codable {
    struct Summary: Codable {
        let budget: Double
        let committedCurrent: Double
        let remainingFree: Double
        let account: String?
    }
    struct Movement: Codable, Identifiable {
        let row: Int
        let date: String
        let name: String
        let amount: Double
        let account: String
        let category: String
        var id: Int { row }
    }
    let summary: Summary
    let transactions: [Movement]
}
struct Expense: Codable, Identifiable {
    let requestId: String
    let amount: Double
    let date: String
    let name: String
    let category: String
    let months: Int
    let budgetTreatment: String
    var type = "Spesa"
    var account = "Trade Republic"
    var note = ""
    var includedInSnapshot = false
    var id: String { requestId }
}
struct Archive: Codable {
    var finance: Finance?
    var queue: [Expense] = []
    var confirmed: [Expense] = []
    var refreshedAt: Date?
}
enum Input {
    static let categories = NativePlatformContract.expenseCategories
    static func cents(_ raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard text.range(of: #"^\d{1,7}(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              value > 0, value <= 1_000_000 else { return nil }
        return NSDecimalNumber(decimal: value * 100).intValue
    }
    static func day(_ date: Date) -> String { CivilDate.day(date) }
    static func expense(amount: String, name: String, category: String, date: Date, months: Int, treatment: String) throws -> Expense {
        guard let cents = cents(amount), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 120, categories.contains(category), (1...12).contains(months),
              ["auto", "ordinary", "planned", "savings"].contains(treatment), day(date) <= day(Date()) else {
            throw Message(text: "Controlla importo, descrizione e data.")
        }
        return Expense(requestId: UUID().uuidString, amount: Double(cents) / 100, date: day(date),
                       name: name.trimmingCharacters(in: .whitespacesAndNewlines), category: category,
                       months: months, budgetTreatment: treatment)
    }
}
struct Message: LocalizedError {
    let text: String
    var errorDescription: String? { text }
}
extension Double {
    private static let lifeOSEuroFormatter: NumberFormatter = {
        let value = NumberFormatter()
        value.locale = Locale(identifier: "en_US_POSIX"); value.numberStyle = .currency; value.currencyCode = "EUR"
        value.currencySymbol = "€"; value.decimalSeparator = ","; value.currencyDecimalSeparator = ","
        value.groupingSeparator = "."; value.currencyGroupingSeparator = "."
        value.positiveFormat = "#,##0.00 ¤"; value.negativeFormat = "-#,##0.00 ¤"
        value.usesGroupingSeparator = true; value.groupingSize = 3
        value.minimumFractionDigits = 2; value.maximumFractionDigits = 2
        return value
    }()
    var euro: String { Self.lifeOSEuroFormatter.string(from: NSNumber(value: self)) ?? "—" }
}
