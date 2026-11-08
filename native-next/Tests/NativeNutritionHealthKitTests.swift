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
    func testCocktailAndMicronutrientSamplesUseCompatibleUnits() throws {
        let cocktail = try XCTUnwrap(NativeGenericFood.matches("Gin Tonic").first)
        var entry = try XCTUnwrap(cocktail.portion(id: UUID(), date: Date(), grams: 2))
        XCTAssertEqual(entry.cocktailServings, 2)
        XCTAssertNil(entry.portionGrams)
        XCTAssertEqual(entry.alcoholGrams, Decimal(string: "31.56"))
        entry.nutrientValues = [
            "vitaminK1": .init(amount: 4, estimateSource: nil),
            "vitaminK2": .init(amount: 6, estimateSource: nil),
            "folateMass": .init(amount: 8, estimateSource: nil)
        ]
        entry.sharedNutrientKeys = ["standardDrinks", "vitaminK", "folateMass"]
        let samples = NativeHealthNutritionWriter.samples(for: entry)
        let drink = try XCTUnwrap(samples.first { $0.quantityType.identifier == HKQuantityTypeIdentifier.numberOfAlcoholicBeverages.rawValue })
        let vitaminK = try XCTUnwrap(samples.first { $0.quantityType.identifier == HKQuantityTypeIdentifier.dietaryVitaminK.rawValue })
        let folate = try XCTUnwrap(samples.first { $0.quantityType.identifier == HKQuantityTypeIdentifier.dietaryFolate.rawValue })
        XCTAssertEqual(drink.quantity.doubleValue(for: .count()), 2.63, accuracy: 0.001)
        XCTAssertEqual(vitaminK.quantity.doubleValue(for: .gramUnit(with: .micro)), 10)
        XCTAssertEqual(folate.quantity.doubleValue(for: .gramUnit(with: .micro)), 8)
    }

    func testAuthorizedCatalogNutrientsUseStableIDsAndCorrectMassUnits() throws {
        var entry = NativeNutritionEntry(id: UUID(), revision: 2, date: Date(), protein: 1, carbohydrate: 2, fat: 3, confirmed: false)
        entry.nutrientValues = [
            "vitaminC": .init(amount: 15, estimateSource: nil),
            "vitaminB12": .init(amount: 2, estimateSource: "ciqual-test"),
            "zinc": .init(amount: 4, estimateSource: nil)
        ]
        entry.sharedNutrientKeys = ["vitaminC", "vitaminB12"]
        let samples = NativeHealthNutritionWriter.samples(for: entry)
        XCTAssertEqual(samples.count, 6)
        let vitaminC = try XCTUnwrap(samples.first { $0.quantityType.identifier == HKQuantityTypeIdentifier.dietaryVitaminC.rawValue })
        let vitaminB12 = try XCTUnwrap(samples.first { $0.quantityType.identifier == HKQuantityTypeIdentifier.dietaryVitaminB12.rawValue })
        XCTAssertEqual(vitaminC.quantity.doubleValue(for: .gramUnit(with: .milli)), 15, accuracy: 0.0001)
        XCTAssertEqual(vitaminB12.quantity.doubleValue(for: .gramUnit(with: .micro)), 2, accuracy: 0.0001)
        XCTAssertEqual(vitaminB12.metadata?[HKMetadataKeySyncIdentifier] as? String,
                       "lifeos-nutrition-\(entry.id.uuidString)-nutrient-vitaminB12")
        XCTAssertEqual(vitaminB12.metadata?["LifeOSNutrientEstimateSource"] as? String, "ciqual-test")
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
    func testNutrientReadsDistinguishNoSampleAndRecordedZero() {
        let type = HKObjectType.quantityType(forIdentifier: .dietaryProtein)!
        let date = Date()
        func sample(_ value: Double, _ manual: Bool) -> HKQuantitySample {
            HKQuantitySample(type: type, quantity: HKQuantity(unit: .gram(), doubleValue: value),
                start: date, end: date, metadata: [HKMetadataKeyWasUserEntered: manual])
        }
        XCTAssertNil(NativeHealthStore.nutrientTotal([]))
        XCTAssertEqual(NativeHealthStore.nutrientTotal([sample(0, true)]), 0)
        XCTAssertEqual(NativeHealthStore.nutrientTotal([sample(12.5, true), sample(4, false)]), 16.5)
    }
    func testEnergyZeroIsNotMissing() {
        let type = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        let day = Calendar.current.startOfDay(for: Date())
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 0), start: day, end: day)
        XCTAssertEqual(NativeHealthStore.calorieTotals([sample])[day], 0)
        XCTAssertNil(NativeHealthStore.calorieTotals([])[day])
    }

}
