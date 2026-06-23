import SwiftUI

struct CardStudyView: View {

    // MARK: - State

    @StateObject private var vm:     CardStudyViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()
    @ObservedObject private var learning = LearningStore.shared

    @AppStorage("studyMode")       private var studyMode:       StudyMode = .firstLetter
    @AppStorage("isVerticalScroll") private var isVerticalScroll = false

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var shakeOffset:  CGFloat = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false
    @State private var isPeeking             = false
    /// The "Jump to current verse" pill shows its full label briefly, then collapses
    /// to just the icon so it stops dominating the corner.
    @State private var jumpExpanded          = true
    /// Raw vertical scroll offset of the read-mode list — lets the jump button track
    /// whether the cursor card is actually on screen, not just `currentIndex` (which
    /// only changes on tap, so scrolling away after a jump never brought it back).
    @State private var listScrollOffset: CGFloat = 0

    /// Live continuous scroll position (0 = top, 1 = bottom) in vertical-scroll
    /// browse mode, measured from the content's offset. Drives the fast-scroll
    /// thumb so it tracks smoothly and reaches both ends exactly.
    @State private var scrollFraction: Double = 0
    private static let vScrollSpace = "verticalScrollCards"

    @Environment(\.dismiss) private var dismiss

    /// Supplies the adjacent pack (name + verses) when the user steps past the
    /// first/last verse — enables cross-pack "Continue Learning". `nil` for
    /// ordinary single-pack study.
    let adjacentPack: ((_ currentPackName: String, _ forward: Bool) -> (name: String, verses: [Verse])?)?

    /// "Continue Learning" hook — after a verse is tested the card offers
    /// **Mark as Learnt** (the only thing that marks a verse done and advances
    /// the cursor). `nil` for ordinary single-pack study.
    let onMarkLearnt: ((Verse) -> Void)?

    // MARK: - Init

    init(packName: String, verses: [Verse], initialIndex: Int = 0,
         initialReviewMode: Bool = false,
         adjacentPack: ((_ currentPackName: String, _ forward: Bool) -> (name: String, verses: [Verse])?)? = nil,
         onMarkLearnt: ((Verse) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: CardStudyViewModel(packName: packName, verses: verses,
                                                           initialIndex: initialIndex,
                                                           initialReviewMode: initialReviewMode))
        self.adjacentPack = adjacentPack
        self.onMarkLearnt = onMarkLearnt
    }

    // MARK: - Cross-pack stepping

    private var canCrossForward:  Bool { adjacentPack?(vm.packName, true)  != nil }
    private var canCrossBackward: Bool { adjacentPack?(vm.packName, false) != nil }

    private func stepForward() {
        if vm.currentIndex >= vm.verses.count - 1, let p = adjacentPack?(vm.packName, true) {
            vm.loadPack(name: p.name, verses: p.verses, startAt: 0)
        } else {
            vm.goForward()
        }
    }
    private func stepBackward() {
        if vm.currentIndex == 0, let p = adjacentPack?(vm.packName, false) {
            vm.loadPack(name: p.name, verses: p.verses, startAt: max(0, p.verses.count - 1))
        } else {
            vm.goBackward()
        }
    }

    // MARK: - Current learning verse

    /// The current stopped verse's index *within the loaded pack*, if it lives here.
    private var currentVerseIndexInPack: Int? {
        guard let key = learning.currentKey else { return nil }
        return vm.verses.firstIndex { $0.srsKey == key }
    }

    /// Is the card on screen the current stopped verse? Gates the Mark-as-Learnt
    /// button so completing it *anywhere* lets you advance the cursor.
    private var isCurrentLearningVerse: Bool {
        guard let v = vm.currentVerse, let key = learning.currentKey else { return false }
        return v.srsKey == key
    }

    /// Offer "Mark as Learnt" in the Continue-Learning flow (explicit hook) or
    /// whenever the card on screen is the current stopped verse.
    private var offersMarkLearnt: Bool { onMarkLearnt != nil || isCurrentLearningVerse }

    /// Float the "Current verse" shortcut when this pack holds the current stopped
    /// verse, we're parked on a different card, and the keyboard isn't up.
    private var showGoToCurrent: Bool {
        guard let i = currentVerseIndexInPack else { return false }
        return i != vm.currentIndex && !isEditing
    }

    private func jumpToCurrentVerse() {
        guard let i = currentVerseIndexInPack, i != vm.currentIndex else { return }
        isScrubbing = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.currentIndex = i }
        HapticEngine.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
    }

    private func goToCurrentButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: jumpExpanded ? 12 : 15, weight: .bold))
                if jumpExpanded {
                    Text("Jump to current verse")
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, jumpExpanded ? 14 : 0)
            .padding(.vertical, jumpExpanded ? 10 : 0)
            // Collapsed form stays a 44pt circular tap target (Apple minimum).
            .frame(minWidth: jumpExpanded ? 0 : 44, minHeight: jumpExpanded ? 0 : 44)
            .background(Capsule().fill(Color.accentColor))
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("Jump to current verse")
        .transition(.scale.combined(with: .opacity))
        // Flash the full label, then shrink to the icon. `.task` restarts every time
        // the button reappears (new view identity), so it re-expands on each show and
        // auto-cancels if it's dismissed before the second is up.
        .task {
            jumpExpanded = true
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { jumpExpanded = false }
        }
    }

    /// List (vertical-scroll read) variant of the jump: just move the cursor
    /// index — the scroll view's `onChange` animates to it. No `isScrubbing`, so
    /// that scroll actually fires (it's guarded by `!isScrubbing`).
    /// List (vertical-scroll read) visibility: show the jump shortcut whenever the
    /// cursor card's centre has scrolled out of the viewport. Cards are a fixed
    /// height here, so the centre is `topPadding + index·(card+spacing) + card/2`.
    private func showJumpInList(cardHeight: CGFloat, viewportHeight: CGFloat) -> Bool {
        guard let ci = currentVerseIndexInPack, !isEditing else { return false }
        let cardCentre = 12 + CGFloat(ci) * (cardHeight + 20) + cardHeight / 2
        let onScreen = cardCentre > listScrollOffset && cardCentre < listScrollOffset + viewportHeight
        return !onScreen
    }

    /// Mark a verse complete from its read-mode card. No advance — the cursor moves
    /// to the next unlearnt verse on its own and the on-card button hides itself.
    private func markVerseComplete(_ verse: Verse) {
        if let cb = onMarkLearnt { cb(verse) } else { LearningStore.shared.markLearnt(verse) }
        HapticEngine.success()
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 2 * AppLayout.screenMargin
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar(width: geo.size.width)

                // Vertical scroll is for browsing in read mode only.
                // Review mode always shows a single focused card.
                if isVerticalScroll && !vm.isReviewMode {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    // Read mode keeps the original 5:3 card. Review mode grows the
                    // card into the otherwise-empty vertical space (capped so it
                    // stays card-shaped) — the masked underscores need the extra
                    // room — and as the flexible middle it also absorbs the keyboard
                    // inset, shrinking to fit when typing rather than overflowing.
                    GeometryReader { area in
                        let cardH = vm.isReviewMode
                            ? max(cardHeight, min(cardWidth * 0.82, area.size.height - 16))
                            : cardHeight
                        ZStack {
                            cardStack
                                .frame(width: cardWidth, height: cardH)
                            // Peek renders as an OVERLAY in every mode so the
                            // SubmitCardView (and its focused TextField) stays
                            // mounted — otherwise the keyboard dismisses — and so
                            // the reveal is identical across all study modes.
                            if vm.isReviewMode, isPeeking,
                               let verse = vm.currentVerse {
                                PeekOverlayCard(
                                    verse: verse,
                                    cardLabel: vm.cardLabel(for: verse),
                                    width: cardWidth,
                                    height: cardH,
                                    isPeeking: isPeeking
                                )
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .zIndex(100)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .bottomTrailing) {
                            if showGoToCurrent {
                                goToCurrentButton(action: jumpToCurrentVerse)
                                    // Align the trailing edge with the card (and the
                                    // app's layout margin) instead of the screen edge.
                                    .padding(.trailing, AppLayout.screenMargin)
                                    .padding(.bottom, 12)
                                    .zIndex(200)
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showGoToCurrent)
                    }
                }

                if (!isVerticalScroll || vm.isReviewMode),
                   vm.verses.count > 1 || canCrossBackward || canCrossForward {
                    scrubberRow
                        .padding(.horizontal, AppLayout.screenMargin)
                        .padding(.bottom, 6)
                }

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: vm.isReviewMode) { _, reviewing in handleReviewModeChange(reviewing) }
        .onChange(of: vm.currentIndex) { _, _ in
            vm.clearInputs()
            if speech.isListening { speech.stopListening() }
            if isScrubbing {
                if submitFocus != nil { submitFocus = .title }
            } else {
                refocusIfNeeded()
            }
        }
        .onChange(of: speech.transcript) { _, text in
            guard speech.isListening else { return }
            switch speechTarget {
            case .title: vm.titleInput = text
            case .verse: vm.verseInput = text
            }
        }
        .onChange(of: submitFocus) { _, newFocus in
            guard speech.isListening, let newFocus else { return }
            speech.stopListening()
            speechTarget = newFocus
            speech.startListening()
        }
    }

    // MARK: - Top Bar

    private func topBar(width: CGFloat) -> some View {
        ZStack {
            // Centred title, width-capped so a long pack name truncates with an
            // ellipsis instead of sliding under the trailing buttons.
            VStack(spacing: 2) {
                Text(vm.packName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                // Hide position counter in vertical-scroll read mode (it's meaningless there)
                if !isVerticalScroll || vm.isReviewMode {
                    Text("\(vm.currentIndex + 1) of \(vm.verses.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: max(120, width - 220))

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }
                .accessibilityLabel("Close")

                Spacer()

                // While typing, the trailing controls become a guaranteed-visible
                // "Done" to dismiss the keyboard (the keyboard's own toolbar item
                // is unreliable this deep in the card stack). Otherwise: shuffle + view.
                if isEditing {
                    Button {
                        isInputFocused = false
                        submitFocus = nil
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("Close keyboard")
                } else {
                    HStack(spacing: 8) {
                        Button {
                            vm.toggleShuffle()
                            HapticEngine.light()
                        } label: {
                            Image(systemName: "shuffle")
                                .studyChromeToggle(isOn: vm.isShuffled)
                        }
                        .accessibilityLabel("Shuffle")
                        .accessibilityValue(vm.isShuffled ? "On" : "Off")
                        // The list/single-card toggle only matters in Read mode —
                        // Review always shows one focused card — so hide it there.
                        if !vm.isReviewMode {
                            Button {
                                isVerticalScroll.toggle()
                            } label: {
                                Image(systemName: isVerticalScroll ? "rectangle.stack" : "list.bullet.rectangle")
                                    .studyChromeToggle(isOn: isVerticalScroll)
                            }
                            .accessibilityLabel(isVerticalScroll ? "Switch to single card" : "Switch to list view")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.18), value: isEditing)
    }

    /// True whenever either text input has keyboard focus.
    private var isEditing: Bool { isInputFocused || submitFocus != nil }

    // MARK: - Card Stack (horizontal swipe mode)

    private var cardStack: some View {
        ZStack {
            if vm.currentIndex + 2 < vm.verses.count {
                backgroundCard(at: vm.currentIndex + 2)
                    .scaleEffect(0.90).offset(y: 24).zIndex(0)
            }
            if vm.currentIndex + 1 < vm.verses.count {
                backgroundCard(at: vm.currentIndex + 1)
                    .scaleEffect(0.95 + 0.05 * forwardDragProgress)
                    .offset(y: 12 * (1 - forwardDragProgress))
                    .zIndex(1)
            }
            if let verse = vm.currentVerse {
                let goingBack = dragOffset.width > 0
                // Peek is rendered as an overlay in `body` (consistent across
                // all modes); the underlying card never swaps for peek.
                makeCard(verse: verse, verseIndex: vm.currentIndex, interactive: true, isPeeking: false)
                    .offset(x: goingBack ? 0 : dragOffset.width,
                            y: goingBack ? backwardDragProgress * 12 : dragOffset.height * 0.1)
                    .scaleEffect(goingBack ? 1.0 - backwardDragProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                    // `simultaneousGesture` lets TextField taps and TextEditor cursor/selection still fire;
                    // the gesture itself filters out predominantly-vertical drags so editor scroll keeps working.
                    .simultaneousGesture(swipeGesture)
            }
            if vm.currentIndex > 0 && dragOffset.width > 0 {
                makeCard(verse: vm.verses[vm.currentIndex - 1], verseIndex: vm.currentIndex - 1, interactive: false)
                    .offset(x: dragOffset.width - CardSwipeConfig.prevCardOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width - CardSwipeConfig.prevCardOffset) * 0.02))
                    .allowsHitTesting(false)
                    .zIndex(3)
            }
        }
    }

    // MARK: - Vertical Scroll Mode

    private func verticalScrollCards(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                                makeCard(verse: verse, verseIndex: index, interactive: index == vm.currentIndex)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(index)
                                    .overlay {
                                        // Skip the focus-tap on the cursor card so its
                                        // on-card "Mark as Complete" button stays tappable.
                                        if index != vm.currentIndex, !learning.isCurrent(verse) {
                                            Color.clear.contentShape(Rectangle())
                                                .onTapGesture {
                                                    HapticEngine.light()
                                                    vm.currentIndex = index
                                                }
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        // Continuous offset probe on the (always-present) content
                        // background — 0 at top, grows scrolling down. Reliable,
                        // unlike index-snapping which sticks one card from each end.
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: VScrollMetricsKey.self,
                                    value: VScrollMetrics(offset: -g.frame(in: .named(Self.vScrollSpace)).minY,
                                                          contentHeight: g.size.height))
                            }
                        )
                    }
                    .coordinateSpace(name: Self.vScrollSpace)
                    .onPreferenceChange(VScrollMetricsKey.self) { m in
                        let maxScroll = max(1, m.contentHeight - outerGeo.size.height)
                        let f = Double(min(max(m.offset / maxScroll, 0), 1))
                        if abs(f - scrollFraction) > 0.0001 { scrollFraction = f }
                        if abs(listScrollOffset - m.offset) > 0.5 { listScrollOffset = m.offset }
                    }

                    if vm.verses.count >= 2 {
                        VerseFastScrollOverlay(
                            verseCount: vm.verses.count,
                            scrollFraction: scrollFraction,
                            containerHeight: outerGeo.size.height,
                            isScrubbing: $isScrubbing,
                            titleProvider: { idx in
                                vm.verses.indices.contains(idx) ? vm.verses[idx].title : ""
                            },
                            referenceProvider: { idx in
                                guard vm.verses.indices.contains(idx) else { return "" }
                                let v = vm.verses[idx]
                                return "\(v.book) \(v.reference)"
                            },
                            onScrubTo: { newIndex in
                                // Jump the list immediately (no animation — 1:1 drag feel)
                                // and update currentIndex so switching to review opens it.
                                var t = Transaction(); t.disablesAnimations = true
                                withTransaction(t) { proxy.scrollTo(newIndex, anchor: .center) }
                                if vm.currentIndex != newIndex { vm.currentIndex = newIndex }
                            }
                        )
                    }
                }
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .milliseconds(60))
                        proxy.scrollTo(vm.currentIndex, anchor: .center)
                    }
                }
                .onChange(of: vm.currentIndex) { _, newIndex in
                    // Tap-on-card or external nav — keep scroll position in sync.
                    // Thumb drag sets isScrubbing, so skip to avoid a duplicate scroll.
                    guard !isScrubbing else { return }
                    withAnimation(.easeInOut(duration: 0.22)) { proxy.scrollTo(newIndex, anchor: .center) }
                }
                // Bottom-trailing to match the single-card view (aligned to the layout
                // margin). Visibility tracks the cursor card's scroll position, so the
                // button returns after you scroll away from a jump.
                .overlay(alignment: .bottomTrailing) {
                    if showJumpInList(cardHeight: cardHeight, viewportHeight: outerGeo.size.height) {
                        goToCurrentButton(action: {
                            // Scroll via the proxy directly (not by mutating currentIndex)
                            // so a re-jump still works when currentIndex is already the
                            // cursor from a previous jump.
                            guard let i = currentVerseIndexInPack else { return }
                            HapticEngine.light()
                            isScrubbing = true
                            if vm.currentIndex != i { vm.currentIndex = i }
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(i, anchor: .center) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
                        })
                        .padding(.trailing, AppLayout.screenMargin)
                        .padding(.bottom, 12)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8),
                           value: showJumpInList(cardHeight: cardHeight, viewportHeight: outerGeo.size.height))
            }
        }
    }

    // MARK: - Card Builders

    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        if vm.verses.indices.contains(index) {
            makeCard(verse: vm.verses[index], verseIndex: index, interactive: false)
        }
    }

    @ViewBuilder
    private func makeCard(verse: Verse, verseIndex: Int, interactive: Bool, isPeeking: Bool = false) -> some View {
        let hasResult = vm.submitResults[verse.id] != nil
        let isBehind = verseIndex < vm.currentIndex
        let isAhead = verseIndex > vm.currentIndex
        let isDirectNext = verseIndex == vm.currentIndex + 1
        let isDirectPrev = verseIndex == vm.currentIndex - 1

        // NOTE: deliberately does NOT include `!isPeeking`. Peek must NOT
        // swap the SubmitCardView out — that would destroy the focused
        // TextField and dismiss the keyboard. Peek is rendered as an overlay
        // in `body` instead. See bug fix above.
        let showSubmitSurface = studyMode == .submit && vm.isReviewMode
            && (interactive || (isDirectNext && !hasResult) || (isDirectPrev && !hasResult))

        if showSubmitSurface {
            SubmitCardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                titleText: interactive ? $vm.titleInput : .constant(""),
                verseText: interactive ? $vm.verseInput : .constant(""),
                result: interactive ? vm.submitResults[verse.id] : nil,
                focusedField: $submitFocus,
                isCurrentLearning: learning.isCurrent(verse)
            )
            .allowsHitTesting(interactive)
        } else {
            // Submit + Review stack: never read mode behind the front card while peeking (full verse).
            let forceMaskedPeek = studyMode == .submit && vm.isReviewMode && !interactive
                && ((isAhead && (!isDirectNext || hasResult)) || isBehind)
            let titleRev = isPeeking ? verse.titleWords.count
                : (forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .title))
            let verseRev = isPeeking ? verse.verseWords.count
                : (forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .verse))
            FlashcardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                isReviewMode: isPeeking ? false : (forceMaskedPeek ? true : vm.isReviewMode),
                titleRevealedCount: titleRev,
                verseRevealedCount: verseRev,
                activeSection: vm.activeSection,
                onSectionTap: interactive && vm.isReviewMode && !isPeeking ? { section in
                    vm.activeSection = section
                    DispatchQueue.main.async { focusInput() }
                } : nil,
                isCurrentLearning: learning.isCurrent(verse),
                onMarkComplete: vm.isReviewMode ? nil : { markVerseComplete(verse) }
            )
        }
    }

    // MARK: - Scrubber

    private var scrubberRow: some View {
        VerseScrubberRow(
            verseCount: vm.verses.count,
            currentIndex: $vm.currentIndex,
            isScrubbing: $isScrubbing,
            showPositionLabel: false,
            trackHeight: 44,
            onScrubIndexChange: nil,
            canStepBeyondStart: canCrossBackward,
            canStepBeyondEnd: canCrossForward,
            onStepBack: {
                isScrubbing = true
                stepBackward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            },
            onStepForward: {
                isScrubbing = true
                stepForward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            }
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 6) {
            if vm.isReviewMode {
                cardControlBand
            }

            if !isInputFocused && submitFocus == nil {
                Picker("Mode", selection: $vm.isReviewMode) {
                    Text("Read").tag(false)
                    Text("Review").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.bottom, 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isReviewMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isCardComplete)
    }

    /// Active-card controls with the always-present hold-to-peek button anchored
    /// to the leading edge so it stays put regardless of which controls show.
    private var cardControlBand: some View {
        HStack(alignment: .center, spacing: StudyControlMetrics.rowSpacing) {
            // Peeking only makes sense while the verse is still hidden — once the
            // card is answered (revealed, or submitted right or wrong) the text is
            // already on the card, so drop the button.
            if !vm.isCardAnswered {
                PeekHoldButton(isPeeking: $isPeeking)
                    .transition(.opacity)
            }
            Group {
                if vm.isCardComplete {
                    if offersMarkLearnt {
                        HStack(spacing: 10) {
                            tryAgainButton
                            markLearntButton
                        }
                    } else {
                        completeLabel
                    }
                } else if studyMode == .submit {
                    submitControls
                } else {
                    inputField
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var completeLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green).font(.system(size: 22))
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("Complete!")
                .font(.system(size: 17, weight: .semibold)).foregroundColor(.green)
        }
        .frame(maxWidth: .infinity)
        .transition(.scale.combined(with: .opacity))
    }

    /// "Continue Learning" only: the single action that marks a verse done. Marks
    /// the current verse learnt and advances to the next (crossing packs at a
    /// boundary). Streak/test progress is handled separately on submit.
    private var markLearntButton: some View {
        Button {
            if let v = vm.currentVerse {
                if let cb = onMarkLearnt { cb(v) } else { LearningStore.shared.markLearnt(v) }
            }
            HapticEngine.success()
            isScrubbing = true
            stepForward()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
        } label: {
            Label("Mark as Complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.green)
                .roundedRect(12)
        }
        .accessibilityLabel("Mark verse as complete and continue")
    }

    /// Resets the current card so the user can attempt it again (clears revealed
    /// words / submitted answer for whichever study mode is active).
    private var tryAgainButton: some View {
        Button { vm.resetCurrentCard() } label: {
            Label("Try Again", systemImage: "arrow.counterclockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(12)
        }
    }

    /// Submit mode: mic + submit button before scoring, try-again after.
    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        return Group {
            if hasResult {
                HStack(spacing: 10) {
                    Button { vm.retrySubmit() } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .roundedRect(12)
                    }
                    if offersMarkLearnt { markLearntButton }
                }
            } else {
                HStack(spacing: 10) {
                    Button { toggleSpeech() } label: {
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(speech.isListening ? .white : .primary)
                            .frame(width: 48, height: 48)
                            .background(speech.isListening ? Color.red : Color(.secondarySystemGroupedBackground))
                            .roundedRect(12)
                    }
                    .accessibilityLabel(speech.isListening ? "Stop dictation" : "Dictate verse")
                    let isEmpty = vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                              && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                    Button {
                        if speech.isListening { speech.stopListening() }
                        let result = vm.handleSubmit()
                        submitFocus = nil
                        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(isEmpty ? Color(.systemGray3) : Color.accentColor)
                            .roundedRect(12)
                    }
                    .disabled(isEmpty)
                }
            }
        }
    }

    /// First-letter and full-word modes share this single text field.
    private var inputField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundColor(.secondary).font(.system(size: 16))

                TextField(studyMode.inputPlaceholder, text: $vm.inputText)
                    .font(.system(size: 17))
                    .focused($isInputFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.inputText) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        switch studyMode {
                        case .firstLetter:
                            let correct = vm.processFirstLetterInput(newValue)
                            DispatchQueue.main.async { vm.inputText = "" }
                            if correct { HapticEngine.light() } else { HapticEngine.error(); triggerShake($shakeOffset) }
                        case .fullWord:
                            if vm.processFullWordInput(newValue) {
                                HapticEngine.light()
                            } else if newValue.hasSuffix(" ") {
                                HapticEngine.error(); triggerShake($shakeOffset)
                            }
                        case .submit:
                            break
                        }
                    }
                    // Keyboard dismissal lives in the top bar ("Done") — a single,
                    // reliable affordance instead of a second keyboard-toolbar one.
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .roundedRect(12)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)
        }
    }

    // MARK: - Swipe Gesture

    private var forwardDragProgress: CGFloat {
        CardSwipeConfig.forwardDragProgress(dragWidth: dragOffset.width)
    }

    private var backwardDragProgress: CGFloat {
        CardSwipeConfig.backwardDragProgress(dragWidth: dragOffset.width)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Skip predominantly-vertical drags so TextEditor scroll/selection in submit mode survives.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if isCardFlying { commitSwipe() }
                let canNext = vm.currentIndex < vm.verses.count - 1
                let canPrev = vm.currentIndex > 0
                dragOffset = CardSwipeConfig.clampedDragTranslation(
                    value.translation,
                    canGoNext: canNext,
                    canGoPrev: canPrev
                )
            }
            .onEnded { value in
                if isCardFlying { commitSwipe() }
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                let vx = value.predictedEndTranslation.width
                if isHorizontal,
                   (dragOffset.width < -CardSwipeConfig.threshold || vx < -CardSwipeConfig.velocityThreshold),
                   vm.currentIndex < vm.verses.count - 1 {
                    swipeForward()
                } else if isHorizontal,
                          (dragOffset.width > CardSwipeConfig.threshold || vx > CardSwipeConfig.velocityThreshold),
                          vm.currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { dragOffset = .zero }
                    // Drag started (dismissing keyboard) but wasn't committed — restore focus.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { refocusIfNeeded() }
                }
            }
    }

    private func swipeForward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = -1
        HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: -CardSwipeConfig.flyWidth, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func swipeBackward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = 1
        HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: CardSwipeConfig.prevCardOffset, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func commitSwipe() {
        guard isCardFlying else { return }
        isPeeking = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            if flyDirection < 0 {
                stepForward()
            } else if flyDirection > 0 {
                stepBackward()
            }
            dragOffset = .zero
            isCardFlying = false
            flyDirection = 0
        }
        // Refocus immediately so the keyboard comes back before its dismiss animation finishes.
        if vm.isReviewMode && !vm.isCardComplete { focusInput() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
    }

    // MARK: - Focus & Speech

    private func handleReviewModeChange(_ reviewing: Bool) {
        if reviewing && !vm.isCardComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusInput() }
        } else {
            if speech.isListening { speech.stopListening() }
            isInputFocused = false
            submitFocus    = nil
        }
    }

    private func refocusIfNeeded() {
        guard vm.isReviewMode && !vm.isCardComplete else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusInput() }
    }

    private func focusInput() {
        studyMode == .submit ? (submitFocus = .title) : (isInputFocused = true)
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
            speech.startListening()
        }
    }

}

#Preview {
    CardStudyView(packName: "5 Assurances", verses: Array(packsNIV84.first?.verses.prefix(5) ?? []))
}
