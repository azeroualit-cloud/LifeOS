import XCTest
import HealthKit
@testable import LifeOSProbe

@MainActor final class NativeNutritionHealthKitTests: XCTestCase {
    func testPortionWritesLabelEnergyAndFibreWithoutChangingLegacySyncIndices() throws {
        let id = UUID(), date = Date()
        let entry = try XCTUnwrap(NativeNutritionEntry.portion(id: id, date: date,
            protein: 6, carbohydrate: 60, fat: 20, fibre: 8, calories: 450, grams: 20))
        let samples = NativeHealthNutritionWriter.samples(for: entry)
        XCTAssertEqual(samples.map(\.quantityType.identifier), [HKQuantityTypeIdentifier.dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal, .dietaryEnergyConsumed, .dietaryFiber].map(\.rawValue))
        XCTAssertEqual(samples[3].quantity.doubleValue(for: .kilocalorie()), 90, accuracy: 0.0001)
        XCTAssertEqual(samples[4].quantity.doubleValue(for: .gram()), 1.6, accuracy: 0.0001)
        for (index, sample) in samples.enumerated() {
            XCTAssertEqual(sample.metadata?[HKMetadataKeySyncIdentifier] as? String, "lifeos-nutrition-\(id.uuidString)-\(index)")
            XCTAssertEqual(sample.startDate, date)
        }
        let legacy = NativeNutritionEntry(id: id, revision: 1, date: date, protein: 10, carbohydrate: 20, fat: 5, confirmed: true)
        XCTAssertEqual(NativeHealthNutritionWriter.samples(for: legacy).count, 4)
        XCTAssertEqual(NativeHealthNutritionWriter.samples(for: legacy)[3].quantity.doubleValue(for: .kilocalorie()), 165)
    }
    func testEveryEnergyEntryContributesToItsLocalDay() {
        let type = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        func sample(_ value: Double, _ date: Date, manual: Bool) -> HKQuantitySample {
            HKQuantitySample(type: type, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: value),
                start: date, end: date, metadata: [HKMetadataKeyWasUserEntered: manual])
        }
        let totals = NativeHealthStore.calorieTotals([
            sample(400, today, manual: false), sample(250, today.addingTimeInterval(3600), manual: true),
            sample(100, tomorrow, manual: false)])
        XCTAssertEqual(totals[today], 650)
        XCTAssertEqual(totals[tomorrow], 100)
    }
}
