import Foundation

/// FOOD-DB-RESET-2026-11-25: one row per food in the lists; the version (cooking, skin) is chosen
/// after tapping it, with the bone weighing that already existed.
enum NativeFoodVariants {
    static let axisOrder = ["Stato", "Pelle"]
    struct Row { let food: NativeGenericFood; let count: Int }
    struct Axis: Identifiable { let name: String; let values: [String]; var id: String { name } }

    /// Keeps the first food of each group (the best ranked or best matching) and counts its versions.
    static func collapse(_ foods: [NativeGenericFood]) -> [Row] {
        var counts: [String: Int] = [:]
        for food in foods { if let key = groupKey(food) { counts[key, default: 0] += 1 } }
        var seen = Set<String>()
        var out: [Row] = []
        for food in foods {
            guard let key = groupKey(food) else { out.append(Row(food: food, count: 1)); continue }
            if seen.insert(key).inserted { out.append(Row(food: food, count: counts[key] ?? 1)) }
        }
        return out
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
