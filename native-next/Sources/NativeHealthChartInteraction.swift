import SwiftUI
import UIKit

/// UIKit arbitrates a deliberate hold against the enclosing scroll view's pan.
/// A quick vertical swipe fails the hold and remains a normal page scroll.
struct NativeHealthChartInteraction: UIViewRepresentable {
    let onSelect: (CGFloat) -> Void
    let onScrubbing: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect, onScrubbing: onScrubbing) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear; view.isOpaque = false
        view.isAccessibilityElement = false; view.accessibilityElementsHidden = true
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.held(_:)))
        hold.minimumPressDuration = NativeDesign.Motion.chartSelectionHoldDuration
        hold.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.require(toFail: hold); tap.delegate = context.coordinator
        view.addGestureRecognizer(hold); view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onSelect = onSelect; context.coordinator.onScrubbing = onScrubbing
    }
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.onScrubbing(false)
        coordinator.onSelect = { _ in }; coordinator.onScrubbing = { _ in }
        for gesture in view.gestureRecognizers ?? [] { view.removeGestureRecognizer(gesture) }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onSelect: (CGFloat) -> Void
        var onScrubbing: (Bool) -> Void
        init(onSelect: @escaping (CGFloat) -> Void, onScrubbing: @escaping (Bool) -> Void) {
            self.onSelect = onSelect; self.onScrubbing = onScrubbing
            super.init()
        }
        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onSelect(gesture.location(in: gesture.view).x)
        }
        @objc func held(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                onScrubbing(true); onSelect(gesture.location(in: gesture.view).x)
            case .changed: onSelect(gesture.location(in: gesture.view).x)
            case .ended:
                onSelect(gesture.location(in: gesture.view).x); onScrubbing(false)
            case .cancelled, .failed: onScrubbing(false)
            default: break
            }
        }
        func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            gesture is UITapGestureRecognizer && !(other is UILongPressGestureRecognizer)
        }
    }
}
