import Foundation

/// CATEGORY-ADMIN-2026-11-24: the expense groups with their items and the income categories are edited in
/// Admin on the site (setting «finance-categories») and read by the app at every refresh, so a change does
/// not need a new build. Without the setting the built-in list stays (NativeExpenseGroups.builtIn).
struct NativeFinanceCategoryDoc: Codable, Equatable {
    struct Group: Codable, Equatable { var name: String; var items: [String] }
    var groups: [Group]
    var income: [String]?

    /// Only usable groups: a name and at least one item, without blanks or repeated items.
    var cleaned: NativeFinanceCategoryDoc {
        var seen = Set<String>()
        let groups = groups.compactMap { group -> Group? in
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let items = group.items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
            return name.isEmpty || items.isEmpty ? nil : Group(name: name, items: items)
        }
        let income = (income ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return NativeFinanceCategoryDoc(groups: groups, income: income.isEmpty ? nil : income)
    }
}

enum NativeFinanceCategories {
    static let key = "native-finance-categories-95"

    /// The list saved from the site, if any.
    static var current: NativeFinanceCategoryDoc? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let doc = try? JSONDecoder().decode(NativeFinanceCategoryDoc.self, from: data), !doc.groups.isEmpty else { return nil }
        return doc
    }
    /// Server doc → local copy; an empty or missing doc goes back to the built-in list.
    static func store(_ doc: Record) {
        guard let data = try? JSONEncoder().encode(JSONValue.object(doc)),
              let decoded = try? JSONDecoder().decode(NativeFinanceCategoryDoc.self, from: data) else {
            UserDefaults.standard.removeObject(forKey: key); return
        }
        let clean = decoded.cleaned
        if clean.groups.isEmpty { UserDefaults.standard.removeObject(forKey: key); return }
        if let encoded = try? JSONEncoder().encode(clean) { UserDefaults.standard.set(encoded, forKey: key) }
    }
    /// Expense items to choose from: the site list, else the built-in contract.
    static var expenseChoices: [String] { current.map { $0.groups.flatMap(\.items) } ?? Input.categories }
    static var incomeChoices: [String] { current?.income ?? NativePlatformContract.incomeCategories }
}
