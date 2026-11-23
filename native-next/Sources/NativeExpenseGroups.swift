import Foundation

/// Spending categories in nine ordered groups, each with its items (preview 93 «Nuova spesa - menu
/// categoria»). The stored category stays the item («Benzina»), so the server is unchanged; the
/// group («Auto») is derived for menus, filters and labels.
enum NativeExpenseGroups {
    static let order: [(group: String, items: [String])] = [
        ("Casa", ["Affitto", "Condominio", "Utenze", "Elettricità", "Gas", "Acqua", "Arredamento e casa", "Casa"]),
        ("Auto", ["Benzina", "Assicurazione", "Bollo", "Manutenzione auto", "Auto"]),
        ("Spesa", ["Alimentari"]),
        ("Mangiare fuori", ["Ristorazione"]),
        ("Abbonamenti", ["Abbonamenti"]),
        ("Salute e sport", ["Palestra", "Dentista", "Farmaci e visite", "Salute"]),
        ("Persona", ["Shopping"]),
        ("Svago", ["Svago", "Viaggi"]),
        ("Altro", ["Altro"]),
    ]
    /// The group of an item; unknown items go to «Altro».
    static func group(of item: String) -> String {
        order.first { $0.items.contains(item) }?.group ?? "Altro"
    }
    /// The available choices arranged by group, in order; items not listed join «Altro».
    static func grouped(_ choices: [String]) -> [(group: String, items: [String])] {
        var placed = Set<String>()
        var result: [(group: String, items: [String])] = []
        for entry in order {
            let items = entry.items.filter { choices.contains($0) }
            placed.formUnion(items)
            if !items.isEmpty { result.append((entry.group, items)) }
        }
        let rest = choices.filter { !placed.contains($0) }
        if !rest.isEmpty {
            if let index = result.firstIndex(where: { $0.group == "Altro" }) { result[index].items = rest + result[index].items }
            else { result.append(("Altro", rest)) }
        }
        return result
    }
    /// «Auto · Benzina», or just the item when group and item coincide («Abbonamenti»).
    static func label(_ item: String) -> String {
        let group = group(of: item)
        return group == item ? item : group + " · " + item
    }
}
