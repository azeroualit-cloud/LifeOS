import XCTest
import HealthKit
@testable import LifeOSProbe

@MainActor final class NativeFoodUnitsTests: XCTestCase {
    func testBrandedCapsulesUseElementalAmountPerCapsuleAndKeepQuantityAfterReload() throws {
        let magnesium = try XCTUnwrap(NativeGenericFood.brandedSupplements.first { $0.id == "brand-vit4ever-magnesium-citrate" })
        let entry = try XCTUnwrap(magnesium.portion(id: UUID(), date: .now, grams: 2))
        XCTAssertEqual(entry.nutrientValues?["magnesium"]?.amount, 240)
        XCTAssertEqual(entry.supplementQuantity, 2)
        XCTAssertNil(entry.portionGrams)
        let restored = try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(restored.quantityDescription, "2 capsule")
        XCTAssertEqual(restored.nutrientValues, entry.nutrientValues)
    }

    func testPowderUsesActualGramsAndLegacyDoseKeepsItsOriginalMeaning() throws {
        let whey = try XCTUnwrap(NativeGenericFood.supplements.first { $0.id == "supplement-whey" })
        let portion = try XCTUnwrap(whey.portion(id: UUID(), date: .now, grams: 30))
        XCTAssertEqual(portion.protein, 24)
        XCTAssertEqual(NSDecimalNumber(decimal: portion.calories).doubleValue, 122, accuracy: 0.0001)
        XCTAssertEqual(portion.quantityDescription, "30 g")
        let legacy = NativeGenericFood(id: "personal-old", name: "Precedente", detail: "Personale", family: .supplement,
            boneInEdiblePercent: nil, nutrientValues: ["vitaminC": .init(amount: 50000, estimateSource: nil)],
            aliases: nil, protein: 0, carbohydrate: 0, fat: 0, fibre: nil, calories: 0)
        let decoded = try JSONDecoder().decode(NativeGenericFood.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.quantityUnit, .legacyServing)
        XCTAssertEqual(decoded.portion(id: UUID(), date: .now, grams: 2)?.nutrientValues?["vitaminC"]?.amount, 1000)
    }

    func testMillilitresAreNeverPersistedAsGramsAndBrandIsSearchable() throws {
        let juice = NativeGenericFood(id: "test-juice", name: "Succo", detail: nil, family: .drink,
            boneInEdiblePercent: nil, nutrientValues: nil, aliases: nil, protein: 0, carbohydrate: 10,
            fat: 0, fibre: nil, calories: 40, measurementBasis: "ml", brand: "Gli Spesotti")
        let entry = try XCTUnwrap(juice.portion(id: UUID(), date: .now, grams: 250))
        XCTAssertEqual(entry.calories, 100)
        XCTAssertEqual(entry.portionMillilitres, 250)
        XCTAssertNil(entry.portionGrams)
        XCTAssertEqual(entry.quantityDescription, "250 ml")
        XCTAssertTrue(entry.nutritionSummary.contains("F —"), "Missing fibre must remain unavailable in history")
        XCTAssertEqual(NativeGenericFood.matches("succo spesotti", in: [juice]).map(\.id), [juice.id])
    }

    func testUndeclaredMacrosDoNotCreateFalseZeroHealthSamples() throws {
        let vitamin = try XCTUnwrap(NativeGenericFood.brandedSupplements.first { $0.id == "brand-natural-elements-vitamin-c" })
        var entry = try XCTUnwrap(vitamin.portion(id: UUID(), date: .now, grams: 1))
        entry.sharedNutrientKeys = ["vitaminC"]
        let samples = NativeHealthNutritionWriter.samples(for: entry)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.quantityType.identifier, HKQuantityTypeIdentifier.dietaryVitaminC.rawValue)
        XCTAssertEqual(samples.first?.quantity.doubleValue(for: .gramUnit(with: .milli)), 500)
    }

    func testUnlabelledFoodPersistsLocallyWithoutRequestingMacroPermission() async throws {
        let writer = UndeclaredNutritionWriter()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NativeNutritionStore(directory: directory, writer: writer)
        let food = NativeGenericFood(id: "test-missing", name: "Alimento senza tabella", detail: nil, family: .fruit,
            boneInEdiblePercent: nil, nutrientValues: nil, aliases: nil, protein: 0, carbohydrate: 0,
            fat: 0, fibre: nil, calories: 0, nutritionNotDeclared: true)
        let entry = try XCTUnwrap(food.portion(id: UUID(), date: .now, grams: 100))
        let saved = await store.save(entry)
        XCTAssertTrue(saved)
        XCTAssertEqual(writer.macroRequests, 0)
        let restored = NativeNutritionStore(directory: directory, writer: writer)
        XCTAssertEqual(restored.entries.first?.id, entry.id)
        XCTAssertTrue(NativeHealthNutritionWriter.samples(for: try XCTUnwrap(restored.entries.first)).isEmpty)
        let deleted = await restored.delete(entry.id)
        XCTAssertTrue(deleted)
        XCTAssertTrue(restored.entries.isEmpty)
        XCTAssertEqual(writer.macroRequests, 0, "Removing an entry with no macro samples must not demand macro permission")
    }

    func testManualTotalsClearPortionWhileDateOnlyEditKeepsUnits() throws {
        let capsule = try XCTUnwrap(NativeGenericFood.brandedSupplements.first { $0.id == "brand-weightworld-omega3" })
        let old = try XCTUnwrap(capsule.portion(id: UUID(), date: .now, grams: 2))
        let updated = try XCTUnwrap(NativeNutritionEntry.direct(id: old.id, date: old.date, protein: 0,
            carbohydrate: 0, fat: 3, fibre: 0, preserving: old))
        XCTAssertNil(updated.supplementQuantity)
        XCTAssertNil(updated.supplementUnit)
        let dateOnly = try XCTUnwrap(NativeNutritionEntry.direct(id: old.id, date: old.date.addingTimeInterval(60),
            protein: old.protein, carbohydrate: old.carbohydrate, fat: old.fat, fibre: old.fibre ?? 0, preserving: old))
        XCTAssertEqual(dateOnly.supplementQuantity, 2)
        XCTAssertEqual(dateOnly.supplementUnit, NativeSupplementUnit.capsule.rawValue)
        var liquid = old
        liquid.supplementQuantity = nil; liquid.supplementUnit = nil; liquid.portionMillilitres = 250
        let changed = try XCTUnwrap(NativeNutritionEntry.direct(id: liquid.id, date: liquid.date, protein: 1,
            carbohydrate: 25, fat: 0, fibre: 0, preserving: liquid))
        XCTAssertNil(changed.portionMillilitres)
    }

    func testOfficialZeroEnergyPolyolLabelDoesNotChangeGenericValidation() throws {
        let erythritol = try XCTUnwrap(NativeGenericFood.brandedFoods.first { $0.id == "coop-ean-8001120736482" })
        let item = try XCTUnwrap(erythritol.portion(id: UUID(), date: .now, grams: 10))
        XCTAssertEqual(item.calories, 0)
        XCTAssertEqual(item.carbohydrate, 10)
        XCTAssertNil(NativeNutritionEntry.portion(id: UUID(), date: .now, protein: 0,
            carbohydrate: 100, fat: 0, fibre: nil, calories: 0, grams: 10))
    }

    func testPersonalCopyPreservesCompositionWithoutRewritingLoggedEntries() throws {
        let source = try XCTUnwrap(NativeGenericFood.brandedSupplements.first { $0.id == "brand-weightworld-omega3" })
        let logged = try XCTUnwrap(source.portion(id: UUID(), date: .now, grams: 1))
        let copy = source.personalCopy()
        XCTAssertNotEqual(copy.id, source.id)
        XCTAssertTrue(copy.id.hasPrefix("personal-"))
        XCTAssertEqual(copy.brand, "WeightWorld")
        XCTAssertEqual(copy.portion(id: UUID(), date: .now, grams: 2)?.nutrientValues?["epa"]?.amount, 660)
        XCTAssertEqual(logged.nutrientValues?["epa"]?.amount, 330)
        XCTAssertEqual(logged.foodID, source.id)
    }
}

@MainActor private final class UndeclaredNutritionWriter: NativeNutritionWriting {
    var macroRequests = 0
    func authorize(includeFibre: Bool) async throws { macroRequests += 1 }
    func write(_ entry: NativeNutritionEntry) async throws {}
    func delete(_ entry: NativeNutritionEntry) async throws {}
}
