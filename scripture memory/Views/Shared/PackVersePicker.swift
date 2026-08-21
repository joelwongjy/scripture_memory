import SwiftUI

/// A pack → verse drill-down for choosing **one** verse.
///
/// Drop it in a `List` inside a `NavigationStack`: it renders a section of
/// pack rows, each pushing that pack's verses. The pack holding the chosen
/// verse shows that verse's reference and the marker next to its name, and the
/// verse itself shows the marker in its row. Picking a verse calls `onSelect`
/// and pops back.
///
/// Used by the starting-point picker (marker: checkmark, confirmed later) and
/// the pin picker (marker: pin, applied immediately). They used to be two
/// copies of the same screens.
struct PackVersePicker: View {
    let packs: [Pack]
    var selectedKey: String?
    var marker: Marker = .checkmark
    /// Shown above the pack rows.
    var header: String? = nil
    var onSelect: (Verse) -> Void

    enum Marker {
        case checkmark, pin

        @ViewBuilder var view: some View {
            switch self {
            case .checkmark: SelectionCheckmark()
            case .pin:
                Image(systemName: "pin.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Pinned")
            }
        }
    }

    var body: some View {
        Section {
            ForEach(packs) { pack in
                NavigationLink {
                    VersePickList(pack: pack, selectedKey: selectedKey, marker: marker, onSelect: onSelect)
                } label: {
                    PackRowLabel(pack: pack) {
                        if let chosen = pack.verses.first(where: { $0.srsKey == selectedKey }) {
                            Text("\(chosen.book) \(chosen.reference)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                            marker.view
                        }
                    }
                }
            }
        } header: {
            if let header { Text(header) }
        }
    }
}

/// One pack's verses, one of which may be marked. Tapping selects and pops.
private struct VersePickList: View {
    let pack: Pack
    var selectedKey: String?
    var marker: PackVersePicker.Marker
    var onSelect: (Verse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(pack.verses) { verse in
                Button {
                    HapticEngine.light()
                    onSelect(verse)
                    dismiss()
                } label: {
                    VerseRowLabel(verse: verse) {
                        if verse.srsKey == selectedKey { marker.view }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(pack.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
