package joel.scripturememory.model

import java.util.UUID

data class DiffWord(
    val text: String,
    val kind: Kind,
    val correction: String? = null,
) {
    enum class Kind { correct, wrong, missing, extra }

    val id: UUID = UUID.randomUUID()
}

data class SubmitResult(
    val titleDiffs: List<DiffWord>,
    val verseDiffs: List<DiffWord>,
) {
    val isAllCorrect: Boolean
        get() = titleDiffs.isNotEmpty() && verseDiffs.isNotEmpty() &&
            titleDiffs.all { it.kind == DiffWord.Kind.correct } &&
            verseDiffs.all { it.kind == DiffWord.Kind.correct }
}
