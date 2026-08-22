import SwiftUI

/// `CardStudyView` as a full-screen cover.
///
/// Every screen that opens the study card presents it the same way: inside a
/// `NavigationStack` (so the keyboard's "Done" toolbar renders) with the
/// navigation bar hidden (so the card's own top bar is the only chrome). This
/// is that wrapper, in one place, instead of repeated at each presentation site.
struct CardStudyCover: View {
    let packName: String
    let verses:   [Verse]
    var initialIndex:      Int  = 0
    var initialReviewMode: Bool = false
    var adjacentPack: ((_ currentPackName: String, _ forward: Bool) -> (name: String, verses: [Verse])?)? = nil
    var onMarkLearnt: ((Verse) -> Void)? = nil

    var body: some View {
        NavigationStack {
            CardStudyView(
                packName: packName,
                verses: verses,
                initialIndex: initialIndex,
                initialReviewMode: initialReviewMode,
                adjacentPack: adjacentPack,
                onMarkLearnt: onMarkLearnt
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
