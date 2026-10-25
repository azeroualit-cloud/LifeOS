import SwiftUI

/// Only the arriving content fades; native tabs retain identity and scroll state.
struct NativeDestinationMotion: ViewModifier {
    @EnvironmentObject private var router: NativeRouter
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let tab: NativeTab
    @State private var arrived = true
    func body(content: Content) -> some View {
        content.opacity(arrived ? 1 : 0)
            .task(id: router.tab) {
                guard router.tab == tab else { return }
                guard !reduceMotion else { arrived = true; return }
                var reset = Transaction(); reset.disablesAnimations = true
                withTransaction(reset) { arrived = false }
                await Task.yield()
                guard !Task.isCancelled else { arrived = true; return }
                withAnimation(.easeOut(duration: NativeDesign.Motion.layoutDuration)) { arrived = true }
            }
    }
}
