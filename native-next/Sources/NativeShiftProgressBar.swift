import SwiftUI

/// SHIFT-BAR-97: the background of the shift badge, in four 2-hour parts with a small gap. Same colours as
/// before (shift colour, done part fuller). On entering the app during the shift (or within 15 minutes after
/// its end) the parts fill again one after the other from left to right, once per completed part.
struct NativeShiftProgressBar: View {
    let model: NativeDashboardFocus
    let now: Date
    let activation: Date
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var reveal = 1.0
    private static let step = 0.28

    var body: some View {
        HStack(spacing: NativeDesign.Space.xxs) {
            if let interval = model.workInterval {
                let tint = model.shift?.color ?? NativeDesign.accent
                let slots = NativeShiftProgress.slots(interval: interval, now: model.justEnded ? interval.end : now)
                ForEach(slots) { slot in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(tint.opacity(0.24))
                            Rectangle().fill(tint.opacity(0.42))
                                .frame(width: geometry.size.width * slot.fraction * reveal)
                                .animation(reduceMotion ? nil : .easeOut(duration: Self.step).delay(Double(slot.index) * Self.step), value: reveal)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: activation) {
            guard let interval = model.workInterval,
                  NativeShiftBurstLedger.shared.claim(interval: interval, activation: activation, now: Date()) != nil,
                  !reduceMotion else { return }
            var instant = Transaction(); instant.disablesAnimations = true
            withTransaction(instant) { reveal = 0 }
            do { try await Task.sleep(nanoseconds: 60_000_000) } catch { reveal = 1; return }
            reveal = 1
        }
    }
}
