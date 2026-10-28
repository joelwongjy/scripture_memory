import SwiftUI

// MARK: - Pin Verse Picker

/// A lightweight pack → verse drill-down for choosing which verse to pin to Home.
/// Tapping a verse pins it immediately and dismisses — no progress is changed.
struct PinVersePicker: View {
    let packs:     [Pack]
    var pinnedKey: String?
    var onPick:    (Verse) -> Void
    var onUnpin:   () -> Void
    @Environment(\.dismiss) private var dismiss

    private var pinned: Verse? {
        guard let pinnedKey else { return nil }
        return packs.lazy.flatMap(\.verses).first { $0.srsKey == pinnedKey }
    }

    var body: some View {
        NavigationStack {
            List {
                if let pinned {
                    Section {
                        Button {
                            onUnpin()
                            HapticEngine.light()
                            dismiss()
                        } label: {
                            Label("Unpin \(pinned.book) \(pinned.reference)", systemImage: "pin.slash")
                        }
                    }
                }
                PackVersePicker(packs: packs, selectedKey: pinnedKey, marker: .pin,
                                footer: "Pick a verse to feature on your Home screen and widget. This doesn't change your learning progress.") { verse in
                    onPick(verse)
                    dismiss()
                }
            }
            .navigationTitle("Pin a Verse")
            .analyticsScreen(.pinPicker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
