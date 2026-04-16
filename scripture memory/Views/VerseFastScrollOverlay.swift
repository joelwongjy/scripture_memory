import SwiftUI

/// Preference key used by `CardStudyView` to measure the actual rendered
/// height of its vertical-scroll area. Nested GeometryReaders produced
/// unreliable heights during initial layout; a preference-key probe on the
/// ScrollView's background gets the true post-layout size.
struct ScrollAreaHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Current Y offset of the scroll content (the minY of the content frame
/// in the scroll view's named coordinate space — becomes negative as the
/// user scrolls down). Changes on every scroll event; the parent uses this
/// to derive which card is currently visible and pulse the fade-in timer.
struct ScrollContentOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Total height of the scroll content (the full LazyVStack, including all
/// cards + padding). Paired with the area height to compute the max
/// scrollable distance.
struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Fast-scroll thumb for the vertical-scroll read mode.
///
/// A draggable thumb pinned to the trailing edge. Dim when idle, full-opacity
/// when grabbed. While dragging, a pill floats to its left showing
/// `labelProvider(index)` — typically "Matthew 5:3".
///
/// IMPORTANT: this view requires the caller to pass `containerHeight`
/// explicitly (the pixel height of the scroll area). Nested GeometryReaders
/// inside `.overlay` / `ZStack` produced unreliable heights (collapsing to
/// ~40pt), so we take the height as input instead.
struct VerseFastScrollOverlay: View {

    // MARK: - Layout constants

    private static let thumbSize: CGFloat          = 36
    private static let thumbTrailingPad: CGFloat   = 6
    private static let trackVerticalInset: CGFloat = 8

    // MARK: - Public props

    let verseCount: Int
    /// Continuous 0.0-1.0 scroll position. When the user scrolls the list,
    /// the thumb follows this directly so motion is smooth rather than
    /// snapping between integer verse indices.
    let scrollFraction: Double
    /// Full height of the enclosing scroll area. Source of truth for the track.
    let containerHeight: CGFloat
    @Binding var isScrubbing: Bool
    /// Bumped by the parent on every scroll offset change. Watching this
    /// drives the fade-in / restart-hide-timer behavior.
    @Binding var scrollActivityPulse: Int
    let labelProvider: (Int) -> String
    /// Called while the user drags the thumb. Parent scrolls the list.
    let onScrubTo: (Int) -> Void

    // MARK: - Internal state

    @State private var isDragging: Bool = false
    @State private var dragIndex: Int? = nil
    @State private var lastHapticIndex: Int = -1
    /// Thumb Y at drag start. Set once in `onChanged` when dragging begins,
    /// used together with `value.translation.height` to compute the target
    /// without the positive-feedback loop that `value.location.y` caused
    /// (locationY is in LAYOUT coords and doesn't track .offset changes).
    @State private var dragStartThumbY: CGFloat = 0

    // Fade-in / fade-out state.
    @State private var thumbVisible: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil

    private static let hideDelay: Duration      = .milliseconds(1500)
    private static let showAnimation: Animation = .easeOut(duration: 0.15)
    private static let hideAnimation: Animation = .easeOut(duration: 0.35)

    /// Drag index (snapped to finger) when dragging; otherwise the integer
    /// index nearest the current `scrollFraction`. Used for the label pill
    /// and haptic boundaries — NOT for the thumb's Y position.
    private var effectiveIndex: Int {
        if let dragIndex { return dragIndex }
        guard verseCount > 1 else { return 0 }
        let raw = Int((scrollFraction * Double(verseCount - 1)).rounded())
        return max(0, min(verseCount - 1, raw))
    }

    /// How far the thumb can travel vertically (thumb TOP Y position range).
    private var trackTravel: CGFloat {
        max(0, containerHeight - 2 * Self.trackVerticalInset - Self.thumbSize)
    }

    private var thumbY: CGFloat {
        let fraction: CGFloat
        if let dragIndex, verseCount > 1 {
            // While dragging, snap to the integer finger position.
            fraction = CGFloat(dragIndex) / CGFloat(verseCount - 1)
        } else {
            // Otherwise follow the continuous scroll fraction for smooth motion.
            fraction = CGFloat(max(0, min(1, scrollFraction)))
        }
        return Self.trackVerticalInset + fraction * trackTravel
    }

    // MARK: - Body

    var body: some View {
        let visible = thumbVisible || isDragging
        ZStack(alignment: .topTrailing) {
            if isDragging, (0..<verseCount).contains(effectiveIndex) {
                labelPill(text: labelProvider(effectiveIndex))
                    .offset(x: -(Self.thumbSize + Self.thumbTrailingPad + 10),
                            y: thumbY - 4)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            thumb
                .offset(x: -Self.thumbTrailingPad, y: thumbY)
                .gesture(dragGesture)
        }
        .frame(width: Self.thumbSize + Self.thumbTrailingPad + 2,
               height: containerHeight,
               alignment: .topTrailing)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(verseCount >= 2 && visible)
        .onAppear {
            // Guarantee the thumb gets one visible flash on mount even if
            // preference-based scroll pulses haven't arrived yet. The hide
            // timer takes it back down after ~1.5s.
            showAndRestartHideTimer()
        }
        .onChange(of: scrollActivityPulse) { _, _ in
            showAndRestartHideTimer()
        }
        .onDisappear {
            hideTask?.cancel()
        }
    }

    // MARK: - Thumb

    private var thumb: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
                .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.blue)
        }
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .opacity(isDragging ? 1.0 : 0.85)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
        .contentShape(Circle())
    }

    // MARK: - Label pill

    private func labelPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .serif))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            )
            .fixedSize()
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChange(translationY: value.translation.height)
            }
            .onEnded { _ in
                handleDragEnd()
            }
    }

    private func handleDragChange(translationY: CGFloat) {
        guard verseCount > 1, trackTravel > 0 else { return }
        if !isDragging {
            // Snapshot starting thumb position so translation is relative
            // to where the drag began, not where the thumb currently is.
            // Using `value.location.y` instead would create a positive-
            // feedback loop — `location.y` is in layout coords and doesn't
            // track the thumb's `.offset`, so as we moved the thumb each
            // frame, the formula kept piling on more displacement.
            dragStartThumbY = thumbY
            withAnimation(.easeOut(duration: 0.15)) { isDragging = true }
        }
        isScrubbing = true

        let targetThumbY = dragStartThumbY + translationY
        let targetThumbTopInTrack = targetThumbY - Self.trackVerticalInset
        let fraction = max(0, min(1, targetThumbTopInTrack / trackTravel))

        let newIndex = Int((fraction * CGFloat(verseCount - 1)).rounded())
        guard (0..<verseCount).contains(newIndex) else { return }
        let changed = newIndex != effectiveIndex
        dragIndex = newIndex
        if changed {
            onScrubTo(newIndex)
            if newIndex != lastHapticIndex {
                HapticEngine.light()
                lastHapticIndex = newIndex
            }
        }
    }

    private func handleDragEnd() {
        withAnimation(.easeOut(duration: 0.15)) { isDragging = false }
        lastHapticIndex = -1
        dragIndex = nil
        // Match VerseScrubberRow.settleDelay (0.4s) so downstream code that
        // observes `isScrubbing` has time to settle before we drop the flag.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isScrubbing = false
        }
        // Keep the thumb visible briefly after release, then fade.
        showAndRestartHideTimer()
    }

    // MARK: - Fade timing

    /// Show the thumb and (re)arm the hide timer. Called on every scroll
    /// activity pulse and at the end of a drag. Uses a cancellable `Task`
    /// so rapid pulses don't stack up timers — each new pulse cancels the
    /// pending hide and starts a fresh one.
    private func showAndRestartHideTimer() {
        if !thumbVisible {
            withAnimation(Self.showAnimation) { thumbVisible = true }
        }
        hideTask?.cancel()
        hideTask = Task { [hideDelay = Self.hideDelay] in
            try? await Task.sleep(for: hideDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isDragging else { return }
                withAnimation(Self.hideAnimation) { thumbVisible = false }
            }
        }
    }
}
