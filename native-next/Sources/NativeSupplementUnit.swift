import Foundation

/// Legacy entries retain their original per-dose basis until explicitly edited.
enum NativeSupplementUnit: String, Codable, CaseIterable, Identifiable {
    case capsule, tablet, gram, millilitre, legacyServing
    var id: String { rawValue }
    static var editable: [Self] { [.capsule, .tablet, .gram, .millilitre] }
    var isMassOrVolume: Bool { self == .gram || self == .millilitre }
    var quantityTitle: String {
        switch self {
        case .capsule: "Capsule"
        case .tablet: "Compresse"
        case .gram, .millilitre: "Quantità"
        case .legacyServing: "Dosi della voce precedente"
        }
    }
    var title: String {
        switch self {
        case .capsule: "Capsule / softgel"
        case .tablet: "Compresse / pillole"
        case .gram: "Grammi"
        case .millilitre: "Millilitri"
        case .legacyServing: "Dose precedente"
        }
    }
    var basisTitle: String {
        switch self {
        case .capsule: "capsula"
        case .tablet: "compressa"
        case .gram: "100 g"
        case .millilitre: "100 ml"
        case .legacyServing: "dose precedente"
        }
    }
}
