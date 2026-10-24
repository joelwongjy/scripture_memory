import SwiftUI

// MARK: - Starting-point picker (pack list → exact verse)

struct StartingPointScreen: View {
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

            // The first verse is represented by "Start from the beginning" above
            // (which carries its own check), so a pack is only badged for a
            // specific, non-first verse — otherwise both would show a check.
            PackVersePicker(packs: packs,
                            selectedKey: pending?.srsKey == ordered.first?.srsKey ? nil : pending?.srsKey,
                            header: "Pick where you stopped") { pending = $0 }
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
        BottomActionBar {
            PrimaryActionButton(title: "Confirm", isEnabled: pending != nil) {
                guard let pending else { return }
                HapticEngine.light()
                onPick(pending)
            }
        }
    }

    private func isSelected(_ verse: Verse?) -> Bool {
        guard let verse, let pending else { return false }
        return verse.srsKey == pending.srsKey
    }

    private var checkmark: some View { SelectionCheckmark() }
}
