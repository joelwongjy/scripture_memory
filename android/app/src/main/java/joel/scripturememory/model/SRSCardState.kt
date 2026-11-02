package joel.scripturememory.model

import kotlinx.serialization.Serializable

@Serializable
enum class SRSPhase { learning, review }

@Serializable
enum class SRSGrade {
    again,
    hard,
    good,
    easy;

    val displayName: String
        get() = when (this) {
            again -> "Again"
            hard -> "Hard"
            good -> "Good"
            easy -> "Easy"
        }
}

@Serializable
data class SRSCardState(
    val key: String,
    val phase: SRSPhase,
    val interval: Double,
    val ease: Double,
    val reps: Int,
    val lapses: Int,
    val learningStep: Int,
    val due: Date,
    val lastReviewed: Date? = null,
) {
    val isUngraded: Boolean get() = lastReviewed == null

    companion object {
        fun newCard(key: String, now: Date): SRSCardState = SRSCardState(
            key = key,
            phase = SRSPhase.learning,
            interval = 0.0,
            ease = SRSConfig.default.startingEase,
            reps = 0,
            lapses = 0,
            learningStep = 0,
            due = now,
            lastReviewed = null,
        )

        fun knownCard(key: String, now: Date, config: SRSConfig = SRSConfig.default): SRSCardState =
            SRSCardState(
                key = key,
                phase = SRSPhase.review,
                interval = config.knownCardInterval,
                ease = config.startingEase,
                reps = 1,
                lapses = 0,
                learningStep = 0,
                due = now,
                lastReviewed = null,
            )

        fun justLearnt(key: String, now: Date, config: SRSConfig = SRSConfig.default): SRSCardState =
            knownCard(key, now, config)
                .copy(due = now.addingTimeInterval(config.knownCardInterval * 86_400))
    }
}

data class SRSConfig(
    val learningSteps: List<Double> = listOf(60.0, 600.0),
    val graduatingInterval: Double = 1.0,
    val easyInterval: Double = 4.0,
    val startingEase: Double = 2.5,
    val easeFloor: Double = 1.3,
    val easeBonus: Double = 0.15,
    val easePenaltyHard: Double = 0.15,
    val easePenaltyAgain: Double = 0.20,
    val hardIntervalMultiplier: Double = 1.2,
    val easyMultiplier: Double = 1.3,
    val knownCardInterval: Double = 3.0,
) {
    companion object {
        val default = SRSConfig()
    }
}

object SRSKey {
    fun canonicalBook(book: String): String =
        book.lowercasedByScalar().trimmingWhitespacesAndNewlines()

    fun normalizedReference(reference: String): String = buildString {
        for (grapheme in reference.graphemes()) {
            if (!isUnicodeWhiteSpace(grapheme.codePointAt(0))) append(grapheme)
        }
    }.lowercasedByScalar()

    fun make(packName: String, book: String, reference: String): String =
        "$packName#${canonicalBook(book)}|${normalizedReference(reference)}"
}
