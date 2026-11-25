import Foundation

/// FOOD-DB-RESET-2026-11-25: one row per food in the lists; the version (cooking, skin) is chosen
/// after tapping it, with the bone weighing that already existed.
enum NativeFoodVariants {
    static let axisOrder = ["Stato", "Pelle"]
    /// FOOD-VARIANT-DEFAULT-2026-11-25: raw first, cooked second, then the other preparations.
    static let stateOrder = ["Crudo", "Fresco", "Cotto", "Lesso", "Al vapore", "Alla piastra", "Al forno", "Al tegamino", "Sode", "Secco"]
    struct Row { let food: NativeGenericFood; let count: Int }
    struct Axis: Identifiable { let name: String; let values: [String]; var id: String { name } }

    /// Keeps the first food of each group (the best ranked or best matching) and counts its versions.
    /// With `preferDefault` (no search typed) the row opens on the raw version; while searching it
    /// opens on the version that matched best («coscia lessa» opens on Lesso).
    static func collapse(_ foods: [NativeGenericFood], preferDefault: Bool = false) -> [Row] {
        var counts: [String: Int] = [:]
        var best: [String: NativeGenericFood] = [:]
        for food in foods {
            guard let key = groupKey(food) else { continue }
            counts[key, default: 0] += 1
            if preferDefault, let current = best[key] { if rank(food) < rank(current) { best[key] = food } } else if best[key] == nil { best[key] = food }
        }
        var seen = Set<String>()
        var out: [Row] = []
        for food in foods {
            guard let key = groupKey(food) else { out.append(Row(food: food, count: 1)); continue }
            if seen.insert(key).inserted { out.append(Row(food: best[key] ?? food, count: counts[key] ?? 1)) }
        }
        return out
    }
    static func rank(_ food: NativeGenericFood) -> Int {
        let state = stateOrder.firstIndex(of: food.variant?["Stato"] ?? "") ?? 50
        return state * 2 + (food.variant?["Pelle"] == "Con pelle" ? 1 : 0)
    }
    private static func groupKey(_ food: NativeGenericFood) -> String? {
        guard let group = food.group, food.variant?.isEmpty == false else { return nil }
        return food.family.rawValue + "|" + group
    }

    /// Every version of the same food, from the synced list (or the bundled base before the first sync).
    static func siblings(of food: NativeGenericFood, in pool: [NativeGenericFood]) -> [NativeGenericFood] {
        guard let key = groupKey(food) else { return [food] }
        let list = pool.filter { Self.groupKey($0) == key }
        return list.isEmpty ? [food] : list
    }
    @MainActor static func pool() -> [NativeGenericFood] {
        let data = UserDefaults.standard.data(forKey: NativeOnlineSync.foodsKey) ?? Data()
        let synced = (try? JSONDecoder().decode([NativeGenericFood].self, from: data)) ?? []
        return synced.contains { $0.origin == "base" } ? synced : synced + NativeGenericFood.baseFoods
    }

    /// Axes with their values in a stable order (Stato before Pelle, values as they appear).
    static func axes(_ siblings: [NativeGenericFood]) -> [Axis] {
        var names: [String] = []
        var values: [String: [String]] = [:]
        for food in siblings {
            for (axis, value) in (food.variant ?? [:]).sorted(by: { $0.key < $1.key }) {
                if !names.contains(axis) { names.append(axis) }
                if !(values[axis] ?? []).contains(value) { values[axis, default: []].append(value) }
            }
        }
        if var states = values["Stato"] {
            states.sort { (stateOrder.firstIndex(of: $0) ?? 50) < (stateOrder.firstIndex(of: $1) ?? 50) }
            values["Stato"] = states
        }
        names.sort { a, b in
            let ia = axisOrder.firstIndex(of: a) ?? 99, ib = axisOrder.firstIndex(of: b) ?? 99
            return ia == ib ? a < b : ia < ib
        }
        return names.map { Axis(name: $0, values: values[$0] ?? []) }.filter { $0.values.count > 1 }
    }

    /// The version with `axis` = `value` and the other axes unchanged; if the catalog has no such
    /// combination, the first version with that value.
    static func pick(_ siblings: [NativeGenericFood], from current: NativeGenericFood, axis: String, value: String) -> NativeGenericFood? {
        var wanted = current.variant ?? [:]; wanted[axis] = value
        return siblings.first { $0.variant == wanted } ?? siblings.first { $0.variant?[axis] == value }
    }
}
