import SwiftUI

/// A pack: its cards as a list of the printed cards, which come out of and go
/// back into the pack's clear plastic pouch.
///
/// Opening, the pouch comes off its shelf tile, unfolds and fans its cards out
/// into the list. Closing (the ×, a swipe in from the leading edge, or a swipe
/// left across the list) gathers them back in and folds it shut. Tap a card to
/// practise from it.
///
/// On the iPhone Duo the hinge is the pouch's fold: shut, the front screen is
/// the pack's cover; open, the pouch lies flat across both halves.
struct PouchView: View {
    let pack: Pack
    /// The pack's tile on the shelf, in global coordinates, to fly out of and
    /// back into.
    let shelf: CGRect?
    /// Takes the screen away once the pouch is back on the shelf.
    var onPutBack: (() -> Void)?

    @State private var index: Int
    @State private var openness: CGFloat
    /// 0 with the stack in its pocket, 1 with it out over the pouch.
    @State private var lift: CGFloat = 0
    /// 0 with the cards out in a stack, 1 with them laid out as the list.
    @State private var spread: CGFloat = 0
    /// The cards are fanned out and the scrolling list has taken over.
    @State private var fanned: Bool
    /// The list has taken its scroll position, so the deck drawn over it while
    /// it settles can go.
    @State private var listSettled = false
    @State private var settleToken = 0
    @Environment(\.displayScale) private var displayScale
    @State private var closing = false
    @State private var openedAt = Date()
    /// The card centred in the list.
    @State private var listIndex: Int?
    @State private var listScrolled = false
    /// The list following a horizontal swipe, before it closes or springs back.
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeAxis: Axis?
    /// 1 with the pouch shut on its shelf tile, 0 with it in front of you.
    @State private var flight: CGFloat
    @State private var hingeDriven = false
    @State private var hingeShut = false
    @State private var practice: TestSession?
    @State private var undoToastState: UndoToastState?
    @AppStorage("pouch.jumpLabelShown.v1") private var jumpLabelShown = false

    @StateObject private var tilt = TiltMonitor()
    @ObservedObject private var learning = LearningStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// The top controls' height under the safe area: a 44pt control and its padding.
    private static let chromeHeight: CGFloat = 60
    /// How far in from the leading edge a swipe counts as the edge swipe.
    private static let edgeWidth: CGFloat = 28

    private var verses: [Verse] { pack.verses }

    init(pack: Pack, startIndex: Int, shelf: CGRect? = nil, onPutBack: (() -> Void)? = nil) {
        let reduce = AppMotion.reduceMotion
        let start = min(max(startIndex, 0), max(pack.verses.count - 1, 0))
        self.pack = pack
        self.shelf = shelf
        self.onPutBack = onPutBack
        _index = State(initialValue: start)
        _listIndex = State(initialValue: start)
        _openness = State(initialValue: reduce ? 1 : 0)
        _lift = State(initialValue: reduce ? 1 : 0)
        _spread = State(initialValue: reduce ? 1 : 0)
        _fanned = State(initialValue: reduce)
        _flight = State(initialValue: shelf != nil && !reduce ? 1 : 0)
    }

    var body: some View {
        GeometryReader { safe in
            let insets = safe.safeAreaInsets
            GeometryReader { root in
                let fold = Self.screenFold(in: root)
                if let fold, fold.height > fold.width {
                    pouch(fold: root.size.width - fold.midX, turned: true,
                          insets: EdgeInsets(top: insets.trailing, leading: insets.top,
                                             bottom: insets.leading, trailing: insets.bottom))
                        .frame(width: root.size.height, height: root.size.width)
                        .rotationEffect(.degrees(90))
                        .frame(width: root.size.width, height: root.size.height)
                } else {
                    pouch(fold: fold?.midY, turned: false, insets: insets)
                }
            }
            .ignoresSafeArea()
        }
        .background(Color(.systemGroupedBackground).opacity(Double(1 - flight)).ignoresSafeArea())
        .overlay {
            if hingeShut {
                FrontCover(pack: pack, shine: tilt.roll)
                    .transition(.opacity)
            }
        }
        .statusBarHidden(hingeShut)
        .undoToast($undoToastState)
        .tracksStudyScreen()
        .fullScreenCover(item: $practice) { session in
            TestSessionView(session: session, onSessionEnded: { practice = nil })
        }
        .modifier(FollowsHinge(onChange: hingeMoved))
        .onAppear { appeared() }
        .analyticsScreen(.pack)
        .onChange(of: fanned) { _, out in out ? tilt.stop() : tilt.start() }
        .onDisappear {
            tilt.stop()
            if verses.indices.contains(index) { PackPositions.save(verses[index], inPack: pack.name) }
        }
    }

    // MARK: - Layout

    /// `fold` is where the screen's fold crosses the pouch, measured down from
    /// its top; `turned`, that it's drawn a quarter turn round.
    @ViewBuilder
    private func pouch(fold: CGFloat?, turned: Bool, insets: EdgeInsets) -> some View {
        if fold != nil {
            ZStack {
                GeometryReader { geo in
                    scene(geo, fold: fold, turned: turned, chrome: insets.top + Self.chromeHeight)
                }
                VStack(spacing: 0) {
                    topBar
                    thumb
                }
                .padding(insets)
            }
        } else {
            VStack(spacing: 0) {
                topBar
                GeometryReader { geo in scene(geo, fold: nil, turned: turned, chrome: 0) }
                    .overlay { thumb }
            }
            .padding(insets)
        }
    }

    /// The pouch and the cards out of it. `chrome` is how far down the floating
    /// controls reach, which the list keeps its cards clear of.
    @ViewBuilder
    private func scene(_ geo: GeometryProxy, fold: CGFloat?, turned: Bool, chrome: CGFloat) -> some View {
        let listWidth = min(geo.size.width - 2 * AppLayout.screenMargin, 600)
        let listHeight = (listWidth / PouchMetrics.cardAspect * displayScale).rounded() / displayScale

        ZStack {
            if fanned {
                fannedList(width: listWidth, height: listHeight, viewport: geo.size.height, chrome: chrome)
                    .offset(x: swipeOffset)
                    .opacity(listSettled ? 1 : 0)
            }
            if !fanned || !listSettled {
                pouchAndDeck(geo, fold: fold, turned: turned, chrome: chrome,
                             listWidth: listWidth, listHeight: listHeight)
            }
        }
        .onChange(of: fanned) { _, out in if !out { listSettled = false } }
        .overlay(alignment: .bottomTrailing) {
            if fanned, let current = currentIndex, index != current {
                JumpToCurrentButton(startExpanded: !jumpLabelShown,
                                    onExpandedShown: { jumpLabelShown = true }) {
                    HapticEngine.light()
                    listScrolled = false
                    index = current
                    withAnimation(AppMotion.movement) { listIndex = current }
                }
                .padding(.trailing, AppLayout.screenMargin)
                .padding(.bottom, 24)
                .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
        }
        .animation(AppMotion.content, value: index == currentIndex)
    }

    /// Only drawn on the way in and out; once fanned, the list replaces it.
    @ViewBuilder
    private func pouchAndDeck(_ geo: GeometryProxy, fold: CGFloat?, turned: Bool, chrome: CGFloat,
                              listWidth: CGFloat, listHeight: CGFloat) -> some View {
        let foldY = fold.flatMap { $0 > 0 && $0 < geo.size.height ? $0 : nil }
        let m = foldY.map { PouchMetrics(width: geo.size.width, halfHeight: min($0, geo.size.height - $0)) }
            ?? PouchMetrics(fitting: CGSize(width: geo.size.width, height: geo.size.height - 12))
        let sceneTop = foldY.map { $0 - m.halfHeight } ?? (geo.size.height - 2 * m.halfHeight) / 2

        let coverCenter = CGPoint(x: geo.size.width / 2, y: sceneTop + m.halfHeight / 2 + m.cardFrame.midY)
        let area = geo.frame(in: .global)
        let tile = (turned ? nil : shelf) ?? CGRect(x: area.minX + coverCenter.x - m.cardWidth / 2,
                                                    y: area.minY + coverCenter.y - m.cardHeight / 2,
                                                    width: m.cardWidth, height: m.cardHeight)
        let shelfScale = tile.width / m.cardWidth

        PouchScene(openness: openness, lift: lift, m: m,
                   style: PlasticStyle(colorScheme), slots: slots, tilt: tilt.roll,
                   face: { cardFace($0, width: m.cardWidth) },
                   cover: { PackCover(pack: pack, cornerRadius: 2, showsShadow: false)
                                .frame(width: m.cardWidth) })
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(y: sceneTop - (geo.size.height - 2 * m.halfHeight) / 2)
            .opacity(Double(max(0, 1 - 0.55 * lift - 0.45 * spread)))
            .scaleEffect(1 - 0.04 * lift)
            .modifier(ShelfFlight(
                flight: flight, scale: shelfScale,
                anchor: UnitPoint(x: coverCenter.x / geo.size.width, y: coverCenter.y / geo.size.height),
                offset: CGSize(width: tile.midX - area.minX - coverCenter.x,
                               height: tile.midY - area.minY - coverCenter.y),
                tile: PackCover(pack: pack, isCurrentPack: pack.name == learning.currentVerse?.packName,
                                cornerRadius: AppLayout.cardRadius / shelfScale)
                    .frame(width: m.cardWidth, height: m.cardHeight)
                    .position(coverCenter)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        LiftedDeck(lift: lift, spread: spread,
                   pocketCenter: CGPoint(x: geo.size.width / 2, y: sceneTop + m.halfHeight + m.cardFrame.midY),
                   listCenter: CGPoint(x: geo.size.width / 2,
                                       y: listMidY(of: index, height: listHeight,
                                                   viewport: geo.size.height, chrome: chrome)),
                   pocketWidth: m.cardWidth, listWidth: listWidth,
                   listPitch: listHeight + AppLayout.spacing,
                   around: { $0 == 0 ? card(at: index) : verses.indices.contains(index + $0) ? .verse(index + $0) : .none },
                   edges: min(5, Int((Double(max(verses.count - index - 1, 0)) / 8).rounded(.up))),
                   face: { cardFace($0, width: $1) })
            .clipped()
            .mask { listMask(chrome: chrome) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        if !closing {
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    finishOpening(flick: value.predictedEndTranslation.height,
                                  pitch: listHeight + AppLayout.spacing)
                })
        }
    }

    private func fannedList(width: CGFloat, height: CGFloat, viewport: CGFloat, chrome: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppLayout.spacing) {
                    ForEach(verses.indices, id: \.self) { i in
                        Button { startPractice(from: i) } label: {
                            listCard(i, width: width)
                                .frame(width: width, height: height)
                                .listCardShadow()
                        }
                        .buttonStyle(CardButtonStyle())
                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .contextMenu { cardMenu(verses[i]) }
                        .id(i)
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppLayout.spacing)
            }
            .modifier(ListScrollTracking(
                onScroll: { listScrolled = true },
                onOffset: { offset in
                    if !listSettled { settleListSoon() }
                    guard listScrolled else { return }
                    let shown = cardShown(at: offset, height: height, viewport: viewport, chrome: chrome)
                    if shown != index { index = shown }
                }))
            .safeAreaPadding(.top, chrome)
            .mask { listMask(chrome: chrome) }
            .scrollPosition(id: $listIndex, anchor: .center)
            .onChange(of: listIndex) { _, new in
                guard #unavailable(iOS 18), listScrolled, let new else { return }
                index = new
            }
            .onAppear {
                proxy.scrollTo(index, anchor: .center)
                settleListSoon()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { settleList() }
            }
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: Self.edgeWidth)
                .contentShape(Rectangle())
                .gesture(closeSwipe)
        }
    }

    /// Lets the deck go once the list's scroll position has stopped moving.
    private func settleListSoon() {
        settleToken += 1
        let token = settleToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if token == settleToken { settleList() }
        }
    }

    private func settleList() {
        guard fanned, !listSettled else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { listSettled = true }
    }

    private func listMask(chrome: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: max(0, chrome - 8))
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: chrome > 0 ? 32 : 0)
            Color.black
        }
    }

    // MARK: - Pieces

    /// Laid out like a navigation bar rather than being one, since on the iPhone
    /// Duo it turns with the pouch.
    private var topBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(pack.name)
                    .font(.headline)
                Text("Card \(index + 1) of \(verses.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .padding(.horizontal, 60)
            .accessibilityElement(children: .combine)
            HStack {
                Button { close(.closeButton) } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Close")
                .buttonBorderShape(.circle)
                .systemGlassButton()
                Spacer()
                Button { startPractice(from: index) } label: {
                    Text("Practice")
                        .fontWeight(.medium)
                        .frame(height: 30)
                        .padding(.horizontal, 4)
                }
                .systemGlassButton()
            }
        }
        .frame(height: 44)
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 8)
        .opacity(Double(1 - flight))
        .disabled(!fanned)
    }

    /// Fast scroll through the list, on the trailing edge where a thumb reaches.
    private var thumb: some View {
        GeometryReader { area in
            if fanned, verses.count >= 2 {
                VerseFastScrollOverlay(
                    verseCount: verses.count,
                    scrollFraction: Double(index) / Double(verses.count - 1),
                    containerHeight: area.size.height,
                    titleProvider: { verses.indices.contains($0) ? verses[$0].title : "" },
                    referenceProvider: { i in
                        guard verses.indices.contains(i) else { return "" }
                        return "\(verses[i].book) \(verses[i].reference)"
                    },
                    onScrubTo: { i in
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { listIndex = i }
                    })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func cardFace(_ card: PouchSlots.Card, width: CGFloat) -> some View {
        switch card {
        case .verse(let i) where verses.indices.contains(i):
            listCard(i, width: width)
        case .backPage:
            PouchBackPageCard(packName: pack.name, verseCount: verses.count,
                              learntCount: verses.filter(learning.isLearnt).count, width: width)
                .paperAppearance()
        case .verse, .none:
            Color.clear
        }
    }

    private func listCard(_ i: Int, width: CGFloat) -> some View {
        let verse = verses[i]
        let isCurrent = learning.isCurrent(verse)
        return PouchVerseCard(verse: verse, isLearnt: learning.isLearnt(verse), width: width) {
            if isCurrent {
                Button { markComplete(verse, from: .card) } label: {
                    Label("Complete", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(PouchInk.green)
            }
            FavoriteStarButton(verse: verse, alignment: .trailing)
        }
        .paperAppearance()
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Practises from this verse")
        .accessibilityAction { startPractice(from: i) }
        .accessibilityAction(named: FavoritesStore.shared.isFavorite(verse) ? "Unstar" : "Star") {
            toggleStar(verse)
        }
        .accessibilityAction(named: learning.isLearnt(verse) ? "Mark as not learnt" : "Mark as learnt") {
            toggleLearnt(verse)
        }
    }

    @ViewBuilder
    private func cardMenu(_ verse: Verse) -> some View {
        let isFavorite = FavoritesStore.shared.isFavorite(verse)
        Button {
            HapticEngine.light()
            toggleStar(verse)
        } label: {
            Label(isFavorite ? "Unstar" : "Star", systemImage: isFavorite ? "star.slash" : "star")
        }
        Button { toggleLearnt(verse) } label: {
            if learning.isLearnt(verse) {
                Label("Mark as Not Learnt", systemImage: "arrow.uturn.backward")
            } else {
                Label("Mark as Learnt", systemImage: "checkmark.circle")
            }
        }
    }

    private func toggleStar(_ verse: Verse) {
        Analytics.log(.starChanged(starred: !FavoritesStore.shared.isFavorite(verse), from: .menu))
        FavoritesStore.shared.toggle(verse)
    }

    private func toggleLearnt(_ verse: Verse) {
        if learning.isLearnt(verse) {
            learning.unmarkLearnt(verse)
            Analytics.log(.learntChanged(learnt: false, from: .menu))
            HapticEngine.light()
        } else {
            markComplete(verse, from: .menu)
        }
    }

    // MARK: - State

    /// A verse, then the back page after the last one.
    private func card(at i: Int) -> PouchSlots.Card {
        i < 0 ? .none : i < verses.count ? .verse(i) : i == verses.count ? .backPage : .none
    }

    private var slots: PouchSlots {
        func edges(_ n: Int) -> Int { min(7, Int((Double(max(n, 0)) / 5).rounded(.up))) }
        return PouchSlots(top: card(at: index - 1), bottom: card(at: index),
                          topEdges: edges(index - 1), bottomEdges: edges(verses.count - index))
    }

    /// Where the learning cursor sits in this pack, if it does.
    private var currentIndex: Int? {
        verses.firstIndex { learning.isCurrent($0) }
    }

    // MARK: - Actions

    private func appeared() {
        if !fanned { tilt.start() }
        let fromShelf = flight > 0
        if fromShelf {
            withAnimation(.smooth(duration: 0.35)) { flight = 0 }
        }
        guard openness < 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (fromShelf ? 0.08 : 0)) {
            guard !hingeDriven else { return }
            unfoldAndFanOut()
        }
    }

    /// The pouch opens, and as it settles the cards rise out of the pocket and
    /// lay out as the list, then the scrolling list takes over from them.
    private func unfoldAndFanOut() {
        withAnimation(.smooth(duration: 0.4)) { openness = 1 }
        withAnimation(.smooth(duration: 0.4).delay(0.3)) { lift = 1 }
        HapticEngine.play(HapticEngine.packOpen)
        withAnimation(.snappy(duration: 0.4).delay(0.6), completionCriteria: .removed) {
            spread = 1
        } completion: {
            guard openness == 1, lift == 1, spread == 1, !closing, !fanned else { return }
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { listIndex = index; fanned = true }
        }
    }

    /// A touch while the pack is opening goes straight to the list, carrying a
    /// flick on through it.
    private func finishOpening(flick: CGFloat, pitch: CGFloat) {
        guard !fanned, !closing, !hingeShut else { return }
        HapticEngine.stop()
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            flight = 0
            openness = 1
            lift = 1
            spread = 1
            listIndex = index
            fanned = true
        }
        let target = min(max(index - Int((flick / pitch).rounded()), 0), verses.count - 1)
        guard target != index else { return }
        index = target
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.5)) { listIndex = target }
        }
    }

    /// The cards gather back into the pocket, the pouch folds shut and goes back
    /// onto its shelf tile; without one, the screen closes once it's shut.
    private func close(_ how: PackCloseMethod) {
        guard !closing else { return }
        closing = true
        Analytics.log(.packClosed(how: how, seconds: Date().timeIntervalSince(openedAt)))
        if AppMotion.reduceMotion { HapticEngine.light(); dismissOrPutBack(); return }
        HapticEngine.play(HapticEngine.packClose)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { fanned = false; swipeOffset = 0 }
        withAnimation(.snappy(duration: 0.32)) { spread = 0 }
        withAnimation(.smooth(duration: 0.32).delay(0.2)) { lift = 0 }
        withAnimation(.smooth(duration: 0.34).delay(0.4), completionCriteria: .logicallyComplete) {
            openness = 0
        } completion: {
            guard shelf != nil, onPutBack != nil else { dismissOrPutBack(); return }
            withAnimation(.smooth(duration: 0.35), completionCriteria: .logicallyComplete) {
                flight = 1
            } completion: { HapticEngine.soft(); dismissOrPutBack() }
        }
    }

    private func dismissOrPutBack() {
        if shelf != nil, let onPutBack { onPutBack() } else { dismiss() }
    }

    /// A swipe in from the leading edge closes the pack; the list follows the
    /// finger until it does or springs back.
    private var closeSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                if swipeAxis == nil { swipeAxis = abs(dx) > abs(dy) * 1.5 ? .horizontal : .vertical }
                guard swipeAxis == .horizontal else { listScrolled = true; return }
                swipeOffset = max(0, dx) * 0.6
            }
            .onEnded { value in
                defer { swipeAxis = nil }
                guard swipeAxis == .horizontal else { return }
                let dx = value.translation.width
                let flick = value.predictedEndTranslation.width
                if dx > 80 || flick > 220 {
                    close(.edgeSwipe)
                } else {
                    withAnimation(AppMotion.control) { swipeOffset = 0 }
                }
            }
    }

    /// The list's full height: its cards and the gap above and below them.
    private func listContentHeight(cardHeight: CGFloat) -> CGFloat {
        CGFloat(verses.count) * (cardHeight + AppLayout.spacing) + AppLayout.spacing
    }

    /// Where the list puts card `i` when it scrolls it as near the middle as it
    /// will go, so the cards fanning out land where the list then shows them.
    private func listMidY(of i: Int, height: CGFloat, viewport: CGFloat, chrome: CGFloat) -> CGFloat {
        let visible = viewport - chrome
        let mid = AppLayout.spacing + CGFloat(i) * (height + AppLayout.spacing) + height / 2
        let most = max(0, listContentHeight(cardHeight: height) - visible)
        return chrome + mid - min(max(0, mid - visible / 2), most)
    }

    /// The card the counter names at a scroll offset: the one in the middle,
    /// except within half a screen of either end, where it slides to the first
    /// or last card.
    private func cardShown(at offset: CGFloat, height: CGFloat, viewport: CGFloat, chrome: CGFloat) -> Int {
        let visible = viewport - chrome
        let most = listContentHeight(cardHeight: height) - visible
        guard most > 0 else { return index }
        let half = visible / 2
        let reading = offset + (offset < most / 2 ? min(max(offset, 0), half)
                                                  : max(half, visible - max(most - offset, 0)))
        let i = Int((reading - AppLayout.spacing / 2) / (height + AppLayout.spacing))
        return min(max(i, 0), verses.count - 1)
    }

    private func startPractice(from i: Int) {
        practice = TestSession.practice(verses, from: i)
    }

    private func markComplete(_ verse: Verse, from source: VerseActionSource) {
        learning.markLearnt(verse)
        Analytics.log(.learntChanged(learnt: true, from: source))
        HapticEngine.success()
        undoToastState = .markedComplete(verse, learning: learning)
    }

    // MARK: Hinge

    /// Shutting the Duo folds the pouch and shows its cover; opening it fans the
    /// cards out again. In between the screen folds with the hinge, so the pouch
    /// stays flat on it.
    private func hingeMoved(closed: Bool?) {
        guard let closed else { hingeDriven = false; hingeShut = false; return }
        hingeDriven = true
        withAnimation(AppMotion.content) { hingeShut = closed }
        if closed {
            HapticEngine.stop()
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                fanned = false
                lift = 0
                spread = 0
                openness = 0
            }
        } else if openness < 1, !closing {
            unfoldAndFanOut()
        }
    }

    /// Where a folding screen's fold crosses this view.
    private static func screenFold(in geo: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        let bounds = CGRect(origin: .zero, size: geo.size)
        return geo.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { bounds.intersects($0) }
    }
}

/// The shut pouch between its tile on the shelf (`flight` 1) and its place in
/// front of you (0), the tile handing over to the pouch near the shelf.
private struct ShelfFlight<Tile: View>: ViewModifier, Animatable {
    var flight: CGFloat
    let scale: CGFloat
    let anchor: UnitPoint
    let offset: CGSize
    let tile: Tile

    var animatableData: CGFloat {
        get { flight }
        set { flight = newValue }
    }

    func body(content: Content) -> some View {
        let tileShows = min(1, max(0, flight * 3 - 2))
        content
            .opacity(Double(min(1, (1 - flight) * 4)))
            .overlay {
                if tileShows > 0 {
                    tile.opacity(Double(tileShows)).allowsHitTesting(false)
                }
            }
            .scaleEffect(1 + (scale - 1) * flight, anchor: anchor)
            .offset(x: offset.width * flight, y: offset.height * flight)
    }
}

/// The shut Duo's front screen: the pack's cover under the plastic, turned to
/// read the right way up with the folded device held sideways.
private struct FrontCover: View {
    let pack: Pack
    let shine: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let long = geo.size.height, short = geo.size.width
            let style = PlasticStyle(colorScheme)
            let rim = max(8, short * 0.035)
            let room = CGSize(width: long - 2 * rim - 24, height: short - 2 * rim - 24)
            let cardWidth = min(room.width, room.height * 5 / 3)
            ZStack {
                Color(.systemGroupedBackground)
                style.tint
                PackCover(pack: pack, cornerRadius: 2, showsShadow: false)
                    .frame(width: cardWidth, height: cardWidth * 3 / 5)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: style.shine, location: 0.14),
                    .init(color: .clear, location: 0.3),
                    .init(color: style.shine.opacity(0.3), location: 0.46),
                    .init(color: .clear, location: 0.6),
                ], startPoint: UnitPoint(x: -0.5 + shine * 0.6, y: 0),
                   endPoint: UnitPoint(x: 0.6 + shine * 0.6, y: 1))
                RoundedRectangle(cornerRadius: rim * 1.6, style: .continuous)
                    .inset(by: rim / 2)
                    .stroke(style.rim, lineWidth: rim)
                RoundedRectangle(cornerRadius: rim * 1.6, style: .continuous)
                    .inset(by: rim)
                    .stroke(style.edgeShade.opacity(0.7), lineWidth: 0.6)
            }
            .frame(width: long, height: short)
            .rotationEffect(.degrees(-90))
            .frame(width: short, height: long)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name), shut. Open the phone to open the pack.")
    }
}

/// Reports whether the hinge is shut, or `nil` without one (iOS 27.1 and later).
private struct FollowsHinge: ViewModifier {
    let onChange: (Bool?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, new in
                onChange(new.hinge.map { $0.status == .closed })
            }
        } else {
            content
        }
    }
}

/// How far the list has scrolled, and when the user starts scrolling it. Before
/// iOS 18 there's neither, and the counter follows the middle card instead.
private struct ListScrollTracking: ViewModifier {
    let onScroll: () -> Void
    let onOffset: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { onScroll() }
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                    onOffset(offset)
                }
        } else {
            content
        }
    }
}
