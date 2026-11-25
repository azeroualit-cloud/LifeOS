import SwiftUI

/// NAV-E-SLOT-2026-11-25: Dashboard · Attività · Calendario · Salute are fixed; the fifth tab
/// (Finanza or Bloom) is chosen on the site (Admin › Barra dell'iPhone, setting «app-layout»).
/// The other one opens from its Dashboard card. Supersedes NAVIGATION-FIVE-2026-11-16.
@MainActor final class NativeAppLayout: ObservableObject {
    static let shared = NativeAppLayout()
    static let slotKey = "lifeos.tab.slot"
    @Published private(set) var slot: NativeTab

    private init() {
        // Visual tests keep Bloom unless a test passes «-lifeos.tab.slot finance».
        var fallback = NativeTab.finance
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--visual-test") { fallback = .bloom }
        #endif
        slot = Self.slot(from: UserDefaults.standard.string(forKey: Self.slotKey)) ?? fallback
    }
    /// Only «finance» and «bloom» are valid; anything else keeps the current choice.
    nonisolated static func slot(from value: String?) -> NativeTab? {
        switch value { case "finance": return .finance; case "bloom": return .bloom; default: return nil }
    }
    /// Applies the site's doc; the choice is kept on the phone for when the server is unreachable.
    func apply(_ doc: Record) {
        guard let next = Self.slot(from: doc.text("tabSlot")) else { return }
        UserDefaults.standard.set(next == .bloom ? "bloom" : "finance", forKey: Self.slotKey)
        if next != slot { slot = next }
    }
    var barOrder: [NativeTab] { [.dashboard, .tasks, .calendar, .health, slot] }
    func inBar(_ tab: NativeTab) -> Bool { barOrder.contains(tab) }
}
