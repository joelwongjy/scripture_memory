import SwiftUI

/// Edit screen for reordering packs (drag) and hiding/showing them.
/// Presented as a sheet from the Packs grid. Changes persist immediately via
/// `PackPreferencesStore` and apply across Packs, Daily, and Review.
struct PackOrganizerView: View {
    let allPacks: [Pack]
    @ObservedObject private var store = PackPreferencesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.arranged(from: allPacks)) { pack in
                        row(pack)
                    }
                    .onMove { source, destination in
                        store.move(arranged: store.arranged(from: allPacks),
                                   from: source, to: destination)
                    }
                } header: {
                    // At the top, not a footer — users won't scroll past every pack
                    // to read an instruction at the bottom. Footnote/secondary so it
                    // reads as a caption, not a heading.
                    Text("Drag to reorder. Hidden packs are removed from Packs, Daily, and Review.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .navigationTitle("Organize Packs")
            .navigationBarTitleDisplayMode(.inline)
            // Always-on edit mode: drag handles are present immediately, so
            // reordering works without an Edit button. The per-row eye button
            // uses `.borderless`, so it still toggles in edit mode.
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { showResetConfirm = true }
                        .disabled(!store.hasCustomization)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset pack order?",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    store.reset()
                    HapticEngine.light()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Restores the original order and shows all packs.")
            }
        }
    }

    private func row(_ pack: Pack) -> some View {
        let isHidden = store.isHidden(pack.name)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill((Color(hex: pack.color) ?? .gray).muted)
                .frame(width: 36, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(pack.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("\(pack.verses.count) verses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.setHidden(pack.name, !isHidden)
                HapticEngine.light()
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 17))
                    .foregroundStyle(isHidden ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isHidden ? "Show \(pack.name)" : "Hide \(pack.name)")
        }
        .opacity(isHidden ? 0.45 : 1)
    }
}
