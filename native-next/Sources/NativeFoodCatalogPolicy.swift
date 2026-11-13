import Foundation

/// Public catalog visibility only. Saved portions and personal recipes remain intact.
enum NativeFoodCatalogPolicy {
    private static let nonAlcoholicExceptions: Set<String> = [
        "coop-0478e3208e43a5369189", "coop-b3b5983630e3f77c2fa5",
        "coop-ean-8001120739902", "coop-ean-8001120740175",
        "coop-5f1d036420368a6f8d40",
        "coop-ean-8001120448323", "coop-ean-8001120448330", "coop-ean-8001120448347",
        "coop-ean-8001120779885", "coop-ean-8001120779892"
    ]
    private static let explicitLiqueurFoods: Set<String> = [
        "coop-ean-8001120593566", "coop-ean-8001120687258",
        "coop-ean-8001120713162", "coop-ean-8001120774934", "coop-ean-8001120593184"
    ]

    static func includes(_ food: NativeGenericFood) -> Bool {
        if food.cocktail != nil { return true }
        if explicitLiqueurFoods.contains(food.id) { return false }
        guard let source = food.sourceURL, let url = URL(string: source),
              url.host == "www.coop.it" || url.host == "coop.it" else { return true }
        let alcoholicCategory = ["/birra/", "/vini-tipici", "/vini-da-tavolo"].contains { url.path.contains($0) }
        return !alcoholicCategory || nonAlcoholicExceptions.contains(food.id)
    }
}
