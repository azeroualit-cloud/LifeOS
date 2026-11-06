import SwiftUI

struct NativeShiftProgressBar: View {
    let model: NativeDashboardFocus
    let now: Date
    let activation: Date
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var pulse = 0.0
    var body: some View {
        GeometryReader { geometry in
            if let interval = model.workInterval {
                let fraction = min(1, max(0, now.timeIntervalSince(interval.start) / interval.duration))
                let tint = model.shift?.color ?? NativeDesign.accent
                ZStack(alignment: .leading) {
                    Rectangle().fill(tint.opacity(0.14))
                    Rectangle().fill(tint.opacity(0.42 + pulse * 0.08))
                        .frame(width: geometry.size.width * fraction)
                }.animation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.layoutDuration), value: fraction)
            }
        }
            .accessibilityHidden(true)
            .task(id: activation) {
                guard let interval = model.workInterval,
                      NativeShiftBurstLedger.shared.claim(interval: interval, activation: activation, now: Date()) != nil else { return }
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.16)) { pulse = 1 }
                do { try await Task.sleep(nanoseconds: 180_000_000) } catch { pulse = 0; return }
                withAnimation(.easeOut(duration: 0.24)) { pulse = 0 }
            }
    }
}
