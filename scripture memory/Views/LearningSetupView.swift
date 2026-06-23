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
                WelcomeScreen { withAnimation(.easeInOut) { showWelcome = false } }
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

// MARK: - Welcome (Apple-style hero + feature callouts)

private struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 56)
                    .padding(.bottom, 22)

                Text("Welcome to\nScripture Memory")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)

                VStack(alignment: .leading, spacing: 30) {
                    FeatureRow(icon: "text.book.closed.fill",
                               title: "Memorize Scripture",
                               subtitle: "Learn verses one at a time, in order, at your own pace.",
                               tint: .blue)
                    FeatureRow(icon: "flame.fill",
                               title: "Build a daily streak",
                               subtitle: "A verse a day keeps your momentum going.",
                               tint: .orange)
                    FeatureRow(icon: "arrow.triangle.2.circlepath",
                               title: "Reviews that stick",
                               subtitle: "Spaced repetition brings verses back right before you'd forget.",
                               tint: .green)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(tint)
                .frame(width: 42, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Starting-point picker (pack list → exact verse)

private struct StartingPointScreen: View {
    let packs:   [Pack]
    let ordered: [Verse]
    var isOnboarding: Bool
    var onPick:   (Verse) -> Void
    var onCancel: () -> Void

    /// The starting point the user has tapped but not yet confirmed. Seeded from
    /// the existing progress so re-opening shows the current pick.
    @State private var pending: Verse?

    init(packs: [Pack], ordered: [Verse], isOnboarding: Bool, currentKey: String?,
         onPick: @escaping (Verse) -> Void, onCancel: @escaping () -> Void) {
        self.packs        = packs
        self.ordered      = ordered
        self.isOnboarding = isOnboarding
        self.onPick       = onPick
        self.onCancel     = onCancel
        _pending = State(initialValue: ordered.first { $0.srsKey == currentKey })
    }

    var body: some View {
        List {
            Section {
                Button {
                    guard let first = ordered.first else { return }
                    pending = first
                    HapticEngine.light()
                } label: {
                    HStack {
                        Label("Start from the beginning", systemImage: "flag.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isSelected(ordered.first) { checkmark }
                    }
                }
            }

            Section {
                ForEach(packs) { pack in
                    NavigationLink {
                        VerseListScreen(pack: pack,
                                        selectedKey: pending?.srsKey,
                                        onSelect: { pending = $0 })
                    } label: {
                        HStack {
                            Text(pack.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            // The first verse is represented by "Start from the beginning"
                            // above (which carries its own check), so only badge a pack for
                            // a specific, non-first verse — otherwise both would show a check.
                            if let v = pending,
                               v.srsKey != ordered.first?.srsKey,
                               pack.verses.contains(where: { $0.srsKey == v.srsKey }) {
                                Text("\(v.book) \(v.reference)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                checkmark
                            }
                        }
                    }
                }
            } header: {
                Text("Already memorizing? Pick where you stopped")
            }
        }
        .navigationTitle(isOnboarding ? "Your Starting Point" : "Current Verse")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { confirmBar }
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private var confirmBar: some View {
        // A pinned footer bar (hairline + frosted material) rather than a bare
        // floating button, so list rows scroll under a clear bar instead of
        // bleeding behind the button — the standard Apple bottom-CTA pattern.
        VStack(spacing: 0) {
            Divider()
            Button {
                guard let pending else { return }
                HapticEngine.light()
                onPick(pending)
            } label: {
                Text("Confirm")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(pending == nil)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func isSelected(_ verse: Verse?) -> Bool {
        guard let verse, let pending else { return false }
        return verse.srsKey == pending.srsKey
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
    }
}

private struct VerseListScreen: View {
    let pack: Pack
    var selectedKey: String?
    var onSelect: (Verse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(pack.verses) { verse in
                    Button {
                        HapticEngine.light()
                        onSelect(verse)
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(verse.book) \(verse.reference)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(verse.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                Text(verse.verse)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if verse.srsKey == selectedKey {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Tap the verse you last memorized up to.")
            }
        }
        .navigationTitle(pack.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
