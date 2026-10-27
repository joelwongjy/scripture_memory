import SwiftUI

/// Previous / position slider / next, under the card in a test session.
struct VerseScrubberRow: View {
    let verseCount: Int
    @Binding var currentIndex: Int
    @Binding var isScrubbing: Bool
    /// Called when the user drags the slider to a new index (e.g. persist test session).
    var onScrubIndexChange: (() -> Void)?

    let onStepBack: () -> Void
    let onStepForward: () -> Void

    var body: some View {
        if verseCount > 1 {
            HStack(spacing: 12) {
                Button("Previous Verse", systemImage: "chevron.left", action: onStepBack)
                    .disabled(currentIndex == 0)
                Slider(value: position, in: 0...Double(verseCount - 1), step: 1) { editing in
                    if editing {
                        isScrubbing = true
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                            isScrubbing = false
                        }
                    }
                }
                .accessibilityLabel("Verse position")
                .accessibilityValue("\(currentIndex + 1) of \(verseCount)")
                Button("Next Verse", systemImage: "chevron.right", action: onStepForward)
                    .disabled(currentIndex >= verseCount - 1)
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .systemGlassButton()
        }
    }

    private var position: Binding<Double> {
        Binding {
            Double(currentIndex)
        } set: { value in
            let index = Int(value.rounded())
            guard index != currentIndex, (0..<verseCount).contains(index) else { return }
            currentIndex = index
            onScrubIndexChange?()
            HapticEngine.light()
        }
    }
}
