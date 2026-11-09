import Foundation
import HealthKit
import Combine

struct NativeHealthFoodEntry: Identifiable {
    let id: UUID
    let lifeOSID: UUID?
    let date: Date
    let name: String?
    let calories: Double
}

@MainActor final class NativeHealthStore: ObservableObject {
    @Published private(set) var days: [HealthDay] = []
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published private(set) var localDays: [HealthDay] = []
    /// HealthKit only: local pending entries remain separate and are never added here.
    @Published private(set) var nutrientsByDay: [Date: [HKQuantityTypeIdentifier: Double]] = [:]
    var nutrientTotals: [HKQuantityTypeIdentifier: Double] { nutrients(on: .now) }
    func nutrients(on date: Date) -> [HKQuantityTypeIdentifier: Double] { nutrientsByDay[calendar.startOfDay(for: date)] ?? [:] }
    func calories(on date: Date) -> Double? { days.first { calendar.isDate($0.date, inSameDayAs: date) }?.calories }
    @Published private(set) var nutrientMessage: String?
    @Published private(set) var nutrientFailures: Set<HKQuantityTypeIdentifier> = []
    private static let nutrientTypes: [HKQuantityTypeIdentifier] = [.dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFiber]
    private static var readTypes: Set<HKObjectType> {
        Set(([HKQuantityTypeIdentifier.bodyMass, .dietaryEnergyConsumed] + nutrientTypes).map { HKObjectType.quantityType(forIdentifier: $0)! })
    }
    private let health = HKHealthStore()
    private var didStart = false
    private var demo = false
    private var food: [HKQuantitySample] = []
    private var weights: [HKQuantitySample] = []
    private let calendar = Calendar.current
    var estimate: HealthEstimate? { NativeHealthMath.estimate(days) }
    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    var todayCalories: Double? {
        days.first(where: { calendar.isDateInToday($0.date) })?.calories
    }

    var todayFoodEntries: [NativeHealthFoodEntry] { foodEntries(on: .now) }

    func foodEntries(on date: Date) -> [NativeHealthFoodEntry] {
        food.reversed().compactMap { sample in
            guard calendar.isDate(sample.startDate, inSameDayAs: date) else { return nil }
            let calories = sample.quantity.doubleValue(for: .kilocalorie())
            guard calories.isFinite, calories >= 0 else { return nil }
            let sync = sample.metadata?[HKMetadataKeySyncIdentifier] as? String
            let prefix = "lifeos-nutrition-"
            let lifeOSID = sync.flatMap { key -> UUID? in
                guard key.hasPrefix(prefix), key.hasSuffix("-3") else { return nil }
                return UUID(uuidString: String(key.dropFirst(prefix.count).dropLast(2)))
            }
            return NativeHealthFoodEntry(id: sample.uuid, lifeOSID: lifeOSID, date: sample.startDate,
                name: sample.metadata?[HKMetadataKeyFoodType] as? String, calories: calories)
        }
    }

    func start(demo: Bool) async {
        guard !didStart else { return }
        didStart = true; self.demo = demo
        if demo {
            #if DEBUG
            if !ProcessInfo.processInfo.arguments.contains("--empty-home") { days = NativeHealthMath.demo() }
            if ProcessInfo.processInfo.arguments.contains("--health-week-review") {
                nutrientsByDay = Dictionary(uniqueKeysWithValues: days.enumerated().map { index, day in
                    (day.date, [.dietaryProtein: Double(115 + index % 7), .dietaryCarbohydrates: 220, .dietaryFatTotal: 65, .dietaryFiber: 25])
                })
            }
            #endif
            return
        }
        guard available else { message = "Salute non è disponibile su questo dispositivo."; return }
        loading = true
        do {
            let types = Self.readTypes
            let status = try await health.statusForAuthorizationRequest(toShare: [], read: types)
            loading = false
            if status == .shouldRequest { await connect() }
            else { await refresh() }
        } catch {
            loading = false
            message = "Salute non è accessibile. Verifica che la firma dell’app includa HealthKit. Controlla i permessi in Impostazioni > Salute."
        }
    }
    func connect() async {
        guard !demo, !loading else { return }
        guard available else { message = "Salute non è disponibile su questo dispositivo."; return }
        loading = true; message = nil
        do {
            let types = Self.readTypes
            try await health.requestAuthorization(toShare: [], read: types)
            loading = false
            await refresh()
        } catch {
            days = []; food = []; weights = []; nutrientsByDay = [:]; nutrientFailures = []
            rebuild()
            loading = false; message = "Accesso a Salute non completato. Verifica i permessi in Impostazioni > Salute."
        }
    }
    func refresh() async {
        guard !demo, !loading, available else { return }
        loading = true; message = nil
        defer { loading = false }
        do {
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .month, value: -6, to: today)!
            let end = Date()
            let newWeights = try await samples(.bodyMass, start: start, end: end)
            let newFood = try await samples(.dietaryEnergyConsumed, start: start, end: end)
            weights = newWeights; food = newFood
            rebuild()
            // Each read has an independent outcome; one failure must not hide other nutrients.
            // Every readable HealthKit source contributes; the local journal is not added.
            var totals: [Date: [HKQuantityTypeIdentifier: Double]] = [:]
            var failures: Set<HKQuantityTypeIdentifier> = []
            for type in Self.nutrientTypes {
                do {
                    let values = try await samples(type, start: start, end: end)
                    for (day, rows) in Dictionary(grouping: values, by: { calendar.startOfDay(for: $0.startDate) }) {
                        if let value = Self.nutrientTotal(rows) { totals[day, default: [:]][type] = value }
                    }
                } catch { failures.insert(type) }
            }
            nutrientsByDay = totals; nutrientFailures = failures
            nutrientMessage = failures.isEmpty ? nil : "Alcuni nutrienti non sono stati letti. Aggiorna per riprovare."

        } catch {
            // Clear old samples rather than continuing to expose stale or revoked data.
            days = []; food = []; weights = []; nutrientsByDay = [:]; nutrientFailures = []
            rebuild()
            message = "Lettura Salute non riuscita. Sblocca iPhone e riprova; verifica anche la firma HealthKit dell’app."
        }
    }
    enum WeightSaveError: LocalizedError {
        case invalid, unavailable, denied, busy
        var errorDescription: String? {
            switch self {
            case .invalid: return "Inserisci un peso valido in kg e una data non futura."
            case .unavailable: return "Apple Health non è disponibile su questo dispositivo."
            case .denied: return "Consenti a Life OS di scrivere il peso in Impostazioni > Salute, poi riprova."
            case .busy: return "Attendi il completamento della lettura di Salute e riprova."
            }
        }
    }
    func saveWeight(_ kilograms: Double, at date: Date, requestID: UUID? = nil) async throws {
        guard kilograms.isFinite, kilograms > 0, kilograms <= 500, date <= Date() else { throw WeightSaveError.invalid }
        guard !loading else { throw WeightSaveError.busy }
        if demo {
            #if DEBUG
            let day = calendar.startOfDay(for: date)
            // Match HealthKit's latest-measurement-per-day presentation in the test fixture.
            if let index = days.firstIndex(where: { $0.date == day }) { days[index].weight = kilograms }
            else { days.append(HealthDay(date: day, weight: kilograms)); days.sort { $0.date < $1.date } }
            return
            #else
            throw WeightSaveError.unavailable
            #endif
        }
        guard available else { throw WeightSaveError.unavailable }
        loading = true
        defer { loading = false }
        let type = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let readTypes: Set<HKObjectType> = [type, HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!]
        try await health.requestAuthorization(toShare: [type], read: readTypes)
        guard health.authorizationStatus(for: type) == .sharingAuthorized else { throw WeightSaveError.denied }
        let metadata: [String: Any]? = requestID.map { [HKMetadataKeySyncIdentifier: "lifeos-weight-" + $0.uuidString, HKMetadataKeySyncVersion: NSNumber(value: 1)] }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms), start: date, end: date, metadata: metadata)
        try await health.save(sample)
        weights.append(sample)
        message = nil
        rebuild()
        NotificationCenter.default.post(name: .lifeOSWeightSaved, object: nil)
    }

    func setLegacyRecords(_ records: [Record]) {
        let local = NativeHealthLegacy.days(records, calendar: calendar)
        guard local != localDays else { return }
        localDays = local
        if !demo { rebuild() }
    }
    func waitUntilIdle() async throws {
        while loading { try await Task.sleep(nanoseconds: 50_000_000) }
        try Task.checkCancellation()
    }
    func rebuild() {
        guard !demo else { return }
        var result = Dictionary(localDays.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        for sample in weights.sorted(by: { $0.startDate < $1.startDate }) {
            let value = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            guard value.isFinite, value > 0 else { continue }
            let day = calendar.startOfDay(for: sample.startDate)
            var item = result[day] ?? HealthDay(date: day)
            item.weight = value // latest sample for a day
            result[day] = item
        }
        let foodTotals = Self.calorieTotals(food, calendar: calendar)
        for (day, calories) in foodTotals {
            var item = result[day] ?? HealthDay(date: day)
            item.calories = calories // HealthKit wins over a local fallback, never sum both.
            result[day] = item
        }
        days = result.values.sorted { $0.date < $1.date }
        if days.isEmpty {
            message = "Nessun dato leggibile. Potrebbero mancare le registrazioni o i permessi: iOS non distingue questi casi."
        }
    }
    /// Every returned HealthKit energy sample contributes, irrespective of source app.
    static func calorieTotals(_ samples: [HKQuantitySample], calendar: Calendar = .current) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for sample in samples {
            let value = sample.quantity.doubleValue(for: .kilocalorie())
            guard value.isFinite, value >= 0 else { continue }
            totals[calendar.startOfDay(for: sample.startDate), default: 0] += value
        }
        return totals
    }
    /// nil means no readable sample; zero is a valid recorded quantity.
    static func nutrientTotal(_ samples: [HKQuantitySample]) -> Double? {
        let values = samples.map { $0.quantity.doubleValue(for: .gram()) }.filter { $0.isFinite && $0 >= 0 }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    private func samples(_ identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKQuantitySample] ?? []) }
            }
            health.execute(query)
        }
    }
}
