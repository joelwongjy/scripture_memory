import SwiftUI

/// Shown under the card once every verse in a quiz is done: the result, then
/// Try Again or Done.
struct SessionCompletePanel: View {
    @ObservedObject var vm: TestSessionViewModel
    let studyMode: StudyMode
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: vm.sessionScore == 0 ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(vm.sessionScore == 0 ? Color.green : Color.accentColor)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text("Session Complete!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)

            // Only Entire Verse mode tracks mistakes, so only it has a score.
            if studyMode == .submit {
                if vm.sessionScore == 0 {
                    Text("Perfect!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.green)
                } else {
                    Text("Score: \(vm.sessionScore)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.red)
                }

                Text("\(vm.perfectCount) of \(vm.verses.count) perfect")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            } else {
                Text("\(vm.verses.count) verses reviewed")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                Button { vm.resetAllProgress() } label: {
                    Text("Try Again").studyActionLabel()
                }
                Button(action: onDone) {
                    Text("Done").studyActionLabel(foreground: .white, background: .accentColor)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

/// Entire Verse mode's running score in the top bar: ✓ when the session is
/// perfect and done, otherwise the (zero or negative) score.
struct SessionScoreBadge: View {
    @ObservedObject var vm: TestSessionViewModel

    var body: some View {
        Group {
            if vm.isSessionComplete && vm.sessionScore == 0 {
                Text("✓")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.green)
            } else {
                Text("\(vm.sessionScore)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(vm.sessionScore < 0 ? Color.red : Color.secondary)
            }
        }
        .frame(width: 36, height: 36)
        .background(Color(.secondarySystemBackground), in: Circle())
        .animation(AppMotion.content, value: vm.sessionScore)
    }
}
