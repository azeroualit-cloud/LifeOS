import Foundation
import HealthKit
import Combine

struct NativeNutritionEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var revision: Int
    var date: Date
    var protein: Decimal
    var carbohydrate: Decimal
    var fat: Decimal
    var confirmed: Bool
    var deletionPending: Bool? = nil
    var fibre: Decimal? = nil
    var labelCalories: Decimal? = nil
    var portionGrams: Decimal? = nil
    var foodName: String? = nil
    var foodID: String? = nil
    var boneInWeightGrams: Decimal? = nil
    var nutrientValues: [String: NativeNutrientAmount]? = nil
    var sharedNutrientKeys: [String]? = nil
    var cocktailServings: Decimal? = nil
    var alcoholGrams: Decimal? = nil
    var standardDrinks: Decimal? { alcoholGrams.map { $0 / 12 } }
    var calories: Decimal { labelCalories ?? (protein * 4 + carbohydrate * 4 + fat * 9) }

    /// Label values are per 100 g; persisted measurements always describe the portion.
    static func portion(id: UUID, date: Date, protein: Decimal, carbohydrate: Decimal,
                        fat: Decimal, fibre: Decimal?, calories: Decimal, grams: Decimal) -> Self? {
        let values = [protein, carbohydrate, fat, fibre ?? 0, calories, grams]
        guard values.allSatisfy({ !$0.isNaN && $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }),
              grams > 0, calories > 0 else { return nil }
        let factor = grams / 100
        return .init(id: id, revision: 0, date: date, protein: protein * factor,
                     carbohydrate: carbohydrate * factor, fat: fat * factor, confirmed: false,
                     fibre: fibre.map { $0 * factor }, labelCalories: calories * factor, portionGrams: grams)
    }
    /// Direct totals. Snapshot the automatic energy so historical entries never change formula.
    static func direct(id: UUID, date: Date, protein: Decimal, carbohydrate: Decimal, fat: Decimal, fibre: Decimal, preserving old: Self? = nil) -> Self? {
        let values = [protein, carbohydrate, fat, fibre]
        guard values.allSatisfy({ !$0.isNaN && $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) else { return nil }
        if var old, old.id == id, old.protein == protein, old.carbohydrate == carbohydrate, old.fat == fat, (old.fibre ?? 0) == fibre {
            old.date = date; return old
        }
        let energy = protein * 4 + carbohydrate * 4 + fat * 9 + fibre * 2
        guard !energy.isNaN, energy > 0, NSDecimalNumber(decimal: energy).doubleValue.isFinite else { return nil }
        return .init(id: id, revision: 0, date: date, protein: protein, carbohydrate: carbohydrate, fat: fat, confirmed: false, fibre: fibre, labelCalories: energy, foodName: old?.foodName, foodID: old?.foodID, nutrientValues: old?.nutrientValues, sharedNutrientKeys: old?.sharedNutrientKeys, cocktailServings: old?.cocktailServings, alcoholGrams: old?.alcoholGrams)
    }
    static func grams(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        guard value.range(of: "^[0-9]+([.,][0-9]+)?$", options: .regularExpression) != nil,
              let number = Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")), number >= 0, !number.isNaN else { return nil }
        return number
    }
}

@MainActor protocol NativeNutritionWriting {
    func authorize(includeFibre: Bool) async throws
    func authorizeNutrients(for entry: NativeNutritionEntry) async -> Set<String>
    func write(_ entry: NativeNutritionEntry) async throws
    func delete(_ entry: NativeNutritionEntry) async throws
}

extension NativeNutritionWriting {
    func authorizeNutrients(for entry: NativeNutritionEntry) async -> Set<String> { [] }
}

@MainActor final class NativeHealthNutritionWriter: NativeNutritionWriting {
    private let health = HKHealthStore()
    private static let alcoholKey = "standardDrinks"
    private static let folateKey = "folateMass"
    private static let vitaminKKey = "vitaminK"
    private static let identifiers: [HKQuantityTypeIdentifier] = [.dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryEnergyConsumed, .dietaryFiber]
    func authorize(includeFibre: Bool) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Message(text: "Apple Salute non è disponibile su questo dispositivo.") }
        let types = Self.identifiers.prefix(includeFibre ? 5 : 4).map { HKObjectType.quantityType(forIdentifier: $0)! }
        try await health.requestAuthorization(toShare: Set(types), read: [])
        guard types.allSatisfy({ health.authorizationStatus(for: $0) == .sharingAuthorized }) else { throw Message(text: "Autorizza la scrittura di tutti i macronutrienti e delle calorie in Apple Salute.") }
    }
    func authorizeNutrients(for entry: NativeNutritionEntry) async -> Set<String> {
        let candidates = Self.additionalValues(for: entry).keys.compactMap { key -> (String, HKQuantityType)? in
            guard let type = Self.nutrientType(for: key) else { return nil }
            return (key, type)
        }
        guard !candidates.isEmpty else { return [] }
        let unrequested = candidates.map { $0.1 }.filter { health.authorizationStatus(for: $0) == .notDetermined }
        if !unrequested.isEmpty {
            try? await health.requestAuthorization(toShare: Set(unrequested), read: [])
        }
        return Set(candidates.filter { health.authorizationStatus(for: $0.1) == .sharingAuthorized }.map { $0.0 })
    }
    func write(_ entry: NativeNutritionEntry) async throws {
        try await health.save(Self.samples(for: entry))
    }
    static func samples(for entry: NativeNutritionEntry) -> [HKQuantitySample] {
        let amounts = [entry.protein, entry.carbohydrate, entry.fat, entry.calories] + (entry.fibre.map { [$0] } ?? [])
        let base = zip(identifiers, amounts).enumerated().map { index, pair in
            var metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "lifeos-nutrition-\(entry.id.uuidString)-\(index)",
                HKMetadataKeySyncVersion: NSNumber(value: entry.revision)
            ]
            if let name = entry.foodName { metadata[HKMetadataKeyFoodType] = name }
            return HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: pair.0)!, quantity: HKQuantity(unit: index == 3 ? .kilocalorie() : .gram(), doubleValue: NSDecimalNumber(decimal: pair.1).doubleValue), start: entry.date, end: entry.date,
                metadata: metadata)
        }
        let values = additionalValues(for: entry)
        let additional = (entry.sharedNutrientKeys ?? []).compactMap { key -> HKQuantitySample? in
            guard let type = nutrientType(for: key), let value = values[key] else { return nil }
            var metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: nutrientSyncID(for: entry, key: key),
                HKMetadataKeySyncVersion: NSNumber(value: entry.revision)
            ]
            if let name = entry.foodName { metadata[HKMetadataKeyFoodType] = name }
            if let estimate = value.estimateSource { metadata["LifeOSNutrientEstimateSource"] = estimate }
            let unit: HKUnit
            switch key {
            case alcoholKey: unit = .count()
            case folateKey, vitaminKKey: unit = .gramUnit(with: .micro)
            default:
                unit = .gramUnit(with: NativeTrackedNutrient(rawValue: key)?.unit == "µg" ? .micro : .milli)
            }
            return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: NSDecimalNumber(decimal: value.amount).doubleValue),
                                    start: entry.date, end: entry.date, metadata: metadata)
        }
        return base + additional
    }

    private static func additionalValues(for entry: NativeNutritionEntry) -> [String: NativeNutrientAmount] {
        var values = entry.nutrientValues ?? [:]
        if let k1 = values["vitaminK1"], let k2 = values["vitaminK2"] {
            let sources = [k1.estimateSource, k2.estimateSource].compactMap { $0 }
            values[vitaminKKey] = .init(amount: k1.amount + k2.amount,
                                       estimateSource: sources.isEmpty ? nil : sources.joined(separator: ", "))
        }
        if let drinks = entry.standardDrinks {
            values[alcoholKey] = .init(amount: drinks, estimateSource: "LifeOS: ricetta cocktail; 1 UA = 12 g")
        }
        return values
    }

    private static func nutrientType(for key: String) -> HKQuantityType? {
        switch key {
        case alcoholKey: return HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)
        case folateKey: return HKObjectType.quantityType(forIdentifier: .dietaryFolate)
        case vitaminKKey: return HKObjectType.quantityType(forIdentifier: .dietaryVitaminK)
        default: break
        }
        let identifier: HKQuantityTypeIdentifier? = switch NativeTrackedNutrient(rawValue: key) {
        case .vitaminC: .dietaryVitaminC
        case .zinc: .dietaryZinc
        case .vitaminA: .dietaryVitaminA
        case .vitaminD: .dietaryVitaminD
        case .vitaminE: .dietaryVitaminE
        case .vitaminB1: .dietaryThiamin
        case .vitaminB2: .dietaryRiboflavin
        case .vitaminB3: .dietaryNiacin
        case .vitaminB5: .dietaryPantothenicAcid
        case .vitaminB6: .dietaryVitaminB6
        case .vitaminB12: .dietaryVitaminB12
        case .calcium: .dietaryCalcium
        case .chloride: .dietaryChloride
        case .copper: .dietaryCopper
        case .iron: .dietaryIron
        case .iodine: .dietaryIodine
        case .magnesium: .dietaryMagnesium
        case .manganese: .dietaryManganese
        case .phosphorus: .dietaryPhosphorus
        case .potassium: .dietaryPotassium
        case .selenium: .dietarySelenium
        case .sodium: .dietarySodium
        default: nil
        }
        return identifier.flatMap { HKObjectType.quantityType(forIdentifier: $0) }
    }

    private static func nutrientSyncID(for entry: NativeNutritionEntry, key: String) -> String {
        "lifeos-nutrition-\(entry.id.uuidString)-nutrient-\(key)"
    }

    func delete(_ entry: NativeNutritionEntry) async throws {
        // Use the same IDs and types as write, including only the optional samples
        // authorized at the time of the write, even if permission has since changed.
        for sample in Self.samples(for: entry) {
            guard let syncID = sample.metadata?[HKMetadataKeySyncIdentifier] as? String else { continue }
            let type = sample.quantityType
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: [syncID])
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                health.deleteObjects(of: type, predicate: predicate) { success, _, error in
                    if let error { continuation.resume(throwing: error) }
                    else if success { continuation.resume() }
                    else { continuation.resume(throwing: Message(text: "Eliminazione da Apple Salute non confermata. Riprova dalla cronologia.")) }
                }
            }
        }
    }

}

@MainActor final class NativeNutritionStore: ObservableObject {
    static let shared = NativeNutritionStore()
    @Published private(set) var entries: [NativeNutritionEntry] = []
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    private let writer: any NativeNutritionWriting
    private let file: URL
    private var loaded = false
    init(directory: URL? = nil, writer: (any NativeNutritionWriting)? = nil) {
        self.writer = writer ?? NativeHealthNutritionWriter()
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LifeOSNutrition", isDirectory: true)
        file = root.appendingPathComponent("entries.json")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { entries = try JSONDecoder().decode([NativeNutritionEntry].self, from: Data(contentsOf: file)) }
            loaded = true
        } catch { self.error = "Archivio nutrizione non disponibile: " + error.localizedDescription }
    }
    private func persist(_ rows: [NativeNutritionEntry]) throws {
        try JSONEncoder().encode(rows).write(to: file, options: [.atomic, .completeFileProtection])
        entries = rows
    }
    func save(_ value: NativeNutritionEntry, retry: Bool = false, expectedRevision: Int? = nil) async -> Bool {
        guard loaded, !busy else { return false }
        guard !entries.contains(where: { $0.deletionPending == true }) else {
            error = "Completa prima l’eliminazione in sospeso dalla cronologia."
            return false
        }
        let amounts = [value.protein, value.carbohydrate, value.fat, value.fibre ?? 0, value.calories]
        guard amounts.allSatisfy({ !$0.isNaN && $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }),
              value.calories > 0 else { return false }
        busy = true; defer { busy = false }
        error = nil
        do {
            try await writer.authorize(includeFibre: value.fibre != nil)
            let old = entries.first { $0.id == value.id }
            if let expectedRevision, old?.revision != expectedRevision {
                throw Message(text: "La registrazione è cambiata o è stata eliminata. Riaprila dalla cronologia prima di modificarla.")
            }
            if entries.contains(where: { !$0.confirmed && $0.id != value.id }) { throw Message(text: "Completa prima la registrazione in sospeso usando Riprova.") }
            var pending = value
            if retry, let old, !old.confirmed { pending = old }
            else {
                pending.revision = (old?.revision ?? 0) + 1; pending.confirmed = false
                let authorized = await writer.authorizeNutrients(for: pending)
                let previouslyShared = Set(old?.sharedNutrientKeys ?? [])
                let shareKeys = previouslyShared.union(authorized).sorted()
                pending.sharedNutrientKeys = shareKeys.isEmpty ? nil : shareKeys
                try persist(entries.filter { $0.id != pending.id } + [pending])
            }
            try await writer.write(pending)
            pending.confirmed = true
            try persist(entries.filter { $0.id != pending.id } + [pending])
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func delete(_ id: UUID) async -> Bool {
        guard loaded, !busy, var entry = entries.first(where: { $0.id == id }) else { return false }
        busy = true; error = nil
        defer { busy = false }
        do {
            // Commit intent before the first HealthKit side effect; keep the row
            // until every type has acknowledged deletion and the index is saved.
            entry.deletionPending = true
            try persist(entries.map { $0.id == id ? entry : $0 })
            try await writer.authorize(includeFibre: entry.fibre != nil)
            try await writer.delete(entry)
            try persist(entries.filter { $0.id != id })
            return true
        } catch { self.error = "Eliminazione da completare: " + error.localizedDescription; return false }
    }

}
