import Foundation

/// UIKit's file result and SwiftUI's dismissal can arrive in either order.
/// Release the selected bytes once both events have arrived, exactly once.
struct NativeBloomPickerHandoff {
    private var selection: Data?
    private var dismissed = false
    private var delivered = false
    private var cancelled = false

    mutating func begin() { self = Self() }
    mutating func picked(_ data: Data) {
        guard !cancelled, !delivered else { return }
        selection = data
    }
    mutating func didDismiss() { dismissed = true }
    mutating func cancel() { cancelled = true; selection = nil }
    mutating func takeReadyData() -> Data? {
        guard dismissed, !cancelled, !delivered, let data = selection else { return nil }
        delivered = true; selection = nil
        return data
    }
    var diagnostic: String {
        "dismissed=\(dismissed);selected=\(selection != nil);delivered=\(delivered);cancelled=\(cancelled)"
    }
}
