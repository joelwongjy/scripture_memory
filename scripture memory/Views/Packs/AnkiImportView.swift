import SwiftUI
import UniformTypeIdentifiers

struct AnkiImportView: View {
    var initialURL: URL? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .intro
    @State private var choosing = false
    @State private var decks: [AnkiImporter.DeckChoice] = []
    @State private var includeMatches = true
    @State private var showsSkipped = false

    private enum Stage {
        case intro
        case reading
        case review(AnkiImportPlan)
        case failed(String)
        case done(AnkiImportSummary)
    }

    private static let types: [UTType] = [
        UTType(filenameExtension: "apkg"), UTType(filenameExtension: "colpkg"),
        .plainText, .commaSeparatedText, .tabSeparatedText,
    ].compactMap { $0 }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import from Anki")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: Self.types) { result in
            if case .success(let url) = result { read(url) }
        }
        .task {
            if let initialURL { read(initialURL) }
        }
        .interactiveDismissDisabled(isReviewing)
    }

    private var isReviewing: Bool {
        if case .review = stage { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .intro:
            intro
        case .reading:
            ProgressView("Reading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        case .review(let plan):
            review(plan)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t Read This File", systemImage: "doc.questionmark")
            } description: {
                Text(message)
            } actions: {
                Button("Choose Another File") { choosing = true }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
            .background(Color(.systemGroupedBackground))
        case .done(let summary):
            done(summary)
        }
    }

    private var intro: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("Bring Your Deck")
                        .font(.title2.weight(.bold))
                    Text("Your review history comes too.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                Label("Choose your deck, then Export.", systemImage: "1.circle")
                Label("Pick Anki Deck Package, with scheduling.", systemImage: "2.circle")
                Label("Save to Files, then choose it below.", systemImage: "3.circle")
            } header: {
                Text("Export from Anki")
            } footer: {
                Text("Works with AnkiMobile, AnkiDroid and desktop Anki.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                choosing = true
            } label: {
                Text("Choose File")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.bottom, 8)
        }
    }

    private func review(_ plan: AnkiImportPlan) -> some View {
        List {
            ForEach(Array(plan.decks.enumerated()), id: \.offset) { i, deck in
                if i < decks.count { deckSection(deck, choice: $decks[i]) }
            }
            if !plan.matches.isEmpty {
                Section {
                    Toggle("Keep Anki Progress", isOn: $includeMatches)
                } header: {
                    Text(plan.matches.count == 1 ? "1 verse already in the app"
                                                 : "\(plan.matches.count) verses already in the app")
                } footer: {
                    Text("They’re TMS or DEP cards, so they won’t be added twice.")
                }
            }
            if !plan.skipped.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showsSkipped) {
                        ForEach(Array(plan.skipped.prefix(50).enumerated()), id: \.offset) { _, front in
                            Text(front.isEmpty ? "Empty note" : front)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    } label: {
                        Text(plan.skipped.count == 1 ? "1 note has no reference"
                                                     : "\(plan.skipped.count) notes have no reference")
                    }
                }
            }
        }
    }

    private func deckSection(_ deck: AnkiImportPlan.Deck, choice: Binding<AnkiImporter.DeckChoice>) -> some View {
        let withProgress = deck.verses.filter(\.hasProgress).count
        return Section {
            Toggle("Import as Pack", isOn: choice.include)
            if choice.wrappedValue.include {
                LabeledContent("Pack Name") {
                    TextField("Pack Name", text: choice.name, prompt: Text(UserPack.defaultName))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.tint)
                        .textInputAutocapitalization(.words)
                }
                if let first = deck.verses.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.reference.display)
                        Text(first.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text(deck.name)
        } footer: {
            Text(deck.verses.count == 1 ? "1 verse" : "\(deck.verses.count) verses")
                + Text(withProgress > 0 ? " · \(withProgress) with history" : "")
        }
    }

    private func done(_ summary: AnkiImportSummary) -> some View {
        List {
            Section {
                if summary.versesAdded > 0 {
                    LabeledContent("Verses added", value: "\(summary.versesAdded)")
                    LabeledContent(summary.packsCreated == 1 ? "New pack" : "New packs", value: "\(summary.packsCreated)")
                }
                if summary.matchedBundled > 0 {
                    LabeledContent("TMS & DEP cards updated", value: "\(summary.matchedBundled)")
                }
                LabeledContent("History kept", value: "\(summary.progressCarried)")
            } footer: {
                Text("Known cards come up in Daily Review when due.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        switch stage {
        case .review(let plan):
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Import") { apply(plan) }
                    .disabled(!decks.contains(where: \.include) && !(includeMatches && !plan.matches.isEmpty))
            }
        case .done:
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        default:
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func read(_ url: URL) {
        stage = .reading
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try AnkiImport.read(url: url) }
            }.value
            switch result {
            case .success(let source):
                let plan = AnkiImporter.plan(for: source)
                guard !plan.decks.isEmpty || !plan.matches.isEmpty else {
                    stage = .failed("No notes have a reference like Romans 8:28.")
                    return
                }
                decks = plan.decks.map { .init(include: true, name: $0.name) }
                stage = .review(plan)
            case .failure(let error):
                stage = .failed(message(for: error))
            }
        }
    }

    private func message(for error: Error) -> String {
        switch error as? AnkiImportError {
        case .unsupported:
            return "Export it again as an Anki Deck Package (.apkg)."
        case .empty:
            return "This deck is empty."
        default:
            return "Export it again as an Anki Deck Package (.apkg)."
        }
    }

    private func apply(_ plan: AnkiImportPlan) {
        let summary = AnkiImporter.apply(plan, decks: decks, includeMatches: includeMatches)
        Analytics.log(.ankiImported(verses: summary.versesAdded, withHistory: summary.progressCarried,
                                    matched: summary.matchedBundled))
        HapticEngine.success()
        stage = .done(summary)
    }
}
