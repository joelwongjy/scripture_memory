import SwiftUI

/// A pack: its cards as a list of the printed cards, which come out of and go
/// back into the pack's clear plastic pouch.
///
/// Opening, the pouch comes off its shelf tile, unfolds and fans its cards out
/// into the list. Closing (the ×, a swipe in from the leading edge, or a swipe
/// left across the list) gathers them back in and folds it shut. Tap a card to
/// lift it out and turn it over to its reference, tap it to check the verse,
/// and tap outside to put it back.
struct PouchView: View {
    let pack: Pack
    /// The pack's tile on the shelf, in global coordinates, to fly out of and
    /// back into. Asked again on the way back, as the tile moves if the screen
    /// has rotated since.
    let shelf: (() -> CGRect)?
    /// Takes the screen away once the pouch is back on the shelf.
    var onPutBack: (() -> Void)?
    /// Unfolds, fans out and folds shut. Off, the pack opens on its list and
    /// closes with the screen, as it does with Reduce Motion.
    let animatesPouch: Bool

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
    @State private var openTime = ActiveTimer()
    /// The card centred in the list.
    @State private var listIndex: Int?
    @State private var listScrolled = false
    @State private var listFraction: Double?
    @State private var scrubFraction: Double?
    /// The list following a horizontal swipe, before it closes or springs back.
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeAxis: Axis?
    /// 1 with the pouch shut on its shelf tile, 0 with it in front of you.
    @State private var flight: CGFloat
    @State private var practice: TestSession?
    @State private var lastPractised: Verse?
    @State private var lifted: LiftedCard?
    /// 1 with the lifted card in the middle of the screen, 0 in its slot.
    @State private var liftAmount: CGFloat = 0
    /// 0 with the lifted card showing its verse, 180 its reference.
    @State private var liftedAngle: Double = 0
    @State private var liftedDrag: CGSize = .zero
    @State private var flipCount = 0
    @State private var undoToastState: UndoToastState?
    @AppStorage("pouch.jumpLabelShown.v1") private var jumpLabelShown = false
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @State private var practiceWidth: CGFloat = 0
    @State private var barWidth: CGFloat = 0
    @State private var titleWidth: CGFloat = 0

    @StateObject private var tilt = TiltMonitor()
    @ObservedObject private var learning = LearningStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private static let screenSpace = "pouchScreen"
    private static let sideButtonSize: CGFloat = 44
    /// A side inset that holds a button and its margins: the buttons move into it.
    private static let railWidth = sideButtonSize + 2 * AppLayout.screenMargin
    private static let cardSwipeDistance: CGFloat = 90
    private static let cardSwipeFlick: CGFloat = 220

    /// How far in from the leading edge a swipe counts as the edge swipe.
    private static let edgeWidth: CGFloat = 28

    private var hasVersionChoice: Bool { BibleVersion.niv11PackNames.contains(pack.name) }

    private var verses: [Verse] {
        guard hasVersionChoice else { return pack.verses }
        return (bibleVersion.packs.first { $0.name == pack.name } ?? pack).verses
    }

    init(pack: Pack, startIndex: Int, shelf: (() -> CGRect)? = nil, animatesPouch: Bool = true,
         onPutBack: (() -> Void)? = nil) {
        let reduce = AppMotion.reduceMotion || !animatesPouch
        let start = min(max(startIndex, 0), max(pack.verses.count - 1, 0))
        self.pack = pack
        self.shelf = shelf
        self.onPutBack = onPutBack
        self.animatesPouch = animatesPouch
        _index = State(initialValue: start)
        _listIndex = State(initialValue: nil)
        _openness = State(initialValue: reduce ? 1 : 0)
        _lift = State(initialValue: reduce ? 1 : 0)
        _spread = State(initialValue: reduce ? 1 : 0)
        _fanned = State(initialValue: reduce)
        _flight = State(initialValue: shelf != nil && !reduce ? 1 : 0)
    }

    var body: some View {
        GeometryReader { safe in
            pouch(insets: safe.safeAreaInsets, safeSize: safe.size)
                .ignoresSafeArea()
        }
        .background(Color(.systemGroupedBackground).opacity(Double(1 - flight)).ignoresSafeArea())
        .undoToast($undoToastState)
        .fullScreenCover(item: $practice, onDismiss: returnToPractisedCard) { session in
            TestSessionView(session: session, onSessionEnded: { practice = nil },
                            onCardShown: { lastPractised = $0 })
        }
        .onAppear { appeared() }
        .analyticsScreen(.pack)
        .onChange(of: fanned) { _, out in out ? tilt.stop() : tilt.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { openTime.resume() } else { openTime.pause() }
        }
        .onDisappear {
            tilt.stop()
            if verses.indices.contains(index) { PackPositions.save(verses[index], inPack: pack.name) }
        }
    }

    // MARK: - Layout

    private func pouch(insets: EdgeInsets, safeSize: CGSize) -> some View {
        let columns = PackListLayout.columns(forWidth: safeSize.width - 2 * AppLayout.screenMargin)
        let hasRail = max(insets.leading, insets.trailing) >= Self.railWidth

        return ZStack {
            VStack(spacing: 0) {
                topBar(columns: columns, showsButtons: !hasRail)
                GeometryReader { geo in scene(geo, below: insets.bottom) }
                    .overlay { thumb }
            }
            .padding(insets)
            .overlay(alignment: insets.leading > insets.trailing ? .leading : .trailing) {
                if hasRail {
                    sideButtons
                        .frame(width: max(insets.leading, insets.trailing))
                }
            }
            .blur(radius: 14 * liftAmount)
            .overlay {
                Color.black.opacity((colorScheme == .dark ? 0.68 : 0.16) * Double(liftAmount))
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(lifted == nil)
            .accessibilityHidden(lifted != nil)

            if let lifted {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: putCardBack)
                        .accessibilityHidden(true)
                    liftedCard(lifted, area: CGRect(origin: CGPoint(x: insets.leading, y: insets.top), size: safeSize))
                }
                .gesture(liftedSwipe)
            }
        }
        .coordinateSpace(name: Self.screenSpace)
    }

    private func liftedCard(_ card: LiftedCard, area: CGRect) -> some View {
        let verse = verses[card.index]
        let showsReference = liftedAngle > 90
        return LiftedCardView(verse: verse, isLearnt: learning.isLearnt(verse), source: card.source,
                              area: area, lift: liftAmount, angle: liftedAngle, drag: liftedDrag,
                              onFlip: flipLiftedCard)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(showsReference ? "\(verse.book) \(verse.reference)"
                                               : "\(verse.title), \(verse.book) \(verse.reference). \(verse.verse)")
            .accessibilityHint("Turns the card over")
            .accessibilityAddTraits([.isButton, .isModal])
            .accessibilityAction { flipLiftedCard() }
            .accessibilityAction(named: "Put Back", putCardBack)
            .accessibilityAction(.escape, putCardBack)
    }

    /// The pouch and the cards out of it.
    @ViewBuilder
    private func scene(_ geo: GeometryProxy, below: CGFloat) -> some View {
        let layout = PackListLayout(width: geo.size.width - 2 * AppLayout.screenMargin,
                                    spacing: AppLayout.spacing)
        let listHeight = (layout.cardWidth / PouchMetrics.cardAspect * displayScale).rounded() / displayScale

        ZStack {
            if fanned {
                fannedList(layout: layout, height: listHeight, viewport: geo.size.height + below,
                           below: below)
                    .offset(x: swipeOffset)
                    .opacity(listSettled ? 1 : 0)
            }
            if !fanned || !listSettled {
                pouchAndDeck(geo, below: below, layout: layout, listHeight: listHeight)
            }
        }
        .onChange(of: fanned) { _, out in if !out { listSettled = false } }
        .overlay(alignment: .bottomTrailing) {
            if fanned, let current = currentIndex, layout.row(of: index) != layout.row(of: current) {
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
    private func pouchAndDeck(_ geo: GeometryProxy, below: CGFloat, layout: PackListLayout,
                              listHeight: CGFloat) -> some View {
        let m = PouchMetrics(fitting: CGSize(width: geo.size.width, height: geo.size.height - 12),
                             widthLimit: layout.pouchWidthLimit)
        let sceneTop = (geo.size.height - 2 * m.halfHeight) / 2

        let coverCenter = CGPoint(x: geo.size.width / 2, y: sceneTop + m.halfHeight / 2 + m.cardFrame.midY)
        let area = geo.frame(in: .global)
        let tile = shelf?() ?? CGRect(x: area.minX + coverCenter.x - m.cardWidth / 2,
                                   y: area.minY + coverCenter.y - m.cardHeight / 2,
                                   width: m.cardWidth, height: m.cardHeight)
        let shelfScale = tile.width / m.cardWidth

        PouchScene(openness: openness, lift: lift, m: m,
                   style: PlasticStyle(colorScheme), slots: slots, tilt: tilt.roll,
                   face: { cardFace($0, width: m.cardWidth) },
                   cover: { PackCover(pack: pack, cornerRadius: 2, showsShadow: false)
                                .frame(width: m.cardWidth) })
            .frame(width: geo.size.width, height: geo.size.height)
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
                   listCenter: CGPoint(x: geo.size.width / 2 + layout.centerOffset(ofCard: index),
                                       y: listMidY(of: index, layout: layout, height: listHeight,
                                                   viewport: geo.size.height + below, below: below)),
                   pocketWidth: m.cardWidth, listWidth: layout.cardWidth,
                   rowPitch: listHeight + AppLayout.spacing,
                   layout: layout, frontCard: index,
                   around: { $0 == 0 ? card(at: index) : verses.indices.contains(index + $0) ? .verse(index + $0) : .none },
                   edges: min(5, Int((Double(max(verses.count - index - 1, 0)) / 8).rounded(.up))),
                   face: { cardFace($0, width: $1) })
            .mask { Color.black.padding(.bottom, -below) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        if !closing {
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    finishOpening(flick: value.predictedEndTranslation.height,
                                  pitch: listHeight + AppLayout.spacing, columns: layout.columns)
                })
        }
    }

    @ViewBuilder
    private func listCards(layout: PackListLayout, height: CGFloat) -> some View {
        if layout.columns == 1 {
            LazyVStack(spacing: layout.spacing) {
                listCells(width: layout.cardWidth, height: height)
            }
            .scrollTargetLayout()
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.cardWidth), spacing: layout.spacing),
                                     count: layout.columns),
                      spacing: layout.spacing) {
                listCells(width: layout.cardWidth, height: height)
            }
            .scrollTargetLayout()
        }
    }

    private func listCells(width: CGFloat, height: CGFloat) -> some View {
        ForEach(verses.indices, id: \.self) { i in
            GeometryReader { cell in
                let lift = { liftCard(i, from: cell.frame(in: .named(Self.screenSpace))) }
                Button(action: lift) {
                    listCard(i, width: width, onLift: lift)
                        .frame(width: width, height: height)
                        .listCardShadow()
                }
                .buttonStyle(CardButtonStyle())
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 2, style: .continuous))
                .contextMenu { cardMenu(i) }
            }
            .frame(width: width, height: height)
            .opacity(lifted?.index == i ? 0 : 1)
            .id(i)
        }
    }

    private func fannedList(layout: PackListLayout, height: CGFloat, viewport: CGFloat,
                            below: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                listCards(layout: layout, height: height)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppLayout.spacing)
                    .padding(.bottom, below)
            }
            .modifier(ListScrollTracking(
                onScroll: { listScrolled = true },
                onOffset: { offset in
                    if !listSettled { settleListSoon() }
                    let most = listContentHeight(layout: layout, cardHeight: height, below: below) - viewport
                    if most > 0 { listFraction = Double(min(max(offset / most, 0), 1)) }
                    guard listScrolled else { return }
                    let shown = cardShown(at: offset, layout: layout, height: height, viewport: viewport, below: below)
                    if shown != index { index = shown }
                }))
            .ignoresSafeArea(.container, edges: below > 0 ? .bottom : [])
            .mask { Color.black.padding(.bottom, -below) }
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
            .onChange(of: layout) { _, _ in
                dropLiftedCard()
                proxy.scrollTo(index, anchor: .center)
            }
            .onChange(of: scrubFraction) { _, fraction in
                guard let fraction else { return }
                scrub(proxy, to: fraction, layout: layout, height: height, viewport: viewport, below: below)
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

    // MARK: - Pieces

    private func topBar(columns: Int, showsButtons: Bool) -> some View {
        let gap = showsButtons ? AppLayout.spacing / 2 : 0
        let span = PackListLayout.titleSpan(barWidth: barWidth,
                                            leading: showsButtons ? Self.sideButtonSize : 0,
                                            trailing: showsButtons ? practiceWidth : 0,
                                            title: titleWidth, gap: gap)
        return ZStack(alignment: .leading) {
            title(columns: columns, wraps: titleWidth > span.width)
                .frame(width: span.width > 0 ? span.width : nil)
                .offset(x: span.x)
            if showsButtons {
                HStack {
                    closeButton
                    Spacer()
                    Button { startPractice(from: index) } label: {
                        Text("Practice")
                            .fontWeight(.medium)
                            .frame(height: 30)
                            .padding(.horizontal, 4)
                    }
                    .systemGlassButton()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { practiceWidth = $0 }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barWidth = $0 }
        .background {
            title(columns: columns, wraps: false)
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titleWidth = $0 }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 8)
        .opacity(Double(1 - flight))
        .disabled(!fanned)
    }

    private func title(columns: Int, wraps: Bool) -> some View {
        VStack(spacing: 1) {
            if hasVersionChoice {
                if wraps {
                    VStack(spacing: 2) { packName; versionPill }
                } else {
                    HStack(spacing: 6) { packName; versionPill }
                }
            } else {
                packName
            }
            Text([pack.seriesCode, PackListLayout.positionLabel(card: index, count: verses.count, columns: columns)]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .accessibilityElement(children: hasVersionChoice ? .contain : .combine)
    }

    private var packName: some View {
        Text(pack.shortName)
            .font(.headline)
            .minimumScaleFactor(0.85)
    }

    private var versionPill: some View {
        Text(bibleVersion.displayName)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .fixedSize()
            .layoutPriority(1)
            .accessibilityHidden(true)
            .overlay {
                Menu { versionPicker } label: {
                    Color.clear.contentShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("Bible Version")
                .accessibilityValue(bibleVersion.displayName)
            }
    }

    private var versionPicker: some View {
        Picker("Bible Version", selection: Binding(get: { bibleVersion }, set: chooseVersion)) {
            ForEach(BibleVersion.allCases, id: \.self) { version in
                Text(version.displayName).tag(version)
            }
        }
        .pickerStyle(.inline)
    }

    private func chooseVersion(_ version: BibleVersion) {
        guard version != bibleVersion else { return }
        dropLiftedCard()
        bibleVersion = version
        Analytics.log(.settingChanged(setting: "bibleVersion", value: version.rawValue))
    }

    private var closeButton: some View {
        Button { close(.closeButton) } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.medium))
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel("Close")
        .buttonBorderShape(.circle)
        .systemGlassButton()
    }

    private var sideButtons: some View {
        VStack(spacing: 12) {
            closeButton
            Button { startPractice(from: index) } label: {
                Image(systemName: "keyboard")
                    .font(.body.weight(.medium))
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Practice")
            .buttonBorderShape(.circle)
            .systemGlassButton()
        }
        .opacity(Double(1 - flight))
        .disabled(!fanned)
    }

    /// Fast scroll through the list, on the trailing edge where a thumb reaches.
    private var thumb: some View {
        GeometryReader { area in
            if fanned, verses.count >= 2 {
                VerseFastScrollOverlay(
                    verseCount: verses.count,
                    scrollFraction: listFraction ?? Double(index) / Double(verses.count - 1),
                    containerHeight: area.size.height,
                    titleProvider: { verses.indices.contains($0) ? verses[$0].title : "" },
                    referenceProvider: { i in
                        guard verses.indices.contains(i) else { return "" }
                        return "\(verses[i].book) \(verses[i].reference)"
                    },
                    onScrub: { fraction in
                        listScrolled = true
                        scrubFraction = fraction
                    },
                    shownIndex: index)
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
        case .coverBack:
            PaperFace(tint: PouchInk.paperBack)
                .frame(width: width, height: width / PouchMetrics.cardAspect)
                .paperAppearance()
        case .verse, .none:
            Color.clear
        }
    }

    private func listCard(_ i: Int, width: CGFloat, onLift: @escaping () -> Void = {}) -> some View {
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
        .accessibilityHint("Lifts the card and turns it over")
        .accessibilityAction { onLift() }
        .accessibilityAction(named: "Practice This Card") { practice = .practice(card: verse) }
        .accessibilityAction(named: FavoritesStore.shared.isFavorite(verse) ? "Unstar" : "Star") {
            toggleStar(verse)
        }
        .accessibilityAction(named: learning.isLearnt(verse) ? "Mark as not learnt" : "Mark as learnt") {
            toggleLearnt(verse)
        }
    }

    @ViewBuilder
    private func cardMenu(_ i: Int) -> some View {
        let verse = verses[i]
        let isFavorite = FavoritesStore.shared.isFavorite(verse)
        Button { practice = .practice(card: verse) } label: {
            Label("Practice This Card", systemImage: "keyboard")
        }
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

    /// The title card's back, the verses, then the back page after the last one.
    private func card(at i: Int) -> PouchSlots.Card {
        i < -1 ? .none : i < 0 ? .coverBack : i < verses.count ? .verse(i) : i == verses.count ? .backPage : .none
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
            withTransaction(t) { fanned = true }
        }
    }

    /// A touch while the pack is opening goes straight to the list, carrying a
    /// flick on through it.
    private func finishOpening(flick: CGFloat, pitch: CGFloat, columns: Int) {
        guard !fanned, !closing else { return }
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
        let target = min(max(index - Int((flick / pitch).rounded()) * columns, 0), verses.count - 1)
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
        Analytics.log(.packClosed(how: how, seconds: openTime.elapsed(), flips: flipCount))
        if AppMotion.reduceMotion || !animatesPouch { HapticEngine.light(); dismissOrPutBack(); return }
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
    private func listContentHeight(layout: PackListLayout, cardHeight: CGFloat, below: CGFloat) -> CGFloat {
        CGFloat(layout.rows(forCount: verses.count)) * (cardHeight + AppLayout.spacing) + AppLayout.spacing + below
    }

    /// Where the list puts card `i` when it scrolls it as near the middle as it
    /// will go, so the cards fanning out land where the list then shows them.
    private func listMidY(of i: Int, layout: PackListLayout, height: CGFloat, viewport: CGFloat,
                          below: CGFloat) -> CGFloat {
        let mid = AppLayout.spacing + CGFloat(layout.row(of: i)) * (height + AppLayout.spacing) + height / 2
        let most = max(0, listContentHeight(layout: layout, cardHeight: height, below: below) - viewport)
        return mid - min(max(0, mid - viewport / 2), most)
    }

    private func scrub(_ proxy: ScrollViewProxy, to fraction: Double, layout: PackListLayout, height: CGFloat,
                       viewport: CGFloat, below: CGFloat) {
        let most = max(0, listContentHeight(layout: layout, cardHeight: height, below: below) - viewport)
        let target = PackListLayout.scrubTarget(fraction: fraction, most: most, viewport: viewport, cardHeight: height,
                                                spacing: AppLayout.spacing,
                                                rows: layout.rows(forCount: verses.count))
        let card = min(layout.firstCard(inRow: target.row), verses.count - 1)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            if let anchor = target.anchor {
                proxy.scrollTo(card, anchor: UnitPoint(x: 0.5, y: anchor))
            } else {
                listIndex = card
            }
        }
    }

    /// The card the counter names at a scroll offset: the one in the middle,
    /// except within half a screen of either end, where it slides to the first
    /// or last card.
    private func cardShown(at offset: CGFloat, layout: PackListLayout, height: CGFloat, viewport: CGFloat,
                           below: CGFloat) -> Int {
        let most = listContentHeight(layout: layout, cardHeight: height, below: below) - viewport
        guard most > 0 else { return index }
        let half = viewport / 2
        let reading = offset + (offset < most / 2 ? min(max(offset, 0), half)
                                                  : max(half, viewport - max(most - offset, 0)))
        let row = Int((reading - AppLayout.spacing / 2) / (height + AppLayout.spacing))
        return min(max(layout.firstCard(inRow: row), 0), verses.count - 1)
    }

    private var cardMotion: Animation {
        AppMotion.reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.24)
    }

    private var cardBounce: Animation {
        AppMotion.reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.62)
    }

    private func liftCard(_ i: Int, from source: CGRect) {
        guard lifted == nil else { return }
        HapticEngine.light()
        flipCount += 1
        lifted = LiftedCard(index: i, source: source)
        withAnimation(cardMotion) {
            liftAmount = 1
            liftedAngle = 180
        }
    }

    private var liftedSwipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                liftedDrag = CGSize(width: PackListLayout.cardPull(value.translation.width),
                                    height: PackListLayout.cardPull(value.translation.height))
            }
            .onEnded { value in
                let flung = hypot(value.predictedEndTranslation.width, value.predictedEndTranslation.height)
                let moved = hypot(value.translation.width, value.translation.height)
                if moved > Self.cardSwipeDistance || flung > Self.cardSwipeFlick {
                    putCardBack(motion: cardBounce)
                } else {
                    withAnimation(cardBounce) { liftedDrag = .zero }
                }
            }
    }

    private func flipLiftedCard() {
        HapticEngine.light()
        withAnimation(cardMotion) { liftedAngle = liftedAngle > 90 ? 0 : 180 }
    }

    private func putCardBack() { putCardBack(motion: cardMotion) }

    private func putCardBack(motion: Animation) {
        guard lifted != nil, liftAmount == 1 else { return }
        withAnimation(motion, completionCriteria: .logicallyComplete) {
            liftAmount = 0
            liftedAngle = 0
            liftedDrag = .zero
        } completion: { lifted = nil }
    }

    private func dropLiftedCard() {
        lifted = nil
        liftedDrag = .zero
        liftAmount = 0
        liftedAngle = 0
    }

    private func returnToPractisedCard() {
        defer { lastPractised = nil }
        guard let verse = lastPractised,
              let i = verses.firstIndex(where: { $0.srsKey == verse.srsKey }) else { return }
        listScrolled = false
        index = i
        withAnimation(AppMotion.movement) { listIndex = i }
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
