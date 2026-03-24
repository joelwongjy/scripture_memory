import SwiftUI

/// Shared prev / scrub track / next row used by pack study and test session.
struct VerseScrubberRow: View {

    private static let knobWidth: CGFloat = 30
    private static let settleDelay: TimeInterval = 0.4

    let verseCount: Int
    @Binding var currentIndex: Int
    @Binding var isScrubbing: Bool
    var showPositionLabel: Bool
    /// Test session uses a shorter track; pack study uses a slightly taller hit target.
    var trackHeight: CGFloat = 34
    /// Called when the user drags the scrubber to a new index (e.g. persist test session).
    var onScrubIndexChange: (() -> Void)?

    let onStepBack: () -> Void
    let onStepForward: () -> Void

    var body: some View {
        VStack(spacing: showPositionLabel ? 6 : 0) {
            HStack(spacing: 10) {
                let canPrev = currentIndex > 0
                let canNext = currentIndex < verseCount - 1

                Button(action: onStepBack) {
                    Image(systemName: "chevron.left").studyScrubberChevronButton()
                }
                .disabled(!canPrev)
                .opacity(canPrev ? 1 : 0.3)

                scrubTrack

                Button(action: onStepForward) {
                    Image(systemName: "chevron.right").studyScrubberChevronButton()
                }
                .disabled(!canNext)
                .opacity(canNext ? 1 : 0.3)
            }

            if showPositionLabel {
                Text("\(currentIndex + 1) / \(verseCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var scrubTrack: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let knobW = Self.knobWidth
            let knobX: CGFloat = verseCount > 1
                ? CGFloat(currentIndex) / CGFloat(verseCount - 1) * (w - knobW)
                : (w - knobW) / 2
            let progress = verseCount > 1 ? CGFloat(currentIndex) / CGFloat(verseCount - 1) : 0
            let fillW = knobW / 2 + progress * (w - knobW)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: 6)
                Capsule()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: fillW, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    .frame(width: knobW, height: knobW)
                    .offset(x: knobX)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        guard w > 0, verseCount > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / w))
                        let newIndex = Int(round(fraction * CGFloat(max(verseCount - 1, 0))))
                        if newIndex != currentIndex, (0..<verseCount).contains(newIndex) {
                            currentIndex = newIndex
                            onScrubIndexChange?()
                            HapticEngine.light()
                        }
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
                            isScrubbing = false
                        }
                    }
            )
        }
        .frame(height: trackHeight)
    }
}
