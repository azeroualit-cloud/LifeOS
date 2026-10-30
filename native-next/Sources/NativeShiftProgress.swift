import Foundation

struct NativeShiftSlot: Identifiable, Equatable {
    let index: Int
    let duration: TimeInterval
    let fraction: Double
    var id: Int { index }
}
enum NativeShiftProgress {
    static func slots(interval: DateInterval, now: Date) -> [NativeShiftSlot] {
        let slot = 2.0 * 3600
        let count = Int(ceil(interval.duration / slot))
        return (0..<count).map { index in
            let offset = Double(index) * slot, duration = min(slot, interval.duration - offset)
            return NativeShiftSlot(index: index, duration: duration, fraction: min(1, max(0, now.timeIntervalSince(interval.start) - offset) / duration))
        }
    }
    static func latestCompleted(interval: DateInterval, now: Date) -> Int? {
        guard now >= interval.start && now < interval.end else { return nil }
        return slots(interval: interval, now: now).last(where: { $0.fraction >= 1 })?.index
    }
}
/// Local, persistent consumption. No timer or tab switch can claim an activation twice.
@MainActor final class NativeShiftBurstLedger {
    static let shared = NativeShiftBurstLedger()
    private let defaults: UserDefaults
    private var lastActivation: Date?
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func claim(interval: DateInterval, activation: Date, now: Date) -> Int? {
        guard lastActivation != activation else { return nil }
        lastActivation = activation
        guard now.timeIntervalSince(activation) >= 0, now.timeIntervalSince(activation) < 20,
              let index = NativeShiftProgress.latestCompleted(interval: interval, now: activation) else { return nil }
        let key = "\(Int(interval.start.timeIntervalSince1970)):\(index)"
        var seen = defaults.stringArray(forKey: "lifeos-shift-bursts-v1") ?? []
        guard !seen.contains(key) else { return nil }
        seen.append(key); defaults.set(Array(seen.suffix(96)), forKey: "lifeos-shift-bursts-v1")
        return index
    }
}
