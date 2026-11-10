import SwiftUI

struct VerseEditorView: View {
    let packID: String
    let editing: UserVerse?
    let draft: PastedVerse?

    @ObservedObject private var store = UserPackStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("userVerse.lastTranslation.v1") private var lastTranslation = VerseTranslation.niv

    @State private var referenceText = ""
    @State private var translation = VerseTranslation.niv
    @State private var text = ""
    @State private var title = ""
    @State private var autofilled: VerseLookupResult?
    @State private var added: [String] = []
    @State private var pastedText: String?
    @State private var confirmDelete = false
    @FocusState private var focus: Field?
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var fieldAlignment: TextAlignment { dynamicType.isAccessibilitySize ? .leading : .trailing }

    private enum Field { case reference, text, title }

    init(packID: String, editing: UserVerse? = nil, draft: PastedVerse? = nil) {
        self.packID = packID
        self.editing = editing
        self.draft = draft
    }

    private var reference: BibleReference? { BibleReference.parse(referenceText) }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool { reference != nil && !trimmedText.isEmpty }

    private var translationChoices: [String] {
        VerseTranslation.choices.contains(translation) ? VerseTranslation.choices
                                                       : VerseTranslation.choices + [translation]
    }

    private var duplicate: Bool {
        guard let reference, let pack = store.pack(id: packID) else { return false }
        let wanted = SRSKey.normalizedReference(reference.reference)
        return pack.verses.contains {
            $0.id != editing?.id && $0.book == reference.book.name
                && SRSKey.normalizedReference($0.reference) == wanted
        }
    }

    private var bookSuggestions: [BibleBook] {
        guard reference == nil, focus == .reference,
              !referenceText.contains(where: \.isNumber) || referenceText.first?.isNumber == true,
              referenceText.filter(\.isNumber).count <= 1 else { return [] }
        return BibleBooks.matching(prefix: referenceText)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                verseSection
                Section {
                    LabeledContent("Title") {
                        TextField("Title", text: $title, prompt: Text("Optional"))
                            .multilineTextAlignment(fieldAlignment)
                            .focused($focus, equals: .title)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                    }
                }
                if editing != nil {
                    Section {
                        Button("Delete Verse", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editing == nil ? "Add Verse" : "Edit Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog("Delete Verse?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Verse", role: .destructive) {
                    if let editing { store.deleteVerses([editing.id], in: packID) }
                    dismiss()
                }
            } message: {
                Text("Its review history is deleted too.")
            }
            .onAppear(perform: start)
            .onChange(of: referenceText) { _, _ in autofill() }
            .onChange(of: text) { old, new in
                if new.count == old.count + 1, new.filter({ $0 == "\n" }).count > old.filter({ $0 == "\n" }).count {
                    text = old
                    focus = nil
                } else if new.count > old.count + 1, PastedVerse.share(in: new) != nil {
                    DispatchQueue.main.async { applyPaste(new) }
                }
            }
            .onChange(of: translation) { _, _ in autofill() }
        }
    }

    private var detailsSection: some View {
        Section {
            LabeledContent("Reference") {
                TextField("Reference", text: $referenceText, prompt: Text("Rom 8:28"))
                    .multilineTextAlignment(fieldAlignment)
                    .focused($focus, equals: .reference)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = trimmedText.isEmpty ? .text : .title }
            }
            if !bookSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bookSuggestions, id: \.usfm) { book in
                            Button(book.name) { referenceText = book.name + " " }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                        }
                    }
                }
            }
            Picker("Translation", selection: $translation) {
                ForEach(translationChoices, id: \.self) { code in
                    Text(VerseTranslation.displayName(code)).tag(code)
                }
            }
        } footer: {
            referenceFooter
        }
    }

    private var typedIsCanonical: Bool {
        guard let reference else { return false }
        return referenceText.trimmingCharacters(in: .whitespaces) == reference.display
    }

    @ViewBuilder
    private var referenceFooter: some View {
        if olderNIVHasIt, !duplicate {
            Button("Fill in the app’s \(VerseTranslation.displayName(VerseTranslation.niv84)) text") {
                translation = VerseTranslation.niv84
            }
            .font(.footnote.weight(.semibold))
        } else if let reference {
            if duplicate {
                Label("Already in this pack", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if !typedIsCanonical {
                Label(reference.display, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else if !added.isEmpty && referenceText.isEmpty {
            Text("Added \(added.last ?? "")")
        } else if !referenceText.isEmpty {
            Text("Try “Rom 8:28”")
        }
    }

    private var olderNIVHasIt: Bool {
        guard let reference, translation == VerseTranslation.niv, trimmedText.isEmpty else { return false }
        return VerseLookup.bundled(reference, translation: VerseTranslation.niv84) != nil
    }

    private var bibleAppURL: URL? {
        guard let reference else { return nil }
        return VerseTranslation.bibleAppURL(for: reference, translation: translation)
    }

    private var verseSection: some View {
        Section {
            TextField("Verse", text: $text, prompt: Text("Type or paste the verse"), axis: .vertical)
                .focused($focus, equals: .text)
                .submitLabel(.done)
                .lineLimit(4...14)
            (dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12))
                                             : AnyLayout(HStackLayout(spacing: 12))) {
                Button {
                    if let bibleAppURL { openURL(bibleAppURL) }
                } label: {
                    Label("Open in Bible", systemImage: "book")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(bibleAppURL == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                }
                .buttonStyle(.bordered)
                .disabled(bibleAppURL == nil)
                .accessibilityLabel(reference.map { "Find \($0.display) in the Bible app" } ?? "Find in the Bible app")
                PasteButton(payloadType: String.self) { strings in
                    guard let first = strings.first else { return }
                    Task { @MainActor in applyPaste(first) }
                }
                .labelStyle(.titleAndIcon)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
        } header: {
            Text("Verse")
        } footer: {
            if autofilled != nil, autofilled?.text == text {
                Text("From the app’s \(VerseTranslation.displayName(translation)) text")
            } else {
                Text("Copy it in your Bible app, then tap Paste.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(editing == nil && !added.isEmpty ? "Done" : "Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(editing == nil ? "Add" : "Save", action: save)
                .disabled(!canSave)
        }
    }

    private func start() {
        if let editing {
            referenceText = "\(editing.book) \(editing.reference)"
            text = editing.text
            title = editing.title
            translation = editing.version ?? VerseTranslation.niv
        } else if let draft {
            translation = draft.version ?? lastTranslation
            referenceText = draft.reference?.display ?? ""
            text = draft.text
            pastedText = draft.text
        } else {
            translation = lastTranslation
            focus = .reference
        }
    }

    private func autofill() {
        guard let reference else { return }
        let isUntouched = trimmedText.isEmpty || text == autofilled?.text
        guard isUntouched, let found = VerseLookup.bundled(reference, translation: translation) else {
            if isUntouched, autofilled != nil {
                text = ""
                if title == autofilled?.title { title = "" }
                autofilled = nil
            }
            return
        }
        if title.isEmpty || title == autofilled?.title { title = found.title }
        text = found.text
        autofilled = found
    }

    private func applyPaste(_ raw: String) {
        let pasted = PastedVerse.parse(raw)
        if let reference = pasted.reference { referenceText = reference.display }
        if let version = pasted.version {
            translation = version == "NIV" ? VerseTranslation.niv : version
        }
        if !pasted.text.isEmpty {
            text = pasted.text
            pastedText = pasted.text
            autofilled = nil
        }
        HapticEngine.light()
    }

    private func save() {
        guard let reference, canSave else { return }
        let verse = UserVerse(id: editing?.id ?? UserVerse.newID(),
                              title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                              text: trimmedText,
                              book: reference.book.name,
                              reference: reference.reference,
                              version: translation)
        lastTranslation = translation
        if editing != nil {
            store.updateVerse(verse, in: packID)
            dismiss()
            return
        }
        store.addVerse(verse, to: packID)
        Analytics.log(.ownVerseAdded(source: autofilled?.text == text ? .bundledText
                                     : pastedText == text ? .pasted : .typed))
        HapticEngine.success()
        added.append(reference.display)
        referenceText = ""
        text = ""
        title = ""
        autofilled = nil
        pastedText = nil
        focus = .reference
    }
}
