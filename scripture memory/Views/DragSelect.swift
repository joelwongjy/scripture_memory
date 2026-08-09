import SwiftUI
import UIKit

/// Two-finger drag to select a run of rows, the way Telegram, Photos and Files do.
///
/// Picking forty consecutive verses by tapping forty checkboxes is the tedium
/// this removes. Two fingers rather than one because a single-finger drag is
/// already spoken for — it scrolls the list — whereas a two-finger pan is
/// otherwise unused, so the two gestures never have to arbitrate.
///
/// The direction of the first row decides the whole drag: start on an unselected
/// row and the run selects, start on a selected one and it clears. Toggling each
/// row independently would leave a dragged-over run alternating, which is never
/// what's wanted.

// MARK: - Row geometry

/// Where each row currently is on screen.
///
/// A plain class, not an `ObservableObject`: these are rewritten on every frame
/// of a scroll, and publishing that would re-render the whole list continuously.
/// Nothing reads the frames except the drag, and the drag reads them live.
final class DragSelectFrames {
    private(set) var frames: [Int: CGRect] = [:]

    func record(_ id: Int, _ frame: CGRect) { frames[id] = frame }
    func forget(_ id: Int) { frames.removeValue(forKey: id) }

    /// The row under `point`, in global coordinates.
    func row(at point: CGPoint) -> Int? {
        frames.first { $0.value.contains(point) }?.key
    }
}

extension View {
    /// Registers this row's position so a two-finger drag can find it.
    func dragSelectRow(id: Int, in store: DragSelectFrames) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear    { store.record(id, geo.frame(in: .global)) }
                    .onDisappear { store.forget(id) }
                    .onChange(of: geo.frame(in: .global)) { _, new in store.record(id, new) }
            }
        )
    }
}

// MARK: - The gesture

/// Installs a two-finger pan on the enclosing scroll view and reports where it is.
///
/// The recogniser goes on the `UIScrollView` rather than on an overlay: an
/// overlay big enough to catch the drag would also swallow the taps meant for
/// the rows underneath, and a view that refuses hit-testing never sees the
/// gesture either.
struct TwoFingerDragSelect: UIViewRepresentable {
    /// Global-coordinate point, and whether this is the first callback of a drag.
    var onDrag: (CGPoint, Bool) -> Void
    var onEnd:  () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false      // never intercepts taps
        context.coordinator.attach(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        // The scroll view may not exist yet on the first layout pass.
        context.coordinator.attach(from: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TwoFingerDragSelect
        private weak var attachedTo: UIScrollView?
        private var began = false

        init(_ parent: TwoFingerDragSelect) { self.parent = parent }

        func attach(from view: UIView) {
            guard attachedTo == nil else { return }
            // Walk up to the List's scroll view.
            var node: UIView? = view
            while let current = node, !(current is UIScrollView) { node = current.superview }
            guard let scroll = node as? UIScrollView else {
                // Layout isn't settled yet; try again next runloop turn.
                DispatchQueue.main.async { [weak view] in
                    if let view { self.attach(from: view) }
                }
                return
            }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.delegate = self
            scroll.addGestureRecognizer(pan)
            attachedTo = scroll
        }

        @objc func handle(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                began = false
                fallthrough
            case .changed:
                // `nil` gives window coordinates, which is what SwiftUI's
                // `.global` frames are measured in — so the two agree without
                // any conversion.
                let point = gesture.location(in: nil)
                parent.onDrag(point, !began)
                began = true
            case .ended, .cancelled, .failed:
                began = false
                parent.onEnd()
            default:
                break
            }
        }

        /// Runs alongside the scroll view's own recognisers rather than fighting
        /// them; a two-finger pan won't trigger a one-finger scroll anyway.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
