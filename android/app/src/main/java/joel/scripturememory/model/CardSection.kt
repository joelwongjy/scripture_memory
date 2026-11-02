package joel.scripturememory.model

enum class CardSection {
    title,
    verse;

    val other: CardSection get() = if (this == title) verse else title
}
