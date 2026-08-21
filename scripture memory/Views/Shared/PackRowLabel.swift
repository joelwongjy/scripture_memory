import SwiftUI

/// A pack named in a list: name, then how many verses it holds. The trailing
/// slot carries whatever the list is for — a chosen verse, a pin, a toggle.
struct PackRowLabel<Trailing: View>: View {
    let pack: Pack
    /// Replaces the verse count — e.g. "3 of 12 verses" while picking.
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: VerseRowLabel<EmptyView, EmptyView>.accessorySpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(detail ?? Wording.verses(pack.verses.count))
                    .font(VerseRowLabel<EmptyView, EmptyView>.titleFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
    }
}

extension PackRowLabel where Trailing == EmptyView {
    init(pack: Pack, detail: String? = nil) {
        self.init(pack: pack, detail: detail, trailing: { EmptyView() })
    }
}
