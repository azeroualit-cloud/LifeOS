import XCTest
@testable import LifeOSProbe

/// FOOD-LOG-EDIT-2026-11-25: editing a logged food keeps the entry and scales every amount.
@MainActor final class NativeFoodLogEditTests: XCTestCase {
    private func chicken() -> NativeNutritionEntry {
        var entry = NativeNutritionEntry.portion(id: UUID(), date: Date(timeIntervalSince1970: 1_000_000), protein: 23, carbohydrate: 0, fat: Decimal(string: "1.6")!, fibre: 0, calories: 110, grams: 180)!
        entry.revision = 2; entry.confirmed = true; entry.foodName = "Petto di pollo"; entry.foodID = "base-chicken"
        entry.nutrientValues = ["zinc": .init(amount: 2, estimateSource: nil)]
        return entry
    }

    func testGramsScaleMacrosEnergyAndMicronutrientsKeepingTheEntry() {
        let entry = chicken()
        XCTAssertEqual(entry.loggedQuantity?.value, 180); XCTAssertEqual(entry.loggedQuantity?.unit, "g")
        let later = entry.date.addingTimeInterval(3600)
        let edited = entry.edited(quantity: 150, date: later)!
        XCTAssertEqual(edited.id, entry.id); XCTAssertEqual(edited.foodID, entry.foodID); XCTAssertEqual(edited.revision, entry.revision)
        XCTAssertEqual(edited.portionGrams, 150); XCTAssertEqual(edited.date, later)
        XCTAssertEqual(NSDecimalNumber(decimal: edited.protein).doubleValue, 34.5, accuracy: 0.0001)
        XCTAssertEqual(NSDecimalNumber(decimal: edited.calories).doubleValue, 165, accuracy: 0.0001)
        XCTAssertEqual(NSDecimalNumber(decimal: edited.nutrientValues!["zinc"]!.amount).doubleValue, 2.0 * 150 / 180, accuracy: 0.0001)
    }

    func testTimeOnlyAndInvalidQuantities() {
        let entry = chicken()
        XCTAssertEqual(entry.edited(quantity: 180, date: entry.date), entry, "same quantity and time: nothing changes")
        XCTAssertEqual(entry.edited(quantity: nil, date: entry.date.addingTimeInterval(60))?.protein, entry.protein)
        XCTAssertNil(entry.edited(quantity: 0, date: entry.date))
        XCTAssertNil(entry.edited(quantity: 10000, date: entry.date))
    }

    func testBoneSupplementAndCocktailUseTheirOwnQuantity() {
        var bone = chicken(); bone.boneInWeightGrams = 250
        let boneEdit = bone.edited(quantity: 200, date: bone.date)!
        XCTAssertEqual(bone.loggedQuantity?.unit, "g con osso"); XCTAssertEqual(boneEdit.boneInWeightGrams, 200); XCTAssertEqual(boneEdit.portionGrams, 144)

        var drink = NativeNutritionEntry(id: UUID(), revision: 1, date: .now, protein: 0, carbohydrate: 14, fat: 0, confirmed: true, labelCalories: 170)
        drink.cocktailServings = 1; drink.alcoholGrams = 14
        let two = drink.edited(quantity: 2, date: drink.date)!
        XCTAssertEqual(two.cocktailServings, 2); XCTAssertEqual(two.alcoholGrams, 28); XCTAssertEqual(two.calories, 340)

        var capsule = NativeNutritionEntry(id: UUID(), revision: 1, date: .now, protein: 0, carbohydrate: 0, fat: 1, confirmed: true, labelCalories: 9, foodID: "personal-omega")
        capsule.supplementQuantity = 2; capsule.supplementUnit = NativeSupplementUnit.allCases.first { !$0.isMassOrVolume }?.rawValue
        XCTAssertEqual(capsule.loggedQuantity?.steps, [1])
        XCTAssertEqual(capsule.edited(quantity: 3, date: capsule.date)?.fat, Decimal(string: "1.5"))
    }
}
