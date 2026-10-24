import SwiftUI

struct CardStudyView: View {

    // MARK: - State

    @StateObject private var vm:     CardStudyViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @AppStorage(StudyMode.storageKey) private var studyMode: StudyMode = .firstLetter

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false
    /// Set when the Read/Review toggle put us in review — see `returnsToRead`.
    @State private var enteredReviewFromList = false
    /// Verse a list tap asked review to open on, consumed by `handleReviewModeChange`.
    @State private var tappedListIndex: Int?
    @State private var isPeeking             = false
    // Read list scroll state. `currentIndex` only moves when you tap a card, so
    // "what's on screen" is tracked separately from the scroll offset.
    @State private var listScrollOffset: CGFloat = 0
    /// 0 = top, 1 = bottom. Drives the fast-scroll thumb.
    @State private var scrollFraction: Double = 0
    /// The card the position counter reports while reading.
    @State private var visibleListIndex: Int = 0
    /// Scroll target for the read list. `scrollPosition(id:)` rather than
    /// `scrollTo` because its programmatic scrolls can be interrupted by the user.
    @State private var verticalScrollTarget: Int?

    /// The jump shortcut's label is shown once per screen, shared by both placements.
    @State private var jumpLabelShown = false
    /// Pending "marked complete" undo prompt.
    @State private var undoToastState: UndoToastState?
    private static let vScrollSpace = "verticalScrollCards"

    @Environment(\.dismiss) private var dismiss

    /// Supplies the adjacent pack (name + verses) when the user steps past the
    /// first/last verse — enables cross-pack "Continue Learning". `nil` for
    /// ordinary single-pack study.
    let adjacentPack: ((_ currentPackName: String, _ forward: Bool) -> (name: String, verses: [Verse])?)?

    /// "Continue Learning" hook for what marking a verse complete does. `nil`
    /// marks it learnt directly.
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

    /// Is the card on screen the verse the learning cursor is parked on? Only that
    /// card offers "Complete" (instead of Next).
    private var isCurrentLearningVerse: Bool {
        guard let v = vm.currentVerse, let key = learning.currentKey else { return false }
        return v.srsKey == key
    }

    /// Float the "Current verse" shortcut when this pack holds the current learning
    /// verse and we're parked on a different card.
    private var showGoToCurrent: Bool {
        guard let i = currentVerseIndexInPack else { return false }
        return i != vm.currentIndex
    }

    private func jumpToCurrentVerse() {
        guard let i = currentVerseIndexInPack, i != vm.currentIndex else { return }
        HapticEngine.light()
        moveProgrammatically(refocus: false) {
            withAnimation(AppMotion.movement) { vm.currentIndex = i }
        }
    }

    /// Runs a move the user didn't make by dragging (a button, a jump, a filter).
    /// `isScrubbing` tells the `currentIndex` observers it was programmatic, until
    /// the animation settles; then the keyboard comes back if there's a card to type.
    private func moveProgrammatically(refocus: Bool = true, _ move: () -> Void) {
        isScrubbing = true
        move()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
            isScrubbing = false
            if refocus { refocusIfNeeded() }
        }
    }

    /// Sends the read list back to the first card. `scrollPosition` only scrolls on a
    /// *change* of id, so a re-entry of the same target (index 0 is a common resting
    /// place) needs the clear-then-set — otherwise a shuffle that leaves the cursor
    /// on 0 would reorder the list under a stationary scroll offset.
    private func scrollListToTop() {
        verticalScrollTarget = nil
        DispatchQueue.main.async {
            withAnimation(AppMotion.content) { verticalScrollTarget = 0 }
        }
    }

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
    ///
    /// Raises an undo toast, since it's one tap and moves the learning cursor. Undo
    /// restores only the learnt flag; it doesn't rewind navigation.
    private func markVerseComplete(_ verse: Verse) {
        if let cb = onMarkLearnt { cb(verse) } else { learning.markLearnt(verse) }
        HapticEngine.success()
        undoToastState = .markedComplete(verse, learning: learning)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 2 * AppLayout.screenMargin
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar(width: geo.size.width)

                // Read mode is a scrolling list of cards; review shows one card
                // at a time, since it's a question you answer.
                if !vm.isReviewMode {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    // Review grows the card into the free vertical space (capped so
                    // it stays card-shaped) and shrinks it again for the keyboard.
                    GeometryReader { area in
                        let cardH = max(cardHeight, min(cardWidth * 0.82, area.size.height - 16))
                        ZStack {
                            cardStack
                                .frame(width: cardWidth, height: cardH)
                            // Peek is an overlay so the card underneath (and its
                            // focused text field) stays mounted.
                            if isPeeking, let verse = vm.currentVerse {
                                PeekOverlayCard(
                                    verse: verse,
                                    cardLabel: vm.cardLabel(for: verse),
                                    width: cardWidth,
                                    height: cardH,
                                    showCardLabel: showsCardLabel
                                )
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .zIndex(100)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .bottomTrailing) {
                            if showGoToCurrent {
                                JumpToCurrentButton(startExpanded: !jumpLabelShown,
                                                    onExpandedShown: { jumpLabelShown = true },
                                                    action: jumpToCurrentVerse)
                                    // Align the trailing edge with the card (and the
                                    // app's layout margin) instead of the screen edge.
                                    .padding(.trailing, AppLayout.screenMargin)
                                    .padding(.bottom, 12)
                                    .zIndex(200)
                            }
                        }
                        .animation(AppMotion.content, value: showGoToCurrent)
                    }
                }

                // The scrubber steps between cards, which only means something on
                // the single-card review surface — the read list scrolls, and has
                // its own fast-scroll thumb.
                if vm.isReviewMode,
                   vm.verses.count > 1 || canCrossBackward || canCrossForward {
                    scrubberRow
                        .padding(.horizontal, AppLayout.screenMargin)
                        .padding(.bottom, 6)
                }

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .undoToast($undoToastState)
        .speechErrorAlert(speech)
        .onChange(of: vm.isReviewMode) { _, reviewing in handleReviewModeChange(reviewing) }
        // Un-starring the last favourite while the filter is on would leave the
        // session showing nothing at all, with the control that got you there now
        // hidden. Fall back to the whole pack instead.
        .onChange(of: favorites.keys) { _, _ in
            if vm.isFavoritesFiltered, vm.favoriteCount == 0 { vm.setFavoritesFilter(false) }
        }
        .onChange(of: vm.currentIndex) { _, _ in
            vm.clearInputs()
            vm.resetDictation()
            if speech.isListening { speech.stopListening() }
            if isScrubbing {
                if submitFocus != nil { submitFocus = .title }
            } else {
                refocusIfNeeded()
            }
        }
        .onChange(of: speech.transcript) { _, text in
            guard speech.isListening else { return }
            vm.applyDictation(text, to: speechTarget)
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
                Text(positionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .contentTransition(.numericText())
                    .animation(AppMotion.control, value: positionLabel)
            }
            .frame(maxWidth: max(120, width - 220))

            HStack {
                Button {
                    if returnsToRead {
                        HapticEngine.light()
                        withAnimation(AppMotion.content) { vm.isReviewMode = false }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: returnsToRead ? "chevron.left" : "xmark")
                        .studyChromeCircleButton()
                }
                .accessibilityLabel(returnsToRead ? "Back to reading" : "Close")

                Spacer()

                if isEditing {
                    KeyboardDoneButton(action: dismissKeyboard)
                } else {
                    HStack(spacing: 8) {
                        Button {
                            let isList = !vm.isReviewMode
                            vm.toggleShuffle(restartFromTop: isList)
                            // `currentIndex` may already be 0, in which case its
                            // onChange won't fire — drive the list to the top here.
                            if isList { scrollListToTop() }
                            HapticEngine.light()
                        } label: {
                            Image(systemName: "shuffle")
                                .studyChromeToggle(isOn: vm.isShuffled)
                        }
                        .accessibilityLabel("Shuffle")
                        .accessibilityValue(vm.isShuffled ? "On" : "Off")

                        if showsFavoritesFilter {
                            Button {
                                // Changing what's in the list shouldn't summon
                                // the keyboard, so this is a programmatic move.
                                dismissKeyboard()
                                moveProgrammatically(refocus: false) {
                                    vm.setFavoritesFilter(!vm.isFavoritesFiltered)
                                }
                                if !vm.isReviewMode { scrollListToTop() }
                                HapticEngine.light()
                            } label: {
                                Image(systemName: vm.isFavoritesFiltered ? "star.fill" : "star")
                                    .studyChromeToggle(isOn: vm.isFavoritesFiltered)
                            }
                            .accessibilityLabel("Show only favourites")
                            .accessibilityValue(vm.isFavoritesFiltered ? "On" : "Off")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 12)
        .animation(AppMotion.control, value: isEditing)
    }

    /// True whenever either text input has keyboard focus.
    private var isEditing: Bool { isInputFocused || submitFocus != nil }

    private func dismissKeyboard() {
        isInputFocused = false
        submitFocus    = nil
    }

    /// Offer the favourites filter only where it can do something: this pack has
    /// starred verses, and it isn't already *the* favourites collection (where
    /// filtering to favourites is the identity).
    private var showsFavoritesFilter: Bool {
        vm.packName != FavoritesStore.packName && vm.favoriteCount > 0
    }

    /// Read mode shows where each verse sits (`"A-1 · TMS 60"`); review mode hides
    /// it. Once the verse is masked, its subpack and pack name are a clue about the
    /// answer rather than a caption — see `FlashcardView.showCardLabel`.
    private var showsCardLabel: Bool { !vm.isReviewMode }

    /// "3 of 37" for the top bar. Review tracks `currentIndex`; the read list tracks
    /// what's actually on screen, since scrolling there doesn't move `currentIndex`
    /// (it only changes when you tap a card).
    private var positionLabel: String {
        let i = vm.isReviewMode ? vm.currentIndex : visibleListIndex
        return "\(i + 1) of \(vm.verses.count)"
    }

    // MARK: - Review Card Stack

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
                let frontCard = makeCard(verse: verse, verseIndex: vm.currentIndex, interactive: true)
                    .offset(x: goingBack ? 0 : dragOffset.width,
                            y: goingBack ? backwardDragProgress * 12 : dragOffset.height * 0.1)
                    .scaleEffect(goingBack ? 1.0 - backwardDragProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                // `simultaneousGesture` lets TextField taps and TextEditor cursor/selection still fire;
                // the gesture itself filters out predominantly-vertical drags so editor scroll keeps working.
                let swipingCard = frontCard.simultaneousGesture(swipeGesture)

                // Tap anywhere on the card to bring the keyboard back. Not in
                // submit mode, where the card *is* two text inputs. A plain tap
                // (not simultaneous) so the card's own controls, like the star,
                // don't also summon the keyboard.
                if studyMode != .submit {
                    swipingCard
                        .onTapGesture {
                            guard !vm.isCardComplete else { return }
                            focusInput()
                        }
                } else {
                    swipingCard
                }
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

    // MARK: - Read List

    private func verticalScrollCards(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                                // Tap a verse to review it (completed ones too).
                                Button {
                                    openReview(at: index)
                                } label: {
                                    makeCard(verse: verse, verseIndex: index, interactive: index == vm.currentIndex)
                                        .frame(width: cardWidth, height: cardHeight)
                                }
                                // Same press-scale as the pack covers.
                                .buttonStyle(CardButtonStyle())
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
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

                        // Mapped off the same fraction the fast-scroll thumb uses, so
                        // the counter and the thumb agree and both ends are exact.
                        let idx = ScrubberMath.index(fraction: f, count: vm.verses.count)
                        if visibleListIndex != idx { visibleListIndex = idx }
                    }
                    .scrollPosition(id: $verticalScrollTarget, anchor: .center)

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
                // `onAppear` runs when returning from review (the scroll view is
                // removed during review, so scroll position would otherwise reset).
                // No animation or delay — scrollPosition mounts the list already
                // centered on the card.
                .onAppear {
                    verticalScrollTarget = vm.currentIndex
                }
                .onChange(of: vm.currentIndex) { _, newIndex in
                    // Tap-on-card or external nav — keep scroll position in sync.
                    // Thumb drag sets isScrubbing, so skip to avoid a duplicate scroll.
                    guard !isScrubbing else { return }
                    withAnimation(AppMotion.content) { verticalScrollTarget = newIndex }
                }
                // Bottom-trailing to match the single-card view (aligned to the layout
                // margin). Visibility tracks the cursor card's scroll position, so the
                // button returns after you scroll away from a jump.
                .overlay(alignment: .bottomTrailing) {
                    if showJumpInList(cardHeight: cardHeight, viewportHeight: outerGeo.size.height) {
                        JumpToCurrentButton(startExpanded: !jumpLabelShown,
                                            onExpandedShown: { jumpLabelShown = true },
                                            action: {
                            // Sets the scroll target directly so a re-jump works even
                            // when `currentIndex` is already the cursor.
                            guard let i = currentVerseIndexInPack else { return }
                            HapticEngine.light()
                            moveProgrammatically(refocus: false) {
                                if vm.currentIndex != i { vm.currentIndex = i }
                                withAnimation(AppMotion.movement) { verticalScrollTarget = i }
                            }
                        })
                        .padding(.trailing, AppLayout.screenMargin)
                        .padding(.bottom, 12)
                    }
                }
                .animation(AppMotion.content,
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
    private func makeCard(verse: Verse, verseIndex: Int, interactive: Bool) -> some View {
        let hasResult = vm.submitResults[verse.id] != nil
        let isBehind = verseIndex < vm.currentIndex
        let isAhead = verseIndex > vm.currentIndex
        let isDirectNext = verseIndex == vm.currentIndex + 1
        let isDirectPrev = verseIndex == vm.currentIndex - 1

        // Peek is drawn as an overlay in `body`, never by swapping this card:
        // replacing the SubmitCardView would destroy the focused text field.
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
                isCurrentLearning: learning.isCurrent(verse),
                showCardLabel: showsCardLabel,
                showsFavoriteToggle: interactive
            )
            .allowsHitTesting(interactive)
        } else {
            // Submit + Review stack: cards behind the front one stay fully masked.
            let forceMasked = studyMode == .submit && vm.isReviewMode && !interactive
                && ((isAhead && (!isDirectNext || hasResult)) || isBehind)
            let titleRev = forceMasked ? 0 : vm.revealedCount(for: verse.id, section: .title)
            let verseRev = forceMasked ? 0 : vm.revealedCount(for: verse.id, section: .verse)
            FlashcardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                isReviewMode: vm.isReviewMode,
                titleRevealedCount: titleRev,
                verseRevealedCount: verseRev,
                activeSection: vm.activeSection,
                onSectionTap: interactive && vm.isReviewMode ? { section in
                    vm.activeSection = section
                    DispatchQueue.main.async { focusInput() }
                } : nil,
                showCardLabel: showsCardLabel,
                isCurrentLearning: learning.isCurrent(verse),
                onMarkComplete: vm.isReviewMode ? nil : { markVerseComplete(verse) },
                // Review: on the card being answered (the moment you can't recall
                // it is when you want to star it). Read: on every card.
                showsFavoriteToggle: vm.isReviewMode ? interactive : true
            )
        }
    }

    // MARK: - Scrubber

    private var scrubberRow: some View {
        VerseScrubberRow(
            verseCount: vm.verses.count,
            currentIndex: $vm.currentIndex,
            isScrubbing: $isScrubbing,
            trackHeight: 44,
            canStepBeyondStart: canCrossBackward,
            canStepBeyondEnd: canCrossForward,
            onStepBack: {
                HapticEngine.light()
                moveProgrammatically(stepBackward)
            },
            onStepForward: {
                HapticEngine.light()
                moveProgrammatically(stepForward)
            }
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 6) {
            if vm.isReviewMode {
                cardControlBand
            }

            if !isEditing {
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
        .animation(AppMotion.content, value: vm.isReviewMode)
        .animation(AppMotion.content, value: vm.isCardComplete)
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
                    HStack(spacing: 10) {
                        TryAgainButton {
                            vm.resetCurrentCard()
                            // The reset remounts the input field; bring the keyboard back.
                            refocusIfNeeded()
                        }
                        if isCurrentLearningVerse { markLearntButton } else { nextButton }
                    }
                } else if studyMode == .submit {
                    submitControls
                } else {
                    RecallInputField(vm: vm, studyMode: studyMode,
                                     isListening: speech.isListening,
                                     isFocused: $isInputFocused,
                                     onToggleSpeech: toggleSpeech)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Advance to the next card once this one is done. Steps into the adjacent pack
    /// at a boundary, same as the scrubber's chevron.
    private var nextButton: some View {
        let canAdvance = vm.currentIndex < vm.verses.count - 1 || canCrossForward
        return Button {
            HapticEngine.light()
            moveProgrammatically(stepForward)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .font(.system(size: 18))
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text("Next")
            }
            .studyActionLabel()
        }
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.5)
        .accessibilityLabel("Verse complete, go to next")
    }

    /// Marks the current learning verse complete and moves on (crossing packs at
    /// a boundary).
    private var markLearntButton: some View {
        MarkCompleteButton {
            if let v = vm.currentVerse { markVerseComplete(v) }
            moveProgrammatically(stepForward)
        }
        .accessibilityLabel("Mark verse as complete and continue")
    }

    /// Entire Verse mode: mic + Submit before scoring, Try Again after.
    @ViewBuilder
    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        if hasResult {
            HStack(spacing: 10) {
                TryAgainButton { vm.retrySubmit() }
                if isCurrentLearningVerse { markLearntButton }
            }
        } else {
            SubmitAnswerRow(
                isListening: speech.isListening,
                canSubmit: vm.hasSubmitInput,
                onToggleSpeech: toggleSpeech,
                onHint: { vm.fillNextHintWord(startingWithVerse: submitFocus == .verse) },
                onSubmit: submitAnswer
            )
        }
    }

    private func submitAnswer() {
        if speech.isListening { speech.stopListening() }
        let result = vm.handleSubmit()
        submitFocus = nil
        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
    }

    // MARK: - Swipe Gesture

    private var forwardDragProgress: CGFloat {
        CardSwipeConfig.forwardDragProgress(dragWidth: dragOffset.width)
    }

    private var backwardDragProgress: CGFloat {
        CardSwipeConfig.backwardDragProgress(dragWidth: dragOffset.width)
    }

    /// Downward travel that counts as "put the keyboard away" rather than a
    /// stray vertical wobble during a horizontal swipe.
    private static let keyboardDismissPull: CGFloat = 40

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
                    withAnimation(AppMotion.control) { dragOffset = .zero }
                    // A deliberate pull downward is a request to put the keyboard
                    // away — the gesture that starts it already dismisses it, so
                    // all that's needed is to stop restoring focus afterwards.
                    // Everything else here is an uncommitted swipe, which should
                    // leave you where you were, still typing.
                    //
                    // Not in submit mode: there the vertical axis belongs to the
                    // TextEditor for scrolling and selection.
                    let pulledDown = !isHorizontal
                        && studyMode != .submit
                        && value.translation.height > Self.keyboardDismissPull
                    if pulledDown {
                        isInputFocused = false
                        submitFocus    = nil
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { refocusIfNeeded() }
                    }
                }
            }
    }

    private func swipeForward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = -1
        HapticEngine.light()
        withAnimation(AppMotion.control) {
            dragOffset = CGSize(width: -CardSwipeConfig.flyWidth, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { commitSwipe() }
    }

    private func swipeBackward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = 1
        HapticEngine.light()
        withAnimation(AppMotion.control) {
            dragOffset = CGSize(width: CardSwipeConfig.prevCardOffset, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { commitSwipe() }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
    }

    // MARK: - Focus & Speech

    /// Whether the leading chrome button goes back to the list instead of closing.
    ///
    /// It undoes the last step, which is what a back control is for: reading is a
    /// level above reviewing only when you actually came through it. Open the
    /// screen straight into review — which Home does, on a setting — and review is
    /// the top level, so closing stays one tap.
    ///
    /// Keyed on how you arrived rather than on whether the keyboard is up. Both
    /// fix the misfire this came from (entering review focuses the input, which
    /// hides the Read/Review picker and leaves close as the only visible control),
    /// but the keyboard comes and goes mid-session — a button that changed meaning
    /// with it would be the same trap wearing a different hat.
    private var returnsToRead: Bool { vm.isReviewMode && enteredReviewFromList }

    /// Switch to review on `index`, from a tap on that card in the list.
    private func openReview(at index: Int) {
        guard vm.verses.indices.contains(index) else { return }
        HapticEngine.light()
        tappedListIndex = index
        withAnimation(AppMotion.content) { vm.isReviewMode = true }
    }

    private func handleReviewModeChange(_ reviewing: Bool) {
        // Only the toggle and a card tap move this. Opening already in review never
        // runs this handler, which is exactly the distinction `returnsToRead` needs.
        enteredReviewFromList = reviewing

        // Which verse review opens on.
        //
        // A tapped card names one outright. Otherwise the toggle was used, and the
        // scroll position is the best available answer to "which verse were you
        // looking at" — better than the old approach of having a tap silently set
        // a selection whose only effect landed on a screen you hadn't reached yet.
        if reviewing {
            let target = tappedListIndex ?? visibleListIndex
            if vm.verses.indices.contains(target) { vm.currentIndex = target }
        }
        tappedListIndex = nil
        if reviewing && !vm.isCardComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focusInput() }
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

    /// Puts the keyboard back on the answer input, re-arming until it actually takes.
    ///
    /// Completing a card unmounts the input field (the Try Again / Mark as Complete
    /// row takes its place), so on the *next* card the field is a freshly inserted
    /// view. A lone `isInputFocused = true` fired while that insertion is still
    /// animating in gets dropped on the floor — which is why the keyboard stayed shut
    /// once you'd finished a verse. Retrying costs nothing when focus lands on the
    /// first attempt (the guard below stops immediately).
    private func focusInput(retriesLeft: Int = 4) {
        studyMode == .submit ? (submitFocus = .title) : (isInputFocused = true)
        guard retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            // Left review mode or finished the card while we waited — leave it alone.
            guard vm.isReviewMode, !vm.isCardComplete else { return }
            let landed = studyMode == .submit ? (submitFocus != nil) : isInputFocused
            if !landed { focusInput(retriesLeft: retriesLeft - 1) }
        }
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
            // The recognizer restarts its transcript from empty, so the
            // already-matched count has to start over with it.
            vm.resetDictation()
            speech.startListening()
        }
    }

}

#Preview {
    CardStudyView(packName: "5 Assurances", verses: Array(packsNIV84.first?.verses.prefix(5) ?? []))
}
