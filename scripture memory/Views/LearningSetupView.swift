import SwiftUI

/// First-launch onboarding **and** the re-openable "starting point" picker.
///
/// Onboarding shows an Apple-style welcome (hero icon + feature callouts), then
/// lets the user pick the **exact verse** they're up to via a pack → verse
/// drill-down. Opened from Settings it skips the welcome and goes straight to
/// the picker (with a Cancel button).
struct LearningSetupView: View {
    var isOnboarding: Bool
    /// Whether to lead with the welcome hero. New installs do; existing users
    /// (who already know the app) skip straight to the picker.
    var showsWelcome: Bool
    var onComplete: () -> Void

    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showWelcome: Bool

    init(isOnboarding: Bool = false, showsWelcome: Bool = true, onComplete: @escaping () -> Void = {}) {
        self.isOnboarding = isOnboarding
        self.showsWelcome = showsWelcome
        self.onComplete   = onComplete
        _showWelcome = State(initialValue: isOnboarding && showsWelcome)
    }

    private var packs:   [Pack]  { packPrefs.visible(from: bibleVersion.packs) }
    private var ordered: [Verse] { packs.flatMap(\.verses) }

    var body: some View {
        Group {
            if showWelcome {
                WelcomeScreen { withAnimation(AppMotion.content) { showWelcome = false } }
            } else {
                NavigationStack {
                    StartingPointScreen(
                        packs:        packs,
                        ordered:      ordered,
                        isOnboarding: isOnboarding,
                        currentKey:   learning.current(in: ordered)?.verse.srsKey,
                        onPick: { verse in
                            learning.setProgress(startingAt: verse, in: ordered)
                            finish()
                        },
                        onCancel: { dismiss() }
                    )
                }
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(isOnboarding)
    }

    private func finish() {
        onComplete()
        dismiss()
    }
}
