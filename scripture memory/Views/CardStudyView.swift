import SwiftUI

struct CardStudyView: View {

    // MARK: - State

    @StateObject private var vm:     CardStudyViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @AppStorage("studyMode")       private var studyMode:       StudyMode = .firstLetter

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var shakeOffset:  CGFloat = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false
    /// Set when the Read/Review toggle put us in review — see `returnsToRead`.
    @State private var enteredReviewFromList = false
    /// Verse a list tap asked review to open on, consumed by `handleReviewModeChange`.
    @State private var tappedListIndex: Int?
    @State private var isPeeking             = false
    /// Raw vertical scroll offset of the read-mode list — lets the jump button track
    /// whether the cursor card is actually on screen, not just `currentIndex` (which
    /// only changes on tap, so scrolling away after a jump never brought it back).
    @State private var listScrollOffset: CGFloat = 0

    /// Live continuous scroll position (0 = top, 1 = bottom) in vertical-scroll
    /// browse mode, measured from the content's offset. Drives the fast-scroll
    /// thumb so it tracks smoothly and reaches both ends exactly.
    @State private var scrollFraction: Double = 0
    /// Index of the card sitting in the middle of the viewport in list mode,
    /// derived from the scroll offset. `currentIndex` can't answer "where am I?"
    /// there — it only moves when you tap a card — so the position counter needs
    /// its own scroll-derived value.
    @State private var visibleListIndex: Int = 0
    /// The jump shortcut's label is a one-time teach, not a recurring banner —
    /// see `JumpToCurrentButton`. Lives here so both the card and list placements
    /// share one budget for the whole time this screen is open.
    @State private var jumpLabelShown = false
    /// Pending "marked complete" undo prompt.
    @State private var undoToastState: UndoToastState?
    /// Scroll target for the vertical read list. Driven by `scrollPosition(id:)`
    /// rather than `ScrollViewReader.scrollTo` because scrollPosition's
    /// programmatic scrolls are natively interruptible — the user can grab
    /// the list mid-animation and take over, which scrollTo forbids.
    @State private var verticalScrollTarget: Int?
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

    /// Offer "Mark as Complete" only on the verse the cursor is actually parked on.
    ///
    /// This used to also fire whenever `onMarkLearnt` was supplied — but that hook is
    /// set for the entire Continue-Learning session, so every card in it offered to
    /// mark a verse complete, including ones already learnt and ones nowhere near
    /// the cursor. On those the button was at best a no-op (`markLearnt` ignores an
    /// already-learnt verse) and at worst misleading, and it displaced the Next
    /// button you actually wanted. The hook decides *what marking does*, not
    /// *whether there's anything to mark*.
    private var offersMarkLearnt: Bool { isCurrentLearningVerse }

    /// Float the "Current verse" shortcut when this pack holds the current stopped
    /// verse and we're parked on a different card.
    ///
    /// This used to also require the keyboard to be down. Review mode holds focus on
    /// the answer field the whole time it's open, so that condition was never
    /// satisfied there and the shortcut simply didn't exist in review — the mode
    /// where hopping back to the verse you're actually learning matters most. Read
    /// mode has no text input at all, so the condition never did anything there
    /// either; it only ever suppressed the button.
    private var showGoToCurrent: Bool {
        guard let i = currentVerseIndexInPack else { return false }
        return i != vm.currentIndex
    }

    private func jumpToCurrentVerse() {
        guard let i = currentVerseIndexInPack, i != vm.currentIndex else { return }
        isScrubbing = true
        withAnimation(AppMotion.movement) { vm.currentIndex = i }
        HapticEngine.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
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
    private func markVerseComplete(_ verse: Verse) {
        if let cb = onMarkLearnt { cb(verse) } else { LearningStore.shared.markLearnt(verse) }
        HapticEngine.success()
        raiseMarkedCompleteToast(for: verse)
    }

    /// Offer a short window to take back a "Mark as Complete". It's a one-tap
    /// action sitting right next to the card, and it advances the learning cursor —
    /// cheap to hit by accident, tedious to reverse without this.
    ///
    /// Undo only restores the learnt flag (and with it the cursor). It deliberately
    /// doesn't rewind navigation: the review-mode button also steps to the next
    /// card, and that step can cross into another pack, so unwinding it would be a
    /// far bigger and less predictable jump than the user asked to undo.
    private func raiseMarkedCompleteToast(for verse: Verse) {
        undoToastState = UndoToastState(message: "Marked as complete") {
            LearningStore.shared.unmarkLearnt(verse)
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 2 * AppLayout.screenMargin
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar(width: geo.size.width)

                // Read mode is a scrolling list of cards — the only browse layout.
                // (A single-card, swipe-through read mode used to sit behind a
                // toggle here; nobody used it, so the toggle and the layout are
                // gone.) Review mode still shows one focused card: it's a
                // question you answer, not a thing you browse.
                if !vm.isReviewMode {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    // Review grows the card into the otherwise-empty vertical space
                    // (capped so it stays card-shaped) — the masked underscores need
                    // the extra room — and as the flexible middle it also absorbs the
                    // keyboard inset, shrinking to fit when typing rather than
                    // overflowing.
                    GeometryReader { area in
                        let cardH = max(cardHeight, min(cardWidth * 0.82, area.size.height - 16))
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
                                    isPeeking: isPeeking,
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
            // Entire Verse collects the transcript as free text to submit; the two
            // typing modes match it word by word against the hidden verse instead.
            if studyMode == .submit {
                switch speechTarget {
                case .title: vm.titleInput = text
                case .verse: vm.verseInput = text
                }
            } else {
                vm.processDictation(text)
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
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Close keyboard")
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
                                // Changing *what's in the list* is a chrome
                                // action, not arriving at a new card to answer —
                                // so it shouldn't summon the keyboard. Rebuilding
                                // moves `currentIndex`, which normally means
                                // "next card, start typing"; `isScrubbing` is the
                                // existing signal for "this move was programmatic".
                                isInputFocused = false
                                submitFocus    = nil
                                isScrubbing    = true
                                vm.setFavoritesFilter(!vm.isFavoritesFiltered)
                                if !vm.isReviewMode { scrollListToTop() }
                                HapticEngine.light()
                                DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                                    isScrubbing = false
                                }
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
        .padding(.top, 12)
        .padding(.bottom, 12)
        .animation(AppMotion.control, value: isEditing)
    }

    /// True whenever either text input has keyboard focus.
    private var isEditing: Bool { isInputFocused || submitFocus != nil }

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
                let frontCard = makeCard(verse: verse, verseIndex: vm.currentIndex, interactive: true, isPeeking: false)
                    .offset(x: goingBack ? 0 : dragOffset.width,
                            y: goingBack ? backwardDragProgress * 12 : dragOffset.height * 0.1)
                    .scaleEffect(goingBack ? 1.0 - backwardDragProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                // `simultaneousGesture` lets TextField taps and TextEditor cursor/selection still fire;
                // the gesture itself filters out predominantly-vertical drags so editor scroll keeps working.
                let swipingCard = frontCard.simultaneousGesture(swipeGesture)

                // Tap anywhere on the card to bring the keyboard back. Previously the
                // only way in was the section text itself — a couple of thin lines —
                // so most of the card was dead space. Restricted to the masked-recall
                // modes: in submit mode the card *is* two text inputs, and forcing
                // focus to the title would steal taps meant for the verse editor.
                if vm.isReviewMode && studyMode != .submit {
                    swipingCard
                        // A plain tap gesture, NOT `simultaneousGesture`. Simultaneous
                        // means "fire as well as whatever was actually hit", so every
                        // control on the card — the star, in particular — summoned the
                        // keyboard on top of doing its own job.
                        //
                        // Nothing is lost by yielding to the controls: a tap on the
                        // title/verse underscores hits FlashcardView's section handler,
                        // which focuses the input itself, and the verse section already
                        // stretches over the blank space below it. This only has to
                        // cover what's genuinely dead — the reference line and the
                        // footer's empty middle.
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

    // MARK: - Vertical Scroll Mode

    private func verticalScrollCards(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                                // Tap a verse to review that verse.
                                //
                                // This existed once as a way to *select* the card
                                // review would later open on, and was removed
                                // because the tap did nothing you could see. Taking
                                // you straight there is the opposite: the whole
                                // result is immediate, and the chevron that
                                // replaces close on this path is the way back.
                                //
                                // Completed verses open too — re-drilling something
                                // you've finished is a normal thing to want.
                                Button {
                                    openReview(at: index)
                                } label: {
                                    makeCard(verse: verse, verseIndex: index, interactive: index == vm.currentIndex)
                                        .frame(width: cardWidth, height: cardHeight)
                                }
                                // Same press-scale the pack covers use, so a card
                                // that can be tapped looks like one without adding
                                // any chrome to say so.
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

                        // Where the counter says you are. Mapped straight off the
                        // scroll fraction — the same function the fast-scroll thumb
                        // uses — so the number in the top bar and the thumb beside it
                        // can never disagree, and both ends are exact by construction:
                        // fraction 0 is card 1, fraction 1 is card N.
                        //
                        // This used to invert the card layout to find whichever card
                        // sat under the middle of the viewport, with the two ends
                        // special-cased. But the viewport is taller than one card and
                        // can't scroll far enough to centre the first or last one, so
                        // at rest against either stop the middle of the screen points
                        // a card or two inward — the top of the list read "2 of 32",
                        // and the special cases only papered over the exact stops.
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
                            // Set the scroll target directly (not just currentIndex)
                            // so a re-jump still works when currentIndex is already the
                            // cursor from a previous jump.
                            guard let i = currentVerseIndexInPack else { return }
                            HapticEngine.light()
                            isScrubbing = true
                            if vm.currentIndex != i { vm.currentIndex = i }
                            withAnimation(AppMotion.movement) { verticalScrollTarget = i }
                            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
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
                isCurrentLearning: learning.isCurrent(verse),
                showCardLabel: showsCardLabel,
                showsFavoriteToggle: interactive
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
                showCardLabel: showsCardLabel,
                isCurrentLearning: learning.isCurrent(verse),
                onMarkComplete: vm.isReviewMode ? nil : { markVerseComplete(verse) },
                // Review: always, on the card being answered. Starring is "come
                // back to this one", and the moment you know that is the moment
                // you couldn't recall it.
                //
                // Read: on every card. Showing it only when already filled kept
                // the list clean and made un-starring possible, but left no way to
                // star a verse *from* the list — the obvious place to do it while
                // reading a pack.
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
            showPositionLabel: false,
            trackHeight: 44,
            onScrubIndexChange: nil,
            canStepBeyondStart: canCrossBackward,
            canStepBeyondEnd: canCrossForward,
            // Stepping lands on a new card to answer, so the keyboard comes back with
            // it — `refocusIfNeeded` no-ops outside review mode and on finished cards.
            onStepBack: {
                isScrubbing = true
                stepBackward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                    isScrubbing = false
                    refocusIfNeeded()
                }
            },
            onStepForward: {
                isScrubbing = true
                stepForward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                    isScrubbing = false
                    refocusIfNeeded()
                }
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
                    // Try Again pairs with whichever "move on" action this card
                    // offers. It used to appear only on the learning-cursor verse,
                    // which left every other card with no way back into it —
                    // finishing one was a one-way door, and re-practising a verse
                    // meant leaving review and coming back.
                    //
                    // The second slot takes over from the old "Complete!" label,
                    // which only announced a state the card already shows with its
                    // green section checks while the thing you actually wanted —
                    // moving on — was stranded on the scrubber chevron. The check
                    // icon keeps the completion signal.
                    HStack(spacing: 10) {
                        tryAgainButton
                        if offersMarkLearnt { markLearntButton } else { nextButton }
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

    /// Advance to the next card once this one is done. Steps into the adjacent pack
    /// at a boundary, same as the scrubber's chevron, so it's only disabled at the
    /// true end of the sequence.
    private var nextButton: some View {
        let canAdvance = vm.currentIndex < vm.verses.count - 1 || canCrossForward
        return Button {
            isScrubbing = true
            stepForward()
            HapticEngine.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                isScrubbing = false
                refocusIfNeeded()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .font(.system(size: 18))
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.5)
        .accessibilityLabel("Verse complete, go to next")
    }

    /// "Continue Learning" only: the single action that marks a verse done. Marks
    /// the current verse learnt and advances to the next (crossing packs at a
    /// boundary). Streak/test progress is handled separately on submit.
    private var markLearntButton: some View {
        Button {
            if let v = vm.currentVerse {
                if let cb = onMarkLearnt { cb(v) } else { LearningStore.shared.markLearnt(v) }
                raiseMarkedCompleteToast(for: v)
            }
            HapticEngine.success()
            isScrubbing = true
            stepForward()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                isScrubbing = false
                refocusIfNeeded()
            }
        } label: {
            // Short label: it shares the row with "Try Again", and the checkmark
            // plus its position on the cursor verse already carry the meaning.
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.green)
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .accessibilityLabel("Mark verse as complete and continue")
    }

    /// Resets the current card so the user can attempt it again (clears revealed
    /// words / submitted answer for whichever study mode is active).
    private var tryAgainButton: some View {
        Button {
            vm.resetCurrentCard()
            // The input field is remounted by the reset — bring the keyboard back
            // with it, since typing is the only thing you tapped Try Again to do.
            refocusIfNeeded()
        } label: {
            Label("Try Again", systemImage: "arrow.counterclockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(StudyControlMetrics.cornerRadius)
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
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .roundedRect(StudyControlMetrics.cornerRadius)
                    }
                    if offersMarkLearnt { markLearntButton }
                }
            } else {
                HStack(spacing: 10) {
                    Button { toggleSpeech() } label: {
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(speech.isListening ? Color.white : Color.primary)
                            .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                            .background(speech.isListening ? Color.red : Color(.secondarySystemGroupedBackground))
                            .roundedRect(StudyControlMetrics.cornerRadius)
                    }
                    .accessibilityLabel(speech.isListening ? "Stop dictation" : "Dictate verse")

                    submitHintButton
                    let isEmpty = vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                              && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                    Button {
                        if speech.isListening { speech.stopListening() }
                        let result = vm.handleSubmit()
                        submitFocus = nil
                        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(isEmpty ? Color(.systemGray3) : Color.accentColor)
                            .roundedRect(StudyControlMetrics.cornerRadius)
                    }
                    .disabled(isEmpty)
                }
            }
        }
    }

    /// Entire Verse's hint: types the next word straight into the answer box.
    ///
    /// A `Button` (not a bare tap target) so pressing it doesn't resign the
    /// editor's first responder and dismiss the keyboard mid-verse.
    private var submitHintButton: some View {
        Button {
            fillNextHintWord()
            HapticEngine.light()
        } label: {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reveal next word")
    }

    /// Extends whichever box you're in by one word, falling through to the other
    /// once that one is complete — so repeated taps walk the whole card without
    /// having to move focus by hand.
    private func fillNextHintWord() {
        guard let verse = vm.currentVerse else { return }
        let startWithVerse = submitFocus == .verse
        let sections: [(target: String, isTitle: Bool)] = startWithVerse
            ? [(verse.verse, false), (verse.title, true)]
            : [(verse.title, true), (verse.verse, false)]

        for section in sections {
            let typed = section.isTitle ? vm.titleInput : vm.verseInput
            guard let filled = HintFill.next(target: section.target, typed: typed) else { continue }
            if section.isTitle { vm.titleInput = filled } else { vm.verseInput = filled }
            return
        }
    }

    /// First-letter and full-word modes share this single text field.
    private var inputField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                dictationButton

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
            .roundedRect(StudyControlMetrics.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: StudyControlMetrics.cornerRadius, style: .continuous).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)

            hintButton
        }
    }

    /// Speak the verse instead of typing it. Takes the slot the decorative
    /// "character.cursor.ibeam" glyph used to occupy inside the text field: the
    /// control row (peek, field, hint) has no width left for a fourth button, and
    /// that glyph was ornament. Entire Verse mode keeps its own larger mic in
    /// `submitControls` — this field only exists in the two typing modes.
    ///
    /// A `Button`, so pressing it doesn't resign the field's first responder and
    /// dismiss the keyboard mid-verse.
    private var dictationButton: some View {
        Button { toggleSpeech() } label: {
            Image(systemName: speech.isListening ? "mic.fill" : "mic")
                .font(.system(size: 16))
                .foregroundStyle(speech.isListening ? Color.red : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speech.isListening ? "Stop dictation" : "Dictate verse")
    }

    /// Reveals the next hidden word (verse first, then title). Wrapped in a
    /// Button so the touch is a recognized tap target and doesn't resign the
    /// keyboard's first responder.
    private var hintButton: some View {
        Button {
            vm.revealHint()
            HapticEngine.light()
        } label: {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .buttonStyle(.plain)
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
