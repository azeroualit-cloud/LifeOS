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
    var boneInWeightGrams: Decimal? = nil
    var calories: Decimal { labelCalories ?? (protein * 4 + carbohydrate * 4 + fat * 9) }

    /// Label values are per 100 g; persisted measurements always describe the portion.
    static func portion(id: UUID, date: Date, protein: Decimal, carbohydrate: Decimal,
                        fat: Decimal, fibre: Decimal, calories: Decimal, grams: Decimal) -> Self? {
        let values = [protein, carbohydrate, fat, fibre, calories, grams]
        guard values.allSatisfy({ !$0.isNaN && $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }),
              grams > 0, calories > 0 else { return nil }
        let factor = grams / 100
        return .init(id: id, revision: 0, date: date, protein: protein * factor,
                     carbohydrate: carbohydrate * factor, fat: fat * factor, confirmed: false,
                     fibre: fibre * factor, labelCalories: calories * factor, portionGrams: grams)
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
        return .init(id: id, revision: 0, date: date, protein: protein, carbohydrate: carbohydrate, fat: fat, confirmed: false, fibre: fibre, labelCalories: energy, foodName: old?.foodName)
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
    func write(_ entry: NativeNutritionEntry) async throws
    func delete(_ entry: NativeNutritionEntry) async throws
}

@MainActor final class NativeHealthNutritionWriter: NativeNutritionWriting {
    private let health = HKHealthStore()
    private static let identifiers: [HKQuantityTypeIdentifier] = [.dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryEnergyConsumed, .dietaryFiber]
    func authorize(includeFibre: Bool) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Message(text: "Apple Salute non è disponibile su questo dispositivo.") }
        let types = Self.identifiers.prefix(includeFibre ? 5 : 4).map { HKObjectType.quantityType(forIdentifier: $0)! }
        try await health.requestAuthorization(toShare: Set(types), read: [])
        guard types.allSatisfy({ health.authorizationStatus(for: $0) == .sharingAuthorized }) else { throw Message(text: "Autorizza la scrittura di tutti i macronutrienti e delle calorie in Apple Salute.") }
    }
    func write(_ entry: NativeNutritionEntry) async throws {
        try await health.save(Self.samples(for: entry))
    }
    static func samples(for entry: NativeNutritionEntry) -> [HKQuantitySample] {
        let amounts = [entry.protein, entry.carbohydrate, entry.fat, entry.calories] + (entry.fibre.map { [$0] } ?? [])
        return zip(identifiers, amounts).enumerated().map { index, pair in
            var metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "lifeos-nutrition-\(entry.id.uuidString)-\(index)",
                HKMetadataKeySyncVersion: NSNumber(value: entry.revision)
            ]
            if let name = entry.foodName { metadata[HKMetadataKeyFoodType] = name }
            return HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: pair.0)!, quantity: HKQuantity(unit: index == 3 ? .kilocalorie() : .gram(), doubleValue: NSDecimalNumber(decimal: pair.1).doubleValue), start: entry.date, end: entry.date,
                metadata: metadata)
        }
    }
    func delete(_ entry: NativeNutritionEntry) async throws {
        // deleteObjects only removes samples created by this application.
        // Preserve the original four indices; fibre is appended at index 4.
        for (index, identifier) in Self.identifiers.prefix(entry.fibre == nil ? 4 : 5).enumerated() {
            let type = HKObjectType.quantityType(forIdentifier: identifier)!
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: ["lifeos-nutrition-\(entry.id.uuidString)-\(index)"])
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
