import SwiftUI

/// Entire Verse mode's progress strip: one dot per verse (gray = not done,
/// green = perfect, red = mistakes), or a continuous bar once there are too many
/// dots to read.
struct SessionProgressBar: View {
    @ObservedObject var vm: TestSessionViewModel

    /// More verses than this and the dots get too small to read.
    private static let maxDots = 24

    var body: some View {
        Group {
            if vm.verses.count > Self.maxDots { bar } else { dots }
        }
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(vm.completedCount) of \(vm.verses.count) done")
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(6, geo.size.width * CGFloat(vm.completedCount) / CGFloat(max(1, vm.verses.count))))
                    .animation(AppMotion.movement, value: vm.completedCount)
            }
        }
        .frame(height: 6)
    }

    private var dots: some View {
        GeometryReader { geo in
            let count   = vm.verses.count
            let spacing = CGFloat(3)
            let maxDot  = CGFloat(8)
            let dotSize = min(maxDot, (geo.size.width - spacing * CGFloat(max(1, count - 1))) / CGFloat(max(1, count)))

            HStack(spacing: spacing) {
                ForEach(Array(vm.verses.enumerated()), id: \.offset) { i, verse in
                    let submitted = vm.hasSubmitted(verse)
                    let correct   = vm.submitResults[verse.id]?.isAllCorrect == true
                    let isCurrent = i == vm.currentIndex

                    Circle()
                        .fill(submitted ? (correct ? Color.green : Color.red) : Color.secondary.opacity(0.25))
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(isCurrent ? 1.4 : 1.0)
                        .animation(AppMotion.control, value: isCurrent)
                        .animation(AppMotion.content, value: submitted)
                        .animation(AppMotion.content, value: correct)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 12)
    }
}
