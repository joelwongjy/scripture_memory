import SwiftUI

struct PackEditorView: View {
    @ObservedObject private var store = UserPackStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var packID: String?
    @State private var name: String
    @State private var color: String
    @State private var verseSheet: VerseSheet?
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private let addsVerseOnOpen: Bool
    private let suggestedName: String

    private struct VerseSheet: Identifiable {
        let verse: UserVerse?
        var id: String { verse?.id ?? "new" }
    }

    init(packID: String? = nil, addsVerseOnOpen: Bool = false) {
        let existing = packID.flatMap { UserPackStore.shared.pack(id: $0) }
        _packID = State(initialValue: existing?.id)
        _name = State(initialValue: existing?.name ?? "")
        suggestedName = existing == nil ? UserPackStore.shared.availableName(UserPack.defaultName) : UserPack.defaultName
        _color = State(initialValue: existing?.color ?? UserPack.colors[0])
        self.addsVerseOnOpen = addsVerseOnOpen
    }

    private var pack: UserPack? { packID.flatMap { store.pack(id: $0) } }

    var body: some View {
        NavigationStack {
            List {
                detailsSection
                if let pack { cardsSection(pack) }
                if pack != nil {
                    Section {
                        Button("Delete Pack", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(pack == nil ? "New Pack" : "Edit Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $verseSheet) { sheet in
                if let packID { VerseEditorView(packID: packID, editing: sheet.verse) }
            }
            .confirmationDialog("Delete \(pack?.name ?? "this pack")?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete Pack", role: .destructive) {
                    if let packID { store.deletePack(id: packID) }
                    dismiss()
                }
            } message: {
                Text(pack?.verses.count == 1 ? "Deletes 1 card and its history on all your devices."
                                              : "Deletes \(pack?.verses.count ?? 0) cards and their history on all your devices.")
            }
            .onAppear {
                if pack == nil { nameFocused = true }
                if addsVerseOnOpen, pack != nil { verseSheet = VerseSheet(verse: nil) }
            }
        }
    }

    private var preview: Pack {
        Pack(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? suggestedName : name,
             color: color, accentText: "", verses: pack?.pack.verses ?? [], userPackID: packID ?? "preview")
    }

    private var detailsSection: some View {
        Section {
            VStack(spacing: 16) {
                PackCover(pack: preview)
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.62 }
                    .accessibilityHidden(true)
                    .animation(.smooth(duration: 0.24), value: color)
                TextField("Name", text: $name, prompt: Text(suggestedName))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { pack == nil ? create() : commitDetails() }
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Pack Name")
                ColorSwatches(selection: $color)
                    .onChange(of: color) { _, _ in commitDetails() }
            }
            .padding(.vertical, 8)
        } footer: {
            if pack == nil {
                Text("OYO means “On Your Own”: verses you choose yourself.")
            }
        }
    }

    private func cardsSection(_ pack: UserPack) -> some View {
        Section {
            Button {
                verseSheet = VerseSheet(verse: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                    Text("Add Verse")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            ForEach(pack.verses) { verse in
                Button {
                    verseSheet = VerseSheet(verse: verse)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(verse.book) \(verse.reference)")
                            .foregroundStyle(Color.primary)
                        if !verse.title.isEmpty {
                            Text(verse.title)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
            .onDelete { offsets in
                store.deleteVerses(Set(offsets.map { pack.verses[$0].id }), in: pack.id)
            }
            .onMove { source, destination in
                store.moveVerses(in: pack.id, from: source, to: destination)
            }
        } header: {
            HStack {
                Text("Cards")
                Spacer()
                if !pack.verses.isEmpty {
                    EditButton()
                        .font(.subheadline)
                        .textCase(nil)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if pack == nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create", action: create)
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    commitDetails()
                    dismiss()
                }
            }
        }
    }

    private func create() {
        let typed = name.trimmingCharacters(in: .whitespaces)
        let created = store.createPack(name: typed.isEmpty ? suggestedName : typed, color: color)
        Analytics.log(.ownPackCreated(from: .newPack))
        packID = created.id
        name = created.name
        nameFocused = false
        HapticEngine.success()
        verseSheet = VerseSheet(verse: nil)
    }

    private func commitDetails() {
        guard let pack else { return }
        store.updatePack(id: pack.id, name: name, color: color)
        name = store.pack(id: pack.id)?.name ?? name
    }
}

struct ColorSwatches: View {
    @Binding var selection: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 30
    @Environment(\.dynamicTypeSize) private var dynamicType

    private static let names = ["Red", "Green", "Blue", "Orange", "Purple", "Graphite"]

    private var columns: [GridItem] {
        let count = dynamicType.isAccessibilitySize ? UserPack.colors.count / 2 : UserPack.colors.count
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(UserPack.colors.enumerated()), id: \.element) { i, hex in
                Button {
                    selection = hex
                    HapticEngine.light()
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: size, height: size)
                        .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTapSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.names[i])
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
    }
}
