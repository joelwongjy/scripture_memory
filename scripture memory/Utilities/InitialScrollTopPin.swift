import SwiftUI
import UIKit

/// Keeps a `ScrollView` at its true top while the navigation chrome settles.
///
/// A `.searchable(placement: .navigationBarDrawer(displayMode: .always))` field
/// is installed by UIKit *after* the scroll view's first layout. On a slow cold
/// launch on device (not reproducible in the simulator) the scroll view's
/// adjusted content inset grows by the search bar's height while its content
/// offset stays where the first layout put it — so the screen opens with the
/// large title already collapsed and the content nudged up under the bar.
///
/// This watches the enclosing `UIScrollView` for a short window after it
/// appears and, as long as the user hasn't touched it, re-anchors the offset to
/// `-adjustedContentInset.top` whenever that inset changes. It stands down on
/// the first drag and disarms itself after `duration`, so a user who scrolls
/// immediately is never fought.
struct InitialScrollTopPin: UIViewRepresentable {
    /// How long after appearing we keep correcting the offset.
    var duration: TimeInterval = 1.5

    func makeUIView(context: Context) -> PinView { PinView(duration: duration) }
    func updateUIView(_ uiView: PinView, context: Context) {}

    final class PinView: UIView {
        private let duration: TimeInterval
        private var timer: Timer?
        private var lastInsetTop: CGFloat?
        /// Armed once: the race only exists on the screen's first appearance.
        /// Re-attaching on a tab switch must not snap a scrolled screen back up.
        private var hasArmed = false

        init(duration: TimeInterval) {
            self.duration = duration
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var intrinsicContentSize: CGSize { .zero }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, !hasArmed else { return }
            hasArmed = true
            lastInsetTop = nil
            let deadline = Date().addingTimeInterval(duration)
            let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                if Date() >= deadline || self.correctIfNeeded() == .userTookOver {
                    t.invalidate()
                    self.timer = nil
                }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }

        private enum Outcome { case idle, corrected, userTookOver }

        private var enclosingScrollView: UIScrollView? {
            var v: UIView? = superview
            while let cur = v {
                if let s = cur as? UIScrollView { return s }
                v = cur.superview
            }
            return nil
        }

        @discardableResult
        private func correctIfNeeded() -> Outcome {
            guard let scroll = enclosingScrollView else { return .idle }
            // The moment the user touches it, it's theirs.
            if scroll.isTracking || scroll.isDragging || scroll.isDecelerating
                || scroll.panGestureRecognizer.state != .possible {
                return .userTookOver
            }
            let top = -scroll.adjustedContentInset.top
            defer { lastInsetTop = scroll.adjustedContentInset.top }
            // Only act when the chrome actually moved (inset changed) and the
            // offset didn't follow — that's the race, nothing else.
            guard let previous = lastInsetTop, previous != scroll.adjustedContentInset.top else {
                // First sample, or inset stable: still pin if we're visibly below top
                // by less than a bar's worth — a leftover from the same race.
                if scroll.contentOffset.y > top + 0.5, scroll.contentOffset.y - top < 200 {
                    scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: top), animated: false)
                    return .corrected
                }
                return .idle
            }
            if abs(scroll.contentOffset.y - top) > 0.5 {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: top), animated: false)
                return .corrected
            }
            return .idle
        }

        deinit { timer?.invalidate() }
    }
}

extension View {
    /// Apply to the *content* of a `ScrollView` whose screen uses an always-shown
    /// search drawer. See `InitialScrollTopPin`.
    func pinsInitialScrollOffsetToTop() -> some View {
        background(InitialScrollTopPin().frame(width: 0, height: 0), alignment: .top)
    }
}
