import SwiftUI

struct NativeShiftProgressBar: View {
    let model: NativeDashboardFocus
    let now: Date
    let activation: Date
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @State private var burst: Int?
    @State private var pulse = 0.0
    var body: some View {
        GeometryReader { geometry in
            if let interval = model.workInterval {
                let slots = NativeShiftProgress.slots(interval: interval, now: now)
                let usable = max(0, geometry.size.width - NativeDesign.Space.xs * CGFloat(max(0, slots.count - 1)))
                HStack(spacing: NativeDesign.Space.xs) {
                    ForEach(slots) { slot in
                        let width = usable * slot.duration / interval.duration
                        ZStack(alignment: .leading) {
                            Capsule().fill((model.shift?.color ?? NativeDesign.accent).opacity(0.14))
                            Capsule().fill(model.shift?.color ?? NativeDesign.accent).frame(width: width * slot.fraction)
                        }.frame(width: width)
                            .scaleEffect(burst == slot.index ? 1 + pulse * 0.08 : 1)
                            .overlay {
                                if burst == slot.index && !reduceMotion {
                                    ForEach(0..<5) { dot in
                                        Circle().fill((model.shift?.color ?? NativeDesign.accent).opacity(pulse * 0.6))
                                            .frame(width: NativeDesign.Space.xxs, height: NativeDesign.Space.xxs)
                                            .offset(x: cos(Double(dot) * .pi * 2 / 5) * (4 + pulse * 10), y: sin(Double(dot) * .pi * 2 / 5) * (4 + pulse * 10))
                                    }
                                }
                            }
                    }
                }
            }
        }.frame(height: NativeDesign.Layout.shiftProgressHeight)
            .accessibilityHidden(true)
            .task(id: activation) {
                guard let interval = model.workInterval,
                      let index = NativeShiftBurstLedger.shared.claim(interval: interval, activation: activation, now: Date()) else { return }
                guard !reduceMotion else { return }
                burst = index
                withAnimation(.easeOut(duration: 0.16)) { pulse = 1 }
                do { try await Task.sleep(nanoseconds: 180_000_000) } catch { pulse = 0; return }
                withAnimation(.easeOut(duration: 0.24)) { pulse = 0 }
            }
    }
}
