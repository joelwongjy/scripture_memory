import SwiftUI

/// Quiz's "Jump to Verse" list: every verse in the session, the current one ticked.
struct VerseJumpSheet: View {
    let verses: [Verse]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(verses.enumerated()), id: \.offset) { i, verse in
                    Button {
                        onSelect(i)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(verse.book) \(verse.reference)")
                                .font(.system(size: 16))
                                .foregroundStyle(i == currentIndex ? Color.accentColor : Color.primary)
                            Spacer()
                            if i == currentIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Jump to Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
