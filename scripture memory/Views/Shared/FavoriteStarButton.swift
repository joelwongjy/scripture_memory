import SwiftUI

/// The star that adds a verse to favourites, living in a card's footer corner.
///
/// Shared by every card surface so the control is in the same place with the
/// same size wherever a verse can be starred. In the card rather than the screen
/// chrome because chrome refers to the pack — there'd be no way for a chrome
/// button to say *which* verse it meant.
struct FavoriteStarButton: View {
    let verse: Verse
    @ObservedObject private var favorites = FavoritesStore.shared

    init(verse: Verse) { self.verse = verse }

    var body: some View {
        let isFavorite = favorites.isFavorite(verse)
        return Button {
            // Explicitly animated, and fast. The store is an ObservableObject, so
            // without a `withAnimation` around the mutation the symbol swap fell
            // back to SwiftUI's default animation — around twice this long, on the
            // one control in the app that most needs to feel instant.
            HapticEngine.light()
            withAnimation(AppMotion.control) { favorites.toggle(verse) }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFavorite ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                // `.offUp` over the default `.downUp`: one glyph leaves as the
                // other arrives instead of the two crossing, which halves the
                // distance the swap has to cover.
                .contentTransition(.symbolEffect(.replace.offUp))
                // 30pt target: the card footer can't spare the full 44, and the
                // control sits alone in its corner with nothing to mis-hit.
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from favourites" : "Add to favourites")
    }
}
