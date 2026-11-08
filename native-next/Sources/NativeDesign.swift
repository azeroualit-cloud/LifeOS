import SwiftUI

enum NativeDesign {
    // Platinum is an interaction colour. Shift colours retain their own meaning.
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.87, alpha: 1) : UIColor(white: 0.23, alpha: 1)
    })
    static let onAccent = Color(uiColor: .systemBackground)
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.045, alpha: 1) : .systemGroupedBackground })
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.075, alpha: 1) : .secondarySystemGroupedBackground })
    static let secondary = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.68 : 0.37, alpha: 1)
    })
    // Compensate the text base so the requested 80% opacity remains readable.
    static let pastCalendarSecondary = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.72 : 0.27, alpha: 1)
    })
    static let actionSurface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.17, alpha: 1) : .tertiarySystemFill })
    static let financeTitle = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.66, green: 0.78, blue: 1, alpha: 1) : UIColor(red: 0.09, green: 0.30, blue: 0.67, alpha: 1)
    })
    static let nutritionTitle = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.88, blue: 0.71, alpha: 1) : UIColor(red: 0.08, green: 0.40, blue: 0.28, alpha: 1)
    })
    static let nutritionCanvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.09, alpha: 1) : .systemGroupedBackground
    })
    static let nutritionInput = Color(uiColor: UIColor { traits in
        guard traits.userInterfaceStyle == .dark else { return .secondarySystemGroupedBackground }
        return UIColor(white: traits.accessibilityContrast == .high ? 0.23 : 0.16, alpha: 1)
    })
    static let calendarCanvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.018, alpha: 1) : .systemGroupedBackground
    })
    static let calendarTitle = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.73, blue: 0.53, alpha: 1) : .systemBrown
    })
    static let calendarAccent = Color(uiColor: .systemBlue)
    static func calendarNumber(size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .default) }
    static let healthCanvas = Color(uiColor: .systemGroupedBackground)
    static let healthSurface = Color(uiColor: .secondarySystemGroupedBackground)
    // Measured from the populated Apple Health dark reference; adapt in light mode.
    static let healthWeight = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 219 / 255, green: 52 / 255, blue: 242 / 255, alpha: 1) : .systemPurple
    })
    static let healthAccent = Color(uiColor: .systemOrange)
    static let healthGray = Color(uiColor: .systemGray)
    static let healthHistoricalBar = healthGray.opacity(0.28)
    static let healthTrend = Color(uiColor: .label)
    static let calendarPreviewFraction: CGFloat = 0.46
    static let inset = Color.primary.opacity(0.045)
    // Financial direction only: red = outflow/decline, green = available/inflow/growth.
    static let financialRed = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.83, green: 0.57, blue: 0.56, alpha: 1) : UIColor(red: 0.63, green: 0.29, blue: 0.28, alpha: 1)
    })
    static let financialGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.73, blue: 0.63, alpha: 1) : UIColor(red: 0.22, green: 0.45, blue: 0.33, alpha: 1)
    })
    enum Space {
        static let none: CGFloat = 0
        static let hairline: CGFloat = 1
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let section: CGFloat = 24
        static let bottom: CGFloat = 32
    }
    enum Layout {
        static let bloomPagerHeight: CGFloat = 400
        static let bloomGridMinimum: CGFloat = 150
        static let bloomThumbnailHeight: CGFloat = 128
        static let bloomMarkdownFirstColumn: CGFloat = 140
        static let bloomMarkdownColumn: CGFloat = 220
        static let bloomMapFitTop: CGFloat = 72
        static let bloomMapFitSide: CGFloat = 48
        static let bloomMapFitBottom: CGFloat = 88
        // Finance amount remains prominent without dominating the screen.
        static let budgetAmount: CGFloat = 40
        static let screenInset = Space.xLarge
        static let listInset = Space.large
        static let cardInset = Space.xLarge
        static let compactCardInset = Space.large
        static let groupedInset = Space.large
        static let nutritionInputLine: CGFloat = 32
        static let nutritionFieldHeight: CGFloat = 72
        static let touchTarget: CGFloat = 44
        static let toolbarVisual: CGFloat = 36
        static let nutritionGlyphWidth: CGFloat = 18
        static let nutritionGlyphHeight: CGFloat = 20
        static let nutritionGlyphStroke: CGFloat = 1.6
        static let healthSummaryRow: CGFloat = 132
        static let healthSummaryGap: CGFloat = 10
        static let healthSummaryChartWidth: CGFloat = 80
        static let healthSummaryChartHeight: CGFloat = 50
        static let healthOverviewChart: CGFloat = 88
        static let healthSelectionCaptionHeight: CGFloat = 28
        static let rowHeight: CGFloat = 52
        static let iconTile: CGFloat = 38
        static let tabHeight: CGFloat = 52
        static let primaryAction: CGFloat = 60
        static let healthChartHeight: CGFloat = 200
        static let categoryWidth: CGFloat = 88
        static let navigationInset = Space.large
        static let pastDayOpacity = 0.80
        static let activityDescriptionHeight: CGFloat = 90
        static let shiftBrushWidth: CGFloat = 44
        static let shiftBrushHeight: CGFloat = 60
        static let shiftProgressWidth: CGFloat = 144
        static let shiftProgressHeight: CGFloat = 8
        static let healthBarRadius: CGFloat = 2
        static let calendarDayNumber: CGFloat = 26
        static let selectionLine: CGFloat = 2
        static let datePickerSheetHeight: CGFloat = 480
        static let allDayChipWidth: CGFloat = 200
        static let agendaIndent: CGFloat = 12
        static let calendarDateNumber: CGFloat = 20
        static let calendarDateLine: CGFloat = 32
        static let calendarSwipeDistance: CGFloat = 44
        static let calendarMonthDayHeight: CGFloat = 88
        static let calendarDayHeight: CGFloat = 54
        static let calendarMarker: CGFloat = 3
        static let statusDot: CGFloat = 6
        static let scrollClearance = Space.bottom + Space.large
    }
    enum Motion {
        static let introDuration = 0.65
        static let introTickNanoseconds: UInt64 = 20_000_000
        static let pressDuration = 0.18
        static let selectionDuration = 0.16
        static let chartSelectionHoldDuration = 0.25
        static let layoutDuration = 0.26
        static let calendarDebounce: UInt64 = 180_000_000
        static let navigationResponse = 0.30
        static let navigationDamping = 0.82
        static let navigationPressResponse = 0.20
        static let navigationPressScale: CGFloat = 0.94
        static let navigationSelectionOpacity = 0.12
        static let pressedScale: CGFloat = 0.985
        static let pressedOpacity = 0.75
    }
    static let warning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.68, blue: 0.25, alpha: 1) : UIColor(red: 0.52, green: 0.28, blue: 0.02, alpha: 1)
    })
    static let danger = Color(uiColor: .systemRed)
    static let success = financialGreen
    static let gap = Space.large
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 12
    static let dayRadius: CGFloat = 12
    static let badgeRadius: CGFloat = 6
    static let progressRadius: CGFloat = 3
    static let heading = Font.system(.headline, weight: .semibold)
    static let value = Font.system(.title, weight: .semibold)
    static func budgetValue(size: CGFloat) -> Font { Font.system(size: size, weight: .semibold) }
    static let body = Font.system(.body, weight: .regular)
    static let metadata = Font.system(.footnote, weight: .regular)
    static let symbol = Font.system(.body, weight: .medium)
}
