import Foundation
import Combine

/// Nutrition goals (NUTRITION-GOALS-93-2026-11-21, build 93 "Obiettivi" sheet).
/// Calories follow the TDEE with a deficit or surplus, or are fixed; protein and
/// fat are grams or grams per kg of the 7-day average weight; carbohydrates take
/// the calories that remain.
struct NativeNutritionGoals: Codable, Equatable {
    enum CalorieMode: String, Codable, CaseIterable { case tdee, fixed }
    enum MacroUnit: String, Codable, CaseIterable { case grams, perKG }

    var calorieMode: CalorieMode = .tdee
    var adjustment: Double = -300
    var fixedCalories: Double = 2450
    var proteinUnit: MacroUnit = .perKG
    var protein: Double = 2.0
    var fatUnit: MacroUnit = .perKG
    var fat: Double = 0.9

    static let standard = NativeNutritionGoals()
    static let adjustmentStep = 50.0
    static let adjustmentRange = -1500.0...1500.0
    static let calorieRange = 800.0...6000.0

    struct Targets: Equatable {
        let calories: Double
        let protein: Double
        let carbohydrate: Double
        let fat: Double
    }

    func calories(tdee: Double?) -> Double? {
        let value: Double
        switch calorieMode {
        case .tdee:
            guard let tdee, tdee.isFinite else { return nil }
            value = tdee + min(max(adjustment, Self.adjustmentRange.lowerBound), Self.adjustmentRange.upperBound)
        case .fixed: value = fixedCalories
        }
        guard value.isFinite, Self.calorieRange.contains(value) else { return nil }
        return value
    }

    func grams(_ value: Double, unit: MacroUnit, weight: Double?) -> Double? {
        guard value.isFinite, value >= 0 else { return nil }
        switch unit {
        case .grams: return value
        case .perKG:
            guard let weight, weight.isFinite, weight > 0 else { return nil }
            return value * weight
        }
    }

    /// Nil when calories cannot be set (no TDEE yet) or a per-kg macro has no weight.
    func targets(tdee: Double?, weight: Double?) -> Targets? {
        guard let kcal = calories(tdee: tdee),
              let protein = grams(protein, unit: proteinUnit, weight: weight),
              let fat = grams(fat, unit: fatUnit, weight: weight) else { return nil }
        let carbohydrate = max(0, (kcal - protein * 4 - fat * 9) / 4)
        return Targets(calories: kcal.rounded(), protein: protein.rounded(), carbohydrate: carbohydrate.rounded(), fat: fat.rounded())
    }

    /// Mean of the weigh-ins in the seven days up to `now`; the last weigh-in when none.
    static func averageWeight(_ days: [HealthDay], now: Date = .now, calendar: Calendar = .current) -> Double? {
        let today = calendar.startOfDay(for: now)
        let weighed = days.filter { $0.date <= now && ($0.weight ?? 0) > 0 && ($0.weight?.isFinite ?? false) }.sorted { $0.date < $1.date }
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return weighed.last?.weight }
        let recent = weighed.filter { $0.date >= start }.compactMap(\.weight)
        return NativeHealthMath.mean(recent) ?? weighed.last?.weight
    }
}

/// Goals and TDEE criteria chosen on this iPhone. They are presentation settings,
/// not records: they stay in UserDefaults and never travel to the server.
@MainActor final class NativeHealthPreferences: ObservableObject {
    static let shared = NativeHealthPreferences()
    private static let goalsKey = "native-nutrition-goals-93"
    private static let criteriaKey = "native-tdee-criteria-93"
    private let defaults: UserDefaults

    @Published var goals: NativeNutritionGoals { didSet { save(goals, Self.goalsKey) } }
    @Published var criteria: NativeTDEECriteria { didSet { save(criteria.clamped, Self.criteriaKey) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        goals = Self.load(NativeNutritionGoals.self, Self.goalsKey, defaults) ?? .standard
        criteria = (Self.load(NativeTDEECriteria.self, Self.criteriaKey, defaults) ?? .standard).clamped
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
    private static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
