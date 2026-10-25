import SwiftUI

/// A pack opened from the Packs grid: the pouch or the list, whichever you
/// last left it as, and moving between them without closing the pack.
///
/// The pouch spreads its cards out into the list; the list gathers them back
/// into the pouch. Both hand over the card you're on, so you never lose your
/// place, and the choice is remembered per pack (`PackViewPreference`).
struct PackReader: View {
    let pack: Pack

    @State private var index: Int
    @State private var showsList: Bool
    @State private var pouchEntrance: PouchView.Entrance = .unfold

    init(pack: Pack, startIndex: Int) {
        self.pack = pack
        _index = State(initialValue: startIndex)
        _showsList = State(initialValue: PackViewPreference.opensAsList(pack.name))
    }

    var body: some View {
        ZStack {
            if showsList {
                CardStudyCover(packName: pack.name, verses: pack.verses, initialIndex: index,
                               onGather: { i in
                                   index = i
                                   PackViewPreference.set(opensAsList: false, for: pack.name)
                                   pouchEntrance = .gather
                                   withAnimation(.easeOut(duration: 0.18)) { showsList = false }
                               })
                .transition(.opacity)
            } else {
                PouchView(packName: pack.name, verses: pack.verses, startIndex: index,
                          entrance: pouchEntrance,
                          onClose: { i in index = i },
                          onSpread: { i in
                              index = i
                              PackViewPreference.set(opensAsList: true, for: pack.name)
                              withAnimation(.easeOut(duration: 0.18)) { showsList = true }
                          })
                .transition(.opacity)
            }
        }
    }
}
