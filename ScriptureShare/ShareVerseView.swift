import SwiftUI

struct ShareVerseView: View {
    let packs: [SharedPackChoice]
    let onCancel: () -> Void
    let onAdd: (SharedVerseDraft) -> Void

    @State private var referenceText: String
    @State private var translation: String
    @State private var text: String
    @State private var title = ""
    @State private var packID: String
    @FocusState private var referenceFocused: Bool

    private static let newPackID = "new"

    init(pasted: PastedVerse, packs: [SharedPackChoice], onCancel: @escaping () -> Void,
         onAdd: @escaping (SharedVerseDraft) -> Void) {
        self.packs = packs
        self.onCancel = onCancel
        self.onAdd = onAdd
        _referenceText = State(initialValue: pasted.reference?.display ?? "")
        _translation = State(initialValue: pasted.version
            ?? SharedVerseInbox.lastTranslation ?? VerseTranslation.niv)
        _text = State(initialValue: pasted.text)
        let last = SharedVerseInbox.lastPackID
        _packID = State(initialValue: packs.first { $0.id == last }?.id ?? packs.first?.id ?? Self.newPackID)
    }

    private var reference: BibleReference? { BibleReference.parse(referenceText) }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var translationChoices: [String] {
        VerseTranslation.choices.contains(translation) ? VerseTranslation.choices
                                                       : VerseTranslation.choices + [translation]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reference", text: $referenceText, prompt: Text("Reference, like Rom 8:28"))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($referenceFocused)
                    TextField("Title", text: $title, prompt: Text("Title (optional)"))
                        .textInputAutocapitalization(.words)
                    Picker("Translation", selection: $translation) {
                        ForEach(translationChoices, id: \.self) { code in
                            Text(VerseTranslation.displayName(code)).tag(code)
                        }
                    }
                } footer: {
                    if reference == nil {
                        Text("Try “Rom 8:28”")
                    }
                }
                Section("Verse") {
                    TextField("Verse", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    Picker("Pack", selection: $packID) {
                        ForEach(packs) { pack in
                            Text(pack.name).tag(pack.id)
                        }
                        Text(packs.isEmpty ? "New Pack “OYO”" : "New Pack").tag(Self.newPackID)
                    }
                } footer: {
                    Text("Appears when you next open Scripture Memory.")
                }
            }
            .onAppear { if referenceText.isEmpty { referenceFocused = true } }
            .navigationTitle("Add Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(reference == nil || trimmedText.isEmpty)
                }
            }
        }
    }

    private func add() {
        guard let reference else { return }
        let isNew = packID == Self.newPackID
        SharedVerseInbox.lastTranslation = translation
        if !isNew { SharedVerseInbox.lastPackID = packID }
        onAdd(SharedVerseDraft(packID: isNew ? nil : packID, newPackName: isNew ? "OYO" : nil,
                               title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                               text: trimmedText, book: reference.book.name,
                               reference: reference.reference, version: translation))
    }
}
