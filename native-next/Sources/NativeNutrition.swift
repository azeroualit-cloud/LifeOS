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
    var calories: Decimal { protein * 4 + carbohydrate * 4 + fat * 9 }
    static func grams(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        guard value.range(of: "^[0-9]+([.,][0-9]+)?$", options: .regularExpression) != nil,
              let number = Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")), number >= 0, !number.isNaN else { return nil }
        return number
    }
}

@MainActor protocol NativeNutritionWriting {
    func authorize() async throws
    func write(_ entry: NativeNutritionEntry) async throws
    func delete(_ entry: NativeNutritionEntry) async throws
}

@MainActor final class NativeHealthNutritionWriter: NativeNutritionWriting {
    private let health = HKHealthStore()
    private let identifiers: [HKQuantityTypeIdentifier] = [.dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryEnergyConsumed]
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Message(text: "Apple Salute non è disponibile su questo dispositivo.") }
        let types = identifiers.map { HKObjectType.quantityType(forIdentifier: $0)! }
        try await health.requestAuthorization(toShare: Set(types), read: [])
        guard types.allSatisfy({ health.authorizationStatus(for: $0) == .sharingAuthorized }) else { throw Message(text: "Autorizza la scrittura di tutti i macronutrienti e delle calorie in Apple Salute.") }
    }
    func write(_ entry: NativeNutritionEntry) async throws {
        let amounts = [entry.protein, entry.carbohydrate, entry.fat, entry.calories]
        let samples = zip(identifiers, amounts).enumerated().map { index, pair in
            HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: pair.0)!, quantity: HKQuantity(unit: index == 3 ? .kilocalorie() : .gram(), doubleValue: NSDecimalNumber(decimal: pair.1).doubleValue), start: entry.date, end: entry.date,
                metadata: [HKMetadataKeySyncIdentifier: "lifeos-nutrition-\(entry.id.uuidString)-\(index)", HKMetadataKeySyncVersion: NSNumber(value: entry.revision)])
        }
        try await health.save(samples)
    }
    func delete(_ entry: NativeNutritionEntry) async throws {
        // deleteObjects only removes samples created by this application.
        // Exact sync identifiers include all revisions of these four samples.
        for (index, identifier) in identifiers.enumerated() {
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
    func save(_ value: NativeNutritionEntry, retry: Bool = false) async -> Bool {
        guard loaded, !busy, !entries.contains(where: { $0.deletionPending == true }) else { return false }
        guard value.protein >= 0, value.carbohydrate >= 0, value.fat >= 0, value.calories > 0,
              !value.calories.isNaN, NSDecimalNumber(decimal: value.calories).doubleValue.isFinite else { return false }
        busy = true; defer { busy = false }
        error = nil
        do {
            try await writer.authorize()
            let old = entries.first { $0.id == value.id }
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
            try await writer.authorize()
            try await writer.delete(entry)
            try persist(entries.filter { $0.id != id })
            return true
        } catch { self.error = "Eliminazione da completare: " + error.localizedDescription; return false }
    }

}
