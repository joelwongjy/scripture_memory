import SwiftUI

struct CardStudyView: View {

    // MARK: - State

    @StateObject private var vm:     CardStudyViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()

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

    /// Measured height of the vertical-scroll area (populated by a
    /// `.background(GeometryReader)` on the ScrollView — see
    /// `verticalScrollCards`). Seed to 0; the first layout pass writes the
    /// real value and the fast-scroll thumb renders at full track length.
    @State private var scrollAreaHeight: CGFloat = 0
    /// Current scroll content offset (LazyVStack's minY in scroll coord
    /// space — negative as user scrolls down). Drives the thumb's display
    /// position so it follows the user's finger.
    @State private var scrollContentOffset: CGFloat = 0
    /// Total height of the scroll content. Paired with scrollAreaHeight to
    /// compute the max scrollable distance for mapping offset → index.
    @State private var scrollContentHeight: CGFloat = 0
    /// Bumped on every scroll offset change so the overlay can fade in.
    @State private var scrollActivityPulse: Int = 0

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    /// Name used for the ScrollView's coordinate space so content-offset
    /// probes can measure Y relative to the viewport.
    private static let scrollSpace = "verticalScrollCards"

    /// Temporarily disabled — the fast-scroll thumb wasn't tracking user
    /// scroll reliably (preferences inside the lazy ScrollView weren't
    /// firing). Code is preserved below pending a proper rewrite, e.g.
    /// using `scrollPosition(id:)` or a UIKit bridge.
    private static let fastScrollEnabled = false

    init(packName: String, verses: [Verse], initialIndex: Int = 0) {
        _vm = StateObject(wrappedValue: CardStudyViewModel(packName: packName, verses: verses, initialIndex: initialIndex))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                // Vertical scroll is for browsing in read mode only.
                // Review mode always shows a single focused card.
                if isVerticalScroll && !vm.isReviewMode {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 12)
                    ZStack {
                        cardStack
                            .frame(width: cardWidth, height: cardHeight)
                        // Peek in submit-mode renders as an OVERLAY so the
                        // SubmitCardView (and its focused TextField) stays
                        // mounted — otherwise the keyboard dismisses.
                        if studyMode == .submit, vm.isReviewMode, isPeeking,
                           let verse = vm.currentVerse {
                            PeekOverlayCard(
                                verse: verse,
                                cardLabel: vm.cardLabel(for: verse),
                                width: cardWidth,
                                height: cardHeight,
                                isPeeking: isPeeking
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .zIndex(100)
                        }
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 12)
                }

                if !isVerticalScroll || vm.isReviewMode {
                    scrubberRow
                        .padding(.horizontal, 20)
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

    private var topBar: some View {
        ZStack {
            // Title is always geometrically centred regardless of button count.
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

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }

                Spacer()

                HStack(spacing: 8) {
                    if vm.canReset {
                        Button { vm.resetCurrentCard() } label: {
                            Image(systemName: "arrow.counterclockwise").studyChromeCircleButton()
                        }
                    }
                    Button {
                        vm.toggleShuffle()
                        HapticEngine.light()
                    } label: {
                        Image(systemName: "shuffle")
                            .studyChromeToggle(isOn: vm.isShuffled)
                    }
                    Button {
                        isVerticalScroll.toggle()
                    } label: {
                        Image(systemName: isVerticalScroll ? "rectangle.stack" : "list.bullet.rectangle")
                            .studyChromeToggle(isOn: isVerticalScroll)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
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
                let showingPeek = isPeeking && vm.isReviewMode
                makeCard(verse: verse, verseIndex: vm.currentIndex, interactive: true, isPeeking: showingPeek)
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
        // TWO height sources for robustness:
        //  1. Outer GeometryReader fires on first layout pass — guarantees
        //     the thumb renders immediately with a reasonable track, even
        //     before any preference has been written.
        //  2. `.background(GeometryReader).preference` on the ScrollView
        //     then overrides with the true rendered height once layout
        //     settles (handles rotation, keyboard appearance, etc.).
        // The overlay is NEVER gated behind `scrollAreaHeight > 0` — if it
        // hasn't arrived yet we fall back to the outer geo.
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                let containerHeight = max(outerGeo.size.height, scrollAreaHeight, 100)
                // Map scroll offset → index so the thumb follows user scroll.
                // scrollContentOffset is the content's minY in the scroll's
                // coord space — goes from 0 (top) to negative as user scrolls
                // down. Max |offset| = contentHeight - viewportHeight.
                let scrollableDistance = max(scrollContentHeight - containerHeight, 1)
                let scrollFraction: Double = Double(min(max(-scrollContentOffset / scrollableDistance, 0), 1))
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        // Eager outer VStack so the top sentinel is NEVER
                        // unmounted by LazyVStack's recycling — otherwise
                        // when the user scrolls far enough down, the
                        // sentinel disappears, preferences stop firing,
                        // and the thumb gets stuck.
                        VStack(spacing: 0) {
                            // Top sentinel: probes scroll offset. Zero-height
                            // marker at the top of content. Its minY in the
                            // scroll's coord space is 0 at rest and goes
                            // negative as the user scrolls down.
                            Color.clear
                                .frame(height: 0)
                                .background(
                                    GeometryReader { g in
                                        Color.clear.preference(
                                            key: ScrollContentOffsetKey.self,
                                            value: g.frame(in: .named(Self.scrollSpace)).minY
                                        )
                                    }
                                )

                            LazyVStack(spacing: 20) {
                                ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                                    makeCard(verse: verse, verseIndex: index, interactive: index == vm.currentIndex)
                                        .frame(width: cardWidth, height: cardHeight)
                                        .id(index)
                                        .overlay {
                                            if index != vm.currentIndex {
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
                            // Total content height — measured on the padded
                            // LazyVStack. Stable across scroll because it's
                            // measuring the container, not its position.
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(
                                        key: ScrollContentHeightKey.self,
                                        value: g.size.height
                                    )
                                }
                            )
                        }
                    }
                    .coordinateSpace(name: Self.scrollSpace)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollAreaHeightKey.self,
                                            value: geo.size.height)
                        }
                    )

                    if Self.fastScrollEnabled, vm.verses.count >= 2 {
                        VerseFastScrollOverlay(
                            verseCount: vm.verses.count,
                            scrollFraction: scrollFraction,
                            containerHeight: containerHeight,
                            isScrubbing: $isScrubbing,
                            scrollActivityPulse: $scrollActivityPulse,
                            labelProvider: { idx in
                                guard vm.verses.indices.contains(idx) else { return "" }
                                let v = vm.verses[idx]
                                return "\(v.book) \(v.reference)"
                            },
                            onScrubTo: { newIndex in
                                // Jump the list immediately (no animation — 1:1
                                // drag feel) AND update currentIndex so that
                                // switching to review mode opens the right card.
                                var t = Transaction()
                                t.disablesAnimations = true
                                withTransaction(t) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                                if vm.currentIndex != newIndex {
                                    vm.currentIndex = newIndex
                                }
                            }
                        )
                    }
                }
                .onPreferenceChange(ScrollAreaHeightKey.self) { newHeight in
                    if abs(newHeight - scrollAreaHeight) > 0.5 {
                        scrollAreaHeight = newHeight
                    }
                }
                .onPreferenceChange(ScrollContentOffsetKey.self) { newOffset in
                    guard newOffset != scrollContentOffset else { return }
                    scrollContentOffset = newOffset
                    scrollActivityPulse &+= 1
                }
                .onPreferenceChange(ScrollContentHeightKey.self) { newHeight in
                    if abs(newHeight - scrollContentHeight) > 0.5 {
                        scrollContentHeight = newHeight
                    }
                }
                // LazyVStack: yield + delay so row ids exist before scrollTo. `onAppear` runs when returning
                // from review (the scroll view is removed during review, so scroll offset would otherwise reset).
                .onAppear {
                    Task { await scrollVerticalReadListToCurrentVerse(proxy: proxy) }
                }
                .onChange(of: vm.currentIndex) { _, newIndex in
                    // currentIndex is only changed by: tap-on-card, thumb drag,
                    // or external code (initial load, review-mode transition).
                    // Thumb drag already scrolled the list in `onScrubTo`, so
                    // guard on isScrubbing to avoid a duplicate animated scroll
                    // on top of the direct one the thumb just performed.
                    if isScrubbing { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                    // Re-flash the thumb on card-tap navigation in case the
                    // scroll probe misses the offset change.
                    scrollActivityPulse &+= 1
                }
            }
        }
    }

    /// Scrolls the vertical read list so `currentIndex` is centered (read mode / vertical list only).
    @MainActor
    private func scrollVerticalReadListToCurrentVerse(proxy: ScrollViewProxy) async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(72))
        let idx = vm.currentIndex
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(idx, anchor: .center)
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
                focusedField: $submitFocus
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
                } : nil
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
            onStepBack: {
                isScrubbing = true
                vm.goBackward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            },
            onStepForward: {
                isScrubbing = true
                vm.goForward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            }
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 6) {
            if vm.isReviewMode {
                if vm.isCardComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green).font(.system(size: 22))
                        Text("Complete!")
                            .font(.system(size: 17, weight: .semibold)).foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 2)
                } else if studyMode == .submit {
                    submitControls
                } else {
                    inputField
                }
            }

            if !isInputFocused && submitFocus == nil {
                Picker("Mode", selection: $vm.isReviewMode) {
                    Text("Read").tag(false)
                    Text("Review").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
        .padding(.bottom, 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isReviewMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isCardComplete)
    }

    /// Submit mode: mic + submit button before scoring, try-again after.
    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        return Group {
            if hasResult {
                Button { vm.retrySubmit() } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
            } else {
                HStack(spacing: 10) {
                    Button { toggleSpeech() } label: {
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(speech.isListening ? .white : .primary)
                            .frame(width: 48, height: 48)
                            .background(speech.isListening ? Color.red : Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    peekIconButton
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
                            .background(isEmpty ? Color(.systemGray3) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(isEmpty)
                    if submitFocus != nil {
                        Button { submitFocus = nil } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
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
                    // Peek and dismiss live in the keyboard toolbar so touching them
                    // never triggers UIKit's resign-on-touch-outside behaviour.
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button {
                                isPeeking.toggle()
                                if isPeeking { HapticEngine.light() }
                            } label: {
                                Image(systemName: isPeeking ? "eye.fill" : "eye")
                                    .foregroundStyle(isPeeking ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.secondary))
                            }
                            Spacer()
                            Button { isInputFocused = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                            }
                        }
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)
        }
        .padding(.horizontal, 24)
    }

    private var peekIconButton: some View {
        // Wrapped in a Button (with no-op action) so iOS recognizes the touch as
        // a tap target and does NOT resign the first responder — otherwise the
        // keyboard dismisses on press. The DragGesture rides alongside via
        // simultaneousGesture for press-and-hold peek behavior.
        Button(action: {}) {
            Image(systemName: isPeeking ? "eye.fill" : "eye")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 48, height: 48)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPeeking {
                        isPeeking = true
                        HapticEngine.light()
                    }
                }
                .onEnded { _ in
                    isPeeking = false
                }
        )
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
                vm.goForward()
            } else if flyDirection > 0 {
                vm.goBackward()
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
