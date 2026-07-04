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

// MARK: - Welcome (a card is dealt onto the desk; you learn by handling it)

/// The welcome IS the product: a real card deals in from off-screen and the
/// user learns the app's two core verbs by doing them — flip it over, then
/// flick it away — before being asked a single setup question.
private struct WelcomeScreen: View {
    var onContinue: () -> Void

    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84

    private enum Step { case deal, flip, toss, done }
    @State private var step: Step = .deal
    @State private var dealt      = false
    @State private var tossed     = false
    @State private var dragOffset: CGSize = .zero

    /// The very first verse of the library — a real card, not a mockup.
    private var sample: Verse? { bibleVersion.packs.first?.verses.first }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Scripture Memory")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text(caption)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .id(step)                       // new step = fresh caption…
                    .transition(.opacity)           // …crossfaded by the step animation
                    .frame(minHeight: 48, alignment: .top)
            }
            .padding(.top, 32)

            Spacer(minLength: 12)

            ZStack {
                if let verse = sample, !tossed {
                    FlashcardView(
                        verse: verse,
                        cardLabel: verse.packName,
                        isReviewMode: false,
                        titleRevealedCount: 0,
                        verseRevealedCount: 0,
                        activeSection: .verse,
                        onFlip: { _ in
                            // Flipping is the lesson — advance whenever it happens.
                            if step == .deal || step == .flip {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step = .toss }
                            }
                        }
                    )
                    .aspectRatio(5.0 / 3.0, contentMode: .fit)
                    .padding(.horizontal, 28)
                    // Dealt in from the bottom-right corner of the desk.
                    .offset(dealt ? dragOffset : CGSize(width: 240, height: 500))
                    .rotationEffect(.degrees(dealt ? Double(dragOffset.width) * 0.04 : 18))
                    .gesture(tossGesture, including: step == .toss ? .all : .subviews)
                } else if tossed {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.flameGradient)
                            .giltSheen()
                        Text("That's the whole loop.")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .frame(maxHeight: 260)

            Spacer(minLength: 12)

            Group {
                if step == .done {
                    ProminentActionButton {
                        onContinue()
                    } label: {
                        Text("Set My Starting Point")
                    }
                } else {
                    Button("Skip") { onContinue() }
                        .buttonStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .animation(.easeInOut(duration: 0.2), value: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .deskSurface()
        .onAppear { deal() }
    }

    private var caption: String {
        switch step {
        case .deal: return "One pack of printed cards.\nA verse a day."
        case .flip: return "This is a real card — tap it to flip it over."
        case .toss: return "Know it? Flick the card away."
        case .done: return "Reviews bring each card back right before you'd forget it."
        }
    }

    /// Deal the card in shortly after the screen settles, then invite the flip.
    private func deal() {
        guard !dealt else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            HapticEngine.medium()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { dealt = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                guard step == .deal else { return }
                withAnimation(.easeInOut(duration: 0.25)) { step = .flip }
            }
        }
    }

    private var tossGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard step == .toss else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard step == .toss else { return }
                let vx = value.predictedEndTranslation.width
                if abs(dragOffset.width) > 110 || abs(vx) > 500 {
                    let dir: CGFloat = (dragOffset.width + vx) >= 0 ? 1 : -1
                    HapticEngine.medium()
                    withAnimation(.easeIn(duration: 0.22)) {
                        dragOffset = CGSize(width: dir * 640, height: dragOffset.height - 60)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        HapticEngine.success()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            tossed = true
                            step = .done
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragOffset = .zero }
                }
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
