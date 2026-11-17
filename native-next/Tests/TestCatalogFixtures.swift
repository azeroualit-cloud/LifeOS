import Foundation
@testable import LifeOSProbe

/// Supplement presets were removed from the app (SUPPLEMENTS-PERSONAL-ONLY-92).
/// They remain here only as data for the unit, label and personal-copy tests.
enum TestCatalogFixtures {
    private final class Anchor {}
    private static func load(_ name: String) -> [NativeGenericFood] {
        guard let url = Bundle(for: Anchor.self).url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([NativeGenericFood].self, from: data) else { return [] }
        return foods
    }
    static let supplements = load("supplements")
    static let brandedSupplements = load("branded-supplements")
}
