import XCTest
@testable import LifeOSProbe
final class NativeNutritionEntryTests: XCTestCase {
    func testBundledFoodUsesPortionAndPreservesName() throws {
        let food = try XCTUnwrap(NativeGenericFood.matches("riso bianco cotto").first)
        let entry = try XCTUnwrap(food.portion(id: UUID(), date: Date(), grams: 150))
        XCTAssertEqual(entry.foodName, "Riso bianco")
        XCTAssertEqual(entry.portionGrams, 150)
        XCTAssertEqual(entry.calories, food.calories * 150 / 100)
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry)), entry)
    }
    func testGenericSearchPrefersCommonItalianNamesAndKeepsPreparationDistinct() {
        let biscuits = NativeGenericFood.matches("  BISCOTTI  ").first
        XCTAssertEqual(biscuits?.name, "Biscotti")
        XCTAssertEqual(biscuits?.detail, "Generic")
        XCTAssertEqual(NativeGenericFood.matches("biscotto").first?.id, biscuits?.id)

        let chicken = NativeGenericFood.matches("Petto di pollo").first
        XCTAssertEqual(chicken?.id, "ciqual-36017")
        XCTAssertEqual(NativeGenericFood.matches("petto pollo").first?.id, chicken?.id)
        XCTAssertEqual(NativeGenericFood.matches("petto di pollo cotto").first?.id, "ciqual-36018")
        XCTAssertEqual(NativeGenericFood.matches("caffe").first?.name, "Caffè espresso")
        XCTAssertTrue(NativeGenericFood.matches("alimento inesistente").isEmpty)
    }
    func testBoneInPortionKeepsScaleWeightAndUsesOnlyEdibleGrams() throws {
        let food = try XCTUnwrap(NativeGenericFood.matches("Coscia di pollo al forno con pelle").first)
        let entry = try XCTUnwrap(food.portion(id: UUID(), date: Date(), grams: 200, weighedWithBone: true))
        XCTAssertEqual(entry.boneInWeightGrams, 200)
        XCTAssertEqual(entry.portionGrams, 142)
        XCTAssertEqual(entry.calories, Decimal(string: "291.1"))
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry)), entry)
        XCTAssertNil(food.portion(id: UUID(), date: Date(), grams: 0, weighedWithBone: true))
    }

    func testCatalogExcludesPorkAndSeparatesMoroccanDishes() {
        for query in ["maiale", "prosciutto", "salame"] {
            XCTAssertTrue(NativeGenericFood.matches(query).isEmpty)
        }
        XCTAssertEqual(NativeGenericFood.matches("couscous").first?.id, "ciqual-9683")
        XCTAssertEqual(NativeGenericFood.matches("couscous senza carne").first?.id, "ciqual-25150")
        XCTAssertEqual(NativeGenericFood.matches("couscous con carne").first?.id, "ciqual-25138")
        XCTAssertEqual(NativeGenericFood.matches("tagine pollo").first?.id, "ciqual-25204")
    }

    func testNutrientsUseEdiblePortionAndReportMissingDays() throws {
        let food = try XCTUnwrap(NativeGenericFood.matches("Coscia di pollo al forno con pelle").first)
        let per100 = try XCTUnwrap(food.nutrientValues?["zinc"])
        var entry = try XCTUnwrap(food.portion(id: UUID(), date: Date(), grams: 200, weighedWithBone: true))
        let zinc = try XCTUnwrap(entry.nutrientValues?["zinc"])
        XCTAssertEqual(zinc.amount, per100.amount * 142 / 100)
        XCTAssertEqual(zinc.estimateSource, per100.estimateSource)
        let old = try XCTUnwrap(NativeNutritionEntry.direct(id: UUID(), date: Date(), protein: 10, carbohydrate: 0, fat: 0, fibre: 0))
        XCTAssertNil(old.nutrientValues)
        let week = NativeNutrientPeriod(.zinc, days: [[entry, old], [old], []])
        XCTAssertEqual(week.amount, zinc.amount)
        XCTAssertEqual(week.daysWithValues, 1)
        XCTAssertEqual(week.daysWithEntries, 2)
        XCTAssertTrue(week.partial)
        XCTAssertNil(NativeNutrientPeriod(.zinc, days: [[old], []]).amount)
        XCTAssertEqual(NativeTrackedNutrient.vitaminC.dailyReference, 105)
        XCTAssertEqual(NativeTrackedNutrient.zinc.dailyReference, 12)
        XCTAssertEqual(week.progress(toward: zinc.amount / 2), 1)
        entry.confirmed = true
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry)), entry)
    }

    func testItalianDecimalsAndFourFourNineCalculation() {
        let entry = NativeNutritionEntry(id: UUID(), revision: 1, date: Date(), protein: 10, carbohydrate: 20, fat: 5, confirmed: false)
        XCTAssertEqual(entry.calories, 165)
        XCTAssertEqual(NativeNutritionEntry.grams("1,25"), Decimal(string: "1.25"))
        XCTAssertEqual(NativeNutritionEntry.grams("1.25"), Decimal(string: "1.25"))
        XCTAssertEqual(NativeNutritionEntry.grams(""), 0)
        for invalid in ["-1", "NaN", "inf", "1,2,3", "4g"] { XCTAssertNil(NativeNutritionEntry.grams(invalid)) }
    }
    func testDirectTotalsIncludeFibreAndRoundTripWithoutPortionScaling() throws {
        let value = try XCTUnwrap(NativeNutritionEntry.direct(id: UUID(), date: Date(), protein: 25, carbohydrate: 40, fat: 10, fibre: 6))
        XCTAssertEqual(value.calories, 362)
        XCTAssertEqual(value.protein, 25); XCTAssertEqual(value.fibre, 6); XCTAssertNil(value.portionGrams)
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(value)), value)
        XCTAssertNil(NativeNutritionEntry.direct(id: UUID(), date: Date(), protein: 0, carbohydrate: 0, fat: 0, fibre: 0))
        XCTAssertNil(NativeNutritionEntry.direct(id: UUID(), date: Date(), protein: -1, carbohydrate: 1, fat: 0, fibre: 0))
    }
    func testDateOnlyEditPreservesLegacyLabelEnergyEvenWithZeroMacros() throws {
        let old = try XCTUnwrap(NativeNutritionEntry.portion(id: UUID(), date: Date(), protein: 0, carbohydrate: 0, fat: 0, fibre: 0, calories: 450, grams: 20))
        let date = old.date.addingTimeInterval(86400)
        let changedDate = try XCTUnwrap(NativeNutritionEntry.direct(id: old.id, date: date, protein: 0, carbohydrate: 0, fat: 0, fibre: 0, preserving: old))
        XCTAssertEqual(changedDate.calories, 90); XCTAssertEqual(changedDate.portionGrams, 20); XCTAssertEqual(changedDate.date, date)
        let changedAmounts = try XCTUnwrap(NativeNutritionEntry.direct(id: old.id, date: date, protein: 10, carbohydrate: 0, fat: 0, fibre: 0, preserving: old))
        XCTAssertEqual(changedAmounts.calories, 40); XCTAssertNil(changedAmounts.portionGrams)
    }
    func testTwentyGramPortionUsesLabelEnergyAndScalesFibre() throws {
        let entry = try XCTUnwrap(NativeNutritionEntry.portion(id: UUID(), date: Date(),
            protein: 6, carbohydrate: 60, fat: 20, fibre: 8, calories: 450, grams: 20))
        XCTAssertEqual(entry.protein, Decimal(string: "1.2"))
        XCTAssertEqual(entry.carbohydrate, 12)
        XCTAssertEqual(entry.fat, 4)
        XCTAssertEqual(entry.fibre, Decimal(string: "1.6"))
        XCTAssertEqual(entry.calories, 90)
        XCTAssertNotEqual(entry.calories, entry.protein * 4 + entry.carbohydrate * 4 + entry.fat * 9)
        XCTAssertEqual(entry.portionGrams, 20)
        XCTAssertEqual(try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONEncoder().encode(entry)), entry)
    }
    func testMissingLabelEnergyOrZeroPortionCannotCreateEntry() {
        let invalid: [(Decimal, Decimal)] = [(0, 20), (450, 0), (450, -1)]
        for (calories, grams) in invalid {
            XCTAssertNil(NativeNutritionEntry.portion(id: UUID(), date: Date(),
                protein: 6, carbohydrate: 60, fat: 20, fibre: 8, calories: calories, grams: grams))
        }
    }
}
