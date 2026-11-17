import SwiftUI

/// Five destinations in the system tab bar; Finance opens from its Dashboard
/// card (NAVIGATION-FIVE-2026-11-16).
extension NativeTab {
    static let barOrder: [NativeTab] = [.dashboard, .tasks, .calendar, .health, .bloom]
}
