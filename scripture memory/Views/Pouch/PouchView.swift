import SwiftUI

/// A pack as the real thing: a clear plastic pouch folded in the middle, with
/// the cards in two inner pockets.
///
/// The bottom pocket holds the card you're on and everything after it. Turning
/// a card flips it over the fold like a page, and it lands upside down in the
/// top pocket, which holds everything before it. Folded shut, the pack's cover
/// card shows through the plastic.
///
/// iPhone Duo: `openness` is meant to follow the hinge. Building with the
/// iOS 27.1 SDK, drive it from `.onHingeChange { _, context in … }` using
/// `context.hinge?.angle` (0° shut … 180° flat). On every other device you
/// open and fold the pouch with a tap or a drag.
struct PouchView: View {
    let packName: String
    let verses: [Verse]
    /// Called with the card you were on, so the screen underneath can follow.
    var onClose: (Int) -> Void = { _ in }

    @State private var index: Int
    @State private var openness: CGFloat
    @State private var turn: CGFloat = 0
    @State private var turning: Int?
    @State private var drag: DragMode = .none
    @State private var hasTurned = false

    @StateObject private var tilt = TiltMonitor()
    @ObservedObject private var learning = LearningStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private enum DragMode { case none, opening, forward, backward }

    init(packName: String, verses: [Verse], startIndex: Int, onClose: @escaping (Int) -> Void = { _ in }) {
        self.packName = packName
        self.verses = verses
        self.onClose = onClose
        _index = State(initialValue: min(max(startIndex, 0), verses.count))
        // Starts shut and unfolds on appear, unless motion is reduced.
        _openness = State(initialValue: AppMotion.reduceMotion ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geo in
                let m = PouchMetrics(fitting: CGSize(width: geo.size.width, height: geo.size.height - 12))
                let sceneTop = (geo.size.height - 2 * m.halfHeight) / 2

                PouchScene(openness: openness, turn: turn, m: m,
                           style: PlasticStyle(colorScheme), slots: slots, tilt: tilt.roll,
                           face: { cardFace($0, width: m.cardWidth) },
                           cover: { PackCover(pack: pack, cornerRadius: 2, showsShadow: false)
                                        .frame(width: m.cardWidth) })
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in
                        tapped(inTopHalf: point.y < sceneTop + m.halfHeight)
                    }
                    .gesture(dragGesture(m: m, splitY: sceneTop + m.halfHeight))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityDescription)
                    .accessibilityHint(openness < 1 ? "Double-tap to open the pouch" : "Swipe up or down to turn cards")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: turnForward()
                        case .decrement: turnBack()
                        @unknown default: break
                        }
                    }
                    .accessibilityAction(named: openness < 1 ? "Open the pouch" : "Fold the pouch") { toggleFold() }
            }
            hint
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            tilt.start()
            guard openness < 1 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.smooth(duration: 0.75)) { openness = 1 }
            }
        }
        .onDisappear {
            tilt.stop()
            let current = min(index, verses.count - 1)
            if verses.indices.contains(current) {
                PackPositions.save(verses[current], inPack: packName)
                onClose(current)
            }
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(packName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(positionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(AppMotion.control, value: positionLabel)
            }
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }
                .accessibilityLabel("Close")
                Spacer()
                Button { toggleFold() } label: {
                    Image(systemName: openness < 1 ? "book" : "book.closed").studyChromeCircleButton()
                }
                .accessibilityLabel(openness < 1 ? "Open the pouch" : "Fold the pouch")
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 12)
    }

    private var hint: some View {
        Text(openness < 1 ? "Tap the pouch to open it" : "Swipe up on the card to turn it over")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .opacity(hasTurned ? 0 : 1)
            .animation(AppMotion.content, value: hasTurned)
            .padding(.bottom, 16)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cardFace(_ card: PouchSlots.Card, width: CGFloat) -> some View {
        switch card {
        case .verse(let i):
            PouchVerseCard(verse: verses[i], isLearnt: learning.isLearnt(verses[i]), width: width)
        case .backPage:
            PouchBackPageCard(packName: packName, verseCount: verses.count,
                              learntCount: verses.filter(learning.isLearnt).count, width: width)
        case .none:
            Color.clear
        }
    }

    // MARK: - State

    /// The pack itself, for its cover: the same cover the pack grid shows.
    private var pack: Pack {
        BibleVersion.saved().packs.first { $0.name == packName }
            ?? Pack(name: packName, color: "#8E8E93", accentText: "", verses: verses)
    }

    private var slots: PouchSlots {
        func card(_ i: Int) -> PouchSlots.Card {
            i < 0 ? .none : i >= verses.count ? .backPage : .verse(i)
        }
        let topIndex = (turning ?? index) - 1
        let bottomIndex = turning.map { $0 + 1 } ?? index
        // One visible edge per handful of cards, so a thick stack looks thick.
        func edges(_ n: Int) -> Int { min(7, Int((Double(max(n, 0)) / 5).rounded(.up))) }
        return PouchSlots(top: card(topIndex), bottom: card(bottomIndex), turning: turning,
                          topEdges: edges(topIndex),
                          bottomEdges: bottomIndex < verses.count ? edges(verses.count - bottomIndex) : 0)
    }

    private var positionLabel: String {
        index >= verses.count ? "End of the pack" : "Card \(index + 1) of \(verses.count)"
    }

    private var accessibilityDescription: String {
        if openness < 1 { return "\(packName) pouch, folded shut" }
        guard verses.indices.contains(index) else { return "\(packName) pouch, end of the pack" }
        let v = verses[index]
        return "\(positionLabel). \(v.title), \(v.book) \(v.reference). \(v.verse)"
    }

    // MARK: - Actions

    private func toggleFold() {
        HapticEngine.light()
        withAnimation(AppMotion.reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.65)) {
            openness = openness < 1 ? 1 : 0
        }
    }

    private func tapped(inTopHalf: Bool) {
        guard turning == nil else { return }
        if openness < 1 { toggleFold(); return }
        inTopHalf ? turnBack() : turnForward()
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
            hasTurned = true
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
        // A full turn is the card travelling from its pocket to the other one.
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
}
