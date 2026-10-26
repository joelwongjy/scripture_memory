import SwiftUI

/// A pack as the real thing: a clear plastic pouch folded in the middle, with
/// the cards in two inner pockets.
///
/// The bottom pocket holds the card you're on and everything after it; turning
/// a card flips it over the fold into the top pocket. Tap the pouch to fan the
/// cards out into a list, and tap a card to gather them back on it.
///
/// On the iPhone Duo the device is the pouch: the hinge opens and shuts it, each
/// pocket fills one half of the screen, and shut, the front screen is its cover.
struct PouchView: View {
    let pack: Pack
    /// The pack's tile on the shelf, in global coordinates, to fly out of and
    /// back into.
    let shelf: CGRect?
    /// Takes the screen away once the pouch is back on the shelf.
    var onPutBack: (() -> Void)?

    @State private var index: Int
    @State private var openness: CGFloat
    @State private var unfolding = false
    @State private var turn: CGFloat = 0
    @State private var turning: Int?
    @State private var drag: DragMode = .none
    /// 0 with the stack in its pocket, 1 with it out over the pouch.
    @State private var lift: CGFloat = 0
    /// 0 with the cards out in a stack, 1 with them laid out as the list.
    @State private var spread: CGFloat = 0
    /// The cards are fanned out and the scrolling list has taken over.
    @State private var fanned = false
    @State private var gathering = false
    /// The card centred in the fanned list.
    @State private var listIndex: Int?
    /// 1 with the pouch shut on its shelf tile, 0 with it in front of you.
    @State private var flight: CGFloat
    @State private var hingeDriven = false
    @State private var hingeShut = false
    @State private var practice: TestSession?
    @State private var undoToastState: UndoToastState?
    @AppStorage("pouch.turnDemoCount.v1") private var turnDemoCount = 0

    @StateObject private var tilt = TiltMonitor()
    @ObservedObject private var learning = LearningStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private enum DragMode { case none, opening, forward, backward }

    /// The top controls' height under the safe area: a 44pt control and its padding.
    private static let chromeHeight: CGFloat = 60

    private var verses: [Verse] { pack.verses }

    init(pack: Pack, startIndex: Int, shelf: CGRect? = nil, onPutBack: (() -> Void)? = nil) {
        self.pack = pack
        self.shelf = shelf
        self.onPutBack = onPutBack
        _index = State(initialValue: min(max(startIndex, 0), pack.verses.count))
        _openness = State(initialValue: AppMotion.reduceMotion ? 1 : 0)
        _flight = State(initialValue: shelf != nil && !AppMotion.reduceMotion ? 1 : 0)
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
        .onDisappear {
            tilt.stop()
            let current = min(index, verses.count - 1)
            if verses.indices.contains(current) { PackPositions.save(verses[current], inPack: pack.name) }
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
    /// controls reach, which the fanned list keeps its cards clear of.
    @ViewBuilder
    private func scene(_ geo: GeometryProxy, fold: CGFloat?, turned: Bool, chrome: CGFloat) -> some View {
        let foldY = fold.flatMap { $0 > 0 && $0 < geo.size.height ? $0 : nil }
        let m = foldY.map { PouchMetrics(width: geo.size.width, halfHeight: min($0, geo.size.height - $0)) }
            ?? PouchMetrics(fitting: CGSize(width: geo.size.width, height: geo.size.height - 12))
        let sceneTop = foldY.map { $0 - m.halfHeight } ?? (geo.size.height - 2 * m.halfHeight) / 2

        let listWidth = min(geo.size.width - 2 * AppLayout.screenMargin, 600)
        let listHeight = listWidth / PouchMetrics.cardAspect

        let coverCenter = CGPoint(x: geo.size.width / 2, y: sceneTop + m.halfHeight / 2 + m.cardFrame.midY)
        let area = geo.frame(in: .global)
        let tile = (turned ? nil : shelf) ?? CGRect(x: area.minX + coverCenter.x - m.cardWidth / 2,
                                                    y: area.minY + coverCenter.y - m.cardHeight / 2,
                                                    width: m.cardWidth, height: m.cardHeight)
        let shelfScale = tile.width / m.cardWidth

        ZStack {
            PouchScene(openness: openness, turn: turn, lift: lift, m: m,
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
                .contentShape(Rectangle())
                .onTapGesture { tapped() }
                .gesture(dragGesture(m: m, splitY: sceneTop + m.halfHeight))
                .allowsHitTesting(lift == 0 && flight == 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityDescription)
                .accessibilityHint(openness < 1 ? "Double-tap to open the pouch"
                                                 : "Double-tap to fan the cards out. Swipe up or down to turn cards")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: turnForward()
                    case .decrement: turnBack()
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: openness < 1 ? "Open the pouch" : "Fold the pouch") { toggleFold() }
                .accessibilityHidden(lift > 0)

            LiftedDeck(lift: lift, spread: spread,
                       pocketCenter: CGPoint(x: geo.size.width / 2, y: sceneTop + m.halfHeight + m.cardFrame.midY),
                       listCenter: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                       pocketWidth: m.cardWidth, listWidth: listWidth,
                       listPitch: listHeight + AppLayout.spacing,
                       previous: card(at: index - 1), front: card(at: index), next: card(at: index + 1),
                       edges: min(5, Int((Double(max(verses.count - index - 1, 0)) / 8).rounded(.up))),
                       face: { cardFace($0, width: $1) })
                .opacity(fanned ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if fanned {
                fannedList(width: listWidth, height: listHeight, viewport: geo.size.height, chrome: chrome)
                    .transition(.opacity)
            }
        }
    }

    private func fannedList(width: CGFloat, height: CGFloat, viewport: CGFloat, chrome: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: AppLayout.spacing) {
                ForEach(verses.indices, id: \.self) { i in
                    listCard(i, width: width)
                        .frame(width: width, height: height)
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                        .contentShape(Rectangle())
                        .onTapGesture { gather(at: i) }
                        .id(i)
                }
            }
            .scrollTargetLayout()
            .frame(maxWidth: .infinity)
            .padding(.vertical, max(0, (viewport - chrome - height) / 2))
        }
        .safeAreaPadding(.top, chrome)
        .mask {
            VStack(spacing: 0) {
                Color.clear.frame(height: max(0, chrome - 8))
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: chrome > 0 ? 32 : 0)
                Color.black
            }
        }
        .scrollPosition(id: $listIndex, anchor: .center)
        .onChange(of: listIndex) { _, new in
            guard let new, new != index else { return }
            index = new
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(pack.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(positionLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(AppMotion.control, value: positionLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .floatingGlass(in: Capsule())
            HStack {
                Button { close() } label: {
                    Image(systemName: "xmark").floatingGlassButton()
                }
                .accessibilityLabel("Close")
                Spacer()
                Button { startPractice() } label: {
                    Text("Practice")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .floatingGlass(in: Capsule())
                }
                .disabled(openness < 1)
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 8)
        .opacity(Double(1 - flight))
    }

    /// The fast way through the pack: over the pouch it riffles straight to any
    /// card; fanned out, it scrolls the list.
    private var thumb: some View {
        GeometryReader { area in
            if verses.count >= 2, openness == 1, lift == 0 || fanned {
                VerseFastScrollOverlay(
                    verseCount: verses.count,
                    scrollFraction: Double(min(index, verses.count - 1)) / Double(verses.count - 1),
                    containerHeight: area.size.height,
                    titleProvider: { verses.indices.contains($0) ? verses[$0].title : "" },
                    referenceProvider: { i in
                        guard verses.indices.contains(i) else { return "" }
                        return "\(verses[i].book) \(verses[i].reference)"
                    },
                    onScrubTo: { i in
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            if fanned { listIndex = i } else if turning == nil { index = i }
                        }
                    },
                    alwaysVisible: !fanned)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .transition(.opacity)
            }
        }
        .opacity(Double(1 - flight))
        .animation(AppMotion.content, value: fanned)
    }

    @ViewBuilder
    private func cardFace(_ card: PouchSlots.Card, width: CGFloat) -> some View {
        switch card {
        case .verse(let i) where verses.indices.contains(i):
            PouchVerseCard(verse: verses[i], isLearnt: learning.isLearnt(verses[i]), width: width)
                .paperAppearance()
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
            FavoriteStarButton(verse: verse)
            if isCurrent {
                Button { markComplete(verse) } label: {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.systemGreen), in: Capsule())
                }
            }
        }
        .paperAppearance()
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Puts the cards back in the pouch on this one")
        .accessibilityAction { gather(at: i) }
        .accessibilityAction(named: FavoritesStore.shared.isFavorite(verse) ? "Unstar" : "Star") {
            FavoritesStore.shared.toggle(verse)
        }
        .accessibilityAction(named: "Mark as complete") {
            if isCurrent { markComplete(verse) }
        }
    }

    // MARK: - State

    /// A verse, then the back page after the last one.
    private func card(at i: Int) -> PouchSlots.Card {
        i < 0 ? .none : i < verses.count ? .verse(i) : i == verses.count ? .backPage : .none
    }

    private var slots: PouchSlots {
        let topIndex = (turning ?? index) - 1
        let bottomIndex = turning.map { $0 + 1 } ?? index
        func edges(_ n: Int) -> Int { min(7, Int((Double(max(n, 0)) / 5).rounded(.up))) }
        return PouchSlots(top: card(at: topIndex), bottom: card(at: bottomIndex), turning: turning,
                          topEdges: edges(topIndex),
                          bottomEdges: bottomIndex < verses.count ? edges(verses.count - bottomIndex) : 0)
    }

    private var positionLabel: String {
        index >= verses.count ? "End of the pack" : "Card \(index + 1) of \(verses.count)"
    }

    private var accessibilityDescription: String {
        if openness < 1 { return "\(pack.name) pouch, folded shut" }
        guard verses.indices.contains(index) else { return "\(pack.name) pouch, end of the pack" }
        let v = verses[index]
        return "\(positionLabel). \(v.title), \(v.book) \(v.reference). \(v.verse)"
    }

    // MARK: - Actions

    private func appeared() {
        tilt.start()
        let fromShelf = flight > 0
        if fromShelf {
            withAnimation(.smooth(duration: 0.45)) { flight = 0 }
        }
        guard openness < 1 else { return }
        unfolding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + (fromShelf ? 0.3 : 0.1)) {
            guard !hingeDriven else { unfolding = false; return }
            withAnimation(.smooth(duration: 0.6), completionCriteria: .logicallyComplete) {
                openness = 1
            } completion: {
                unfolding = false
                demoTurn()
            }
        }
    }

    /// Off the shelf, the pouch folds shut and goes back onto its tile;
    /// otherwise the screen just closes.
    private func close() {
        guard shelf != nil, let onPutBack, !AppMotion.reduceMotion else { dismiss(); return }
        HapticEngine.light()
        fanned = false
        withAnimation(.smooth(duration: 0.4)) {
            openness = 0
            lift = 0
            spread = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.smooth(duration: 0.45), completionCriteria: .logicallyComplete) {
                flight = 1
            } completion: { onPutBack() }
        }
    }

    private func startPractice() {
        practice = TestSession.practice(verses, from: min(index, verses.count - 1))
    }

    private func markComplete(_ verse: Verse) {
        learning.markLearnt(verse)
        HapticEngine.success()
        undoToastState = .markedComplete(verse, learning: learning)
    }

    private func toggleFold() {
        HapticEngine.light()
        fanned = false
        withAnimation(AppMotion.reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.65)) {
            openness = openness < 1 ? 1 : 0
            lift = 0
            spread = 0
        }
    }

    /// Shut, a tap opens it (unless the hinge does); open, it fans the cards out.
    private func tapped() {
        guard turning == nil, !unfolding else { return }
        if openness < 1 {
            if !hingeDriven { toggleFold() }
            return
        }
        fanOut()
    }

    // MARK: Fanning out

    /// The cards rise out of the pocket and lay out as the list, then the
    /// scrolling list takes over from them.
    private func fanOut() {
        guard openness == 1, !unfolding, turning == nil, lift == 0 else { return }
        let current = min(index, verses.count - 1)
        guard verses.indices.contains(current) else { return }
        index = current
        listIndex = current
        HapticEngine.medium()
        if AppMotion.reduceMotion { lift = 1; spread = 1; fanned = true; return }
        withAnimation(.snappy(duration: 0.5), completionCriteria: .logicallyComplete) {
            lift = 1
            spread = 1
        } completion: {
            guard openness == 1, lift == 1, spread == 1 else { return }
            withAnimation(.easeOut(duration: 0.12)) { fanned = true }
        }
    }

    /// Card `i` comes to the middle, the cards close up on it, and the stack
    /// slides back into the pocket.
    private func gather(at i: Int) {
        guard fanned, !gathering else { return }
        gathering = true
        HapticEngine.light()
        let settle = {
            index = i
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { fanned = false }
            if AppMotion.reduceMotion { lift = 0; spread = 0; gathering = false; return }
            withAnimation(.snappy(duration: 0.4), completionCriteria: .logicallyComplete) {
                spread = 0
            } completion: {
                withAnimation(.snappy(duration: 0.45)) { lift = 0 }
                gathering = false
            }
        }
        guard listIndex != i, !AppMotion.reduceMotion else { settle(); return }
        withAnimation(.snappy(duration: 0.3), completionCriteria: .logicallyComplete) {
            listIndex = i
        } completion: { settle() }
    }

    // MARK: Turning

    /// The first couple of times the pouch opens, the front card lifts partway
    /// over the fold and settles back.
    private func demoTurn() {
        guard turnDemoCount < 2, !AppMotion.reduceMotion, openness == 1, turning == nil,
              lift == 0, index < verses.count else { return }
        turnDemoCount += 1
        turning = index
        turn = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.smooth(duration: 0.45), completionCriteria: .logicallyComplete) {
                turn = 0.22
            } completion: {
                cancelTurn(forward: true)
            }
        }
    }

    private func turnForward() {
        guard openness == 1, turning == nil, index < verses.count else { return }
        turning = index
        turn = 0
        DispatchQueue.main.async { finishTurn(forward: true) }
    }

    private func turnBack() {
        guard openness == 1, turning == nil, index > 0 else { return }
        turning = index - 1
        turn = 1
        DispatchQueue.main.async { finishTurn(forward: false) }
    }

    /// Carries a turn through to the other pocket, then makes it the new state.
    private func finishTurn(forward: Bool) {
        let commit = {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                index += forward ? 1 : -1
                turning = nil
                turn = 0
            }
            HapticEngine.light()
        }
        if AppMotion.reduceMotion { commit(); return }
        withAnimation(.snappy(duration: 0.45), completionCriteria: .logicallyComplete) {
            turn = forward ? 1 : 0
        } completion: { commit() }
    }

    /// Lets go of a turn that didn't go far enough: the card falls back.
    private func cancelTurn(forward: Bool) {
        withAnimation(.snappy(duration: 0.3), completionCriteria: .logicallyComplete) {
            turn = forward ? 0 : 1
        } completion: {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { turning = nil; turn = 0 }
        }
    }

    private func dragGesture(m: PouchMetrics, splitY: CGFloat) -> some Gesture {
        let span = m.cardHeight * 1.5
        return DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dy = value.translation.height
                if drag == .none {
                    if openness < 1 {
                        drag = .opening
                    } else if turning == nil, value.startLocation.y >= splitY, dy < 0, index < verses.count {
                        drag = .forward
                        turning = index
                    } else if turning == nil, value.startLocation.y < splitY, dy > 0, index > 0 {
                        drag = .backward
                        turning = index - 1
                    }
                }
                switch drag {
                case .opening:  openness = min(1, max(0, -dy / m.halfHeight))
                case .forward:  turn = min(1, max(0, -dy / span))
                case .backward: turn = 1 - min(1, max(0, dy / span))
                case .none:     break
                }
            }
            .onEnded { value in
                let flick = value.predictedEndTranslation.height
                switch drag {
                case .opening:
                    let open = openness > 0.3 || -flick > m.halfHeight * 0.5
                    withAnimation(.smooth(duration: 0.5)) { openness = open ? 1 : 0 }
                    if open { HapticEngine.light() }
                case .forward:
                    if turn > 0.45 || -flick > span * 0.6 { finishTurn(forward: true) } else { cancelTurn(forward: true) }
                case .backward:
                    if turn < 0.55 || flick > span * 0.6 { finishTurn(forward: false) } else { cancelTurn(forward: false) }
                case .none:
                    break
                }
                drag = .none
            }
    }

    // MARK: Hinge

    /// The screen folds with the hinge, so the pouch stays flat on it; only
    /// shutting the hinge changes anything.
    private func hingeMoved(closed: Bool?) {
        guard let closed else { hingeDriven = false; hingeShut = false; return }
        hingeDriven = true
        withAnimation(AppMotion.content) { hingeShut = closed }
        let wasShut = openness < 1
        if closed {
            fanned = false
            lift = 0
            spread = 0
        }
        withAnimation(.smooth(duration: 0.25), completionCriteria: .logicallyComplete) {
            openness = closed ? 0 : 1
        } completion: {
            if wasShut, !closed { demoTurn() }
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
