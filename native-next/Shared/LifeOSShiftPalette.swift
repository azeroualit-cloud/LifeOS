import SwiftUI

enum LifeOSShiftPalette {
    static func color(_ kind: String) -> Color {
        let light: UInt32, dark: UInt32
        switch kind {
        case "morning": light = 0x8FACD9; dark = 0x639BCF
        case "afternoon": light = 0x9BCB83; dark = 0x6CAF7A
        case "night": light = 0x727780; dark = 0xADB2BC
        case "rest": light = 0xE79862; dark = 0xDF986D
        case "holiday": light = 0xA88B18; dark = 0xDEC34E
        default: return .secondary
        }
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static func letter(_ kind: String?) -> String {
        switch kind {
        case "morning": return "M"
        case "afternoon": return "P"
        case "night": return "N"
        case "rest": return "R"
        case "holiday": return "F"
        default: return "—"
        }
    }
}
