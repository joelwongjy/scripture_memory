import SwiftUI

/// Google-Photos-style fast-scroll thumb pinned to the trailing edge. While
/// dragging, a pill floats to its left showing the target verse's title and
/// reference, the way Photos shows the month and year.
///
/// All position math lives in `ScrubberMath` (unit-tested).
struct VerseFastScrollOverlay: View {

    private static let thumbSize: CGFloat        = 40
    private static let thumbTrailingPad: CGFloat = 6
    private static let trackInset: CGFloat       = 8
    private static let hideDelay: Duration       = .milliseconds(1400)

    let verseCount:        Int
    /// Position through the deck in [0,1] (0 = first card, 1 = last).
    let scrollFraction:    Double
    let containerHeight:   CGFloat
    let titleProvider:     (Int) -> String
    let referenceProvider: (Int) -> String
    /// Called while dragging the thumb — the parent scrolls the list to `index`.
    let onScrubTo:         (Int) -> Void
    /// Stays on screen instead of fading out once scrolling stops: for content
    /// that doesn't scroll by itself, where the thumb is the way through it.
    var alwaysVisible = false

    @State private var isDragging       = false
    @State private var dragFraction:    Double = 0
    @State private var dragStartThumbY: CGFloat = 0
    @State private var lastDragIndex    = -1
    @State private var visible          = false
    @State private var hideTask:        Task<Void, Never>? = nil

    private var travel: CGFloat {
        CGFloat(ScrubberMath.trackTravel(containerHeight: Double(containerHeight),
                                         thumbSize: Double(Self.thumbSize),
                                         inset: Double(Self.trackInset)))
    }
    private var activeFraction: Double { isDragging ? dragFraction : min(max(scrollFraction, 0), 1) }
    private var effectiveIndex: Int { ScrubberMath.index(fraction: activeFraction, count: verseCount) }
    private var thumbY: CGFloat {
        CGFloat(ScrubberMath.thumbY(fraction: activeFraction,
                                    travel: Double(travel), inset: Double(Self.trackInset)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isDragging, (0..<verseCount).contains(effectiveIndex) {
                labelPill
                    .offset(x: -(Self.thumbSize + Self.thumbTrailingPad + 12), y: thumbY - 6)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            thumb
                .offset(x: -Self.thumbTrailingPad, y: thumbY)
                .gesture(dragGesture)
        }
        .frame(width: Self.thumbSize + Self.thumbTrailingPad + 2,
               height: containerHeight, alignment: .topTrailing)
        .opacity(visible || isDragging || alwaysVisible ? 1 : 0)
        .animation(AppMotion.control, value: visible)
        .allowsHitTesting(verseCount >= 2)
        .onAppear { flash() }
        .onChange(of: scrollFraction) { _, _ in if !isDragging { flash() } }
        .onDisappear { hideTask?.cancel() }
    }

    private var thumb: some View {
        ZStack {
            Circle().fill(Color(.secondarySystemBackground))
                .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .scaleEffect(isDragging ? 1.12 : 1)
        .opacity(isDragging ? 1 : 0.9)
        .animation(AppMotion.control, value: isDragging)
        .contentShape(Circle())
        .accessibilityHidden(true)
    }

    /// Hard cap so a long verse title can't push the floating pill off the left
    /// edge of the screen. Measured against the title/reference fonts so short
    /// titles still hug their content; longer ones truncate with an ellipsis.
    private static let pillContentMaxWidth: CGFloat = 188

    private func pillContentWidth() -> CGFloat {
        let titleFont: UIFont = {
            let b = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return b.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 15) } ?? b
        }()
        let refFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let tW = (titleProvider(effectiveIndex) as NSString).size(withAttributes: [.font: titleFont]).width
        let rW = (referenceProvider(effectiveIndex) as NSString).size(withAttributes: [.font: refFont]).width
        return min(max(tW, rW).rounded(.up) + 2, Self.pillContentMaxWidth)
    }

    private var labelPill: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(titleProvider(effectiveIndex))
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.primary).lineLimit(1).truncationMode(.tail)
            Text(referenceProvider(effectiveIndex))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
        }
        // Fixed (measured, capped) width so the pill escapes the narrow overlay
        // column without growing unbounded to the left.
        .frame(width: pillContentWidth(), alignment: .trailing)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    dragStartThumbY = thumbY
                    withAnimation(AppMotion.control) { isDragging = true }
                }
                dragFraction = ScrubberMath.fractionForDrag(
                    startThumbY: Double(dragStartThumbY),
                    translationY: Double(value.translation.height),
                    inset: Double(Self.trackInset),
                    travel: Double(travel))
                let idx = ScrubberMath.index(fraction: dragFraction, count: verseCount)
                if idx != lastDragIndex {
                    onScrubTo(idx)
                    HapticEngine.light()
                    lastDragIndex = idx
                }
            }
            .onEnded { _ in
                withAnimation(AppMotion.control) { isDragging = false }
                lastDragIndex = -1
                flash()
            }
    }

    /// Show the thumb and (re)arm the auto-hide timer.
    private func flash() {
        if !visible { withAnimation(AppMotion.control) { visible = true } }
        hideTask?.cancel()
        hideTask = Task { [delay = Self.hideDelay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isDragging else { return }
                withAnimation(AppMotion.movement) { visible = false }
            }
        }
    }
}
