package joel.scripturememory.model

val TestSessionViewModel.allCardsGraded: Boolean
    get() = verses.all { it.id in sessionGrades }

fun TestSessionViewModel.notePeek(verse: Verse) {
    peekedVerseIds = peekedVerseIds + verse.id
}

fun TestSessionViewModel.displayState(verse: Verse): SRSCardState {
    preGradeStates[verse.id]?.let { return it }
    return SRSStore.shared.state(verse)
        ?: SRSStore.initialState(verse.srsKey, LearningStore.shared.isLearnt(verse), Date.now())
}

fun TestSessionViewModel.suggestedGradeFor(verse: Verse): SRSGrade? {
    if (studyMode != StudyMode.submit) return null
    if (verse.id in peekedVerseIds) return SRSGrade.again
    val allCorrect = submitResults[verse.id]?.isAllCorrect == true
    return suggestedGrade(allCorrect, mistakes(verse.id))
}

fun TestSessionViewModel.grade(grade: SRSGrade) {
    val verse = currentVerse ?: return
    val learning = LearningStore.shared
    StreakStore.shared.recordToday()

    if (verse.id !in sessionGrades) {
        val knew = learning.isLearnt(verse)
        val current = SRSStore.shared.state(verse)
        if (current != null) {
            preGradeStates = preGradeStates + (verse.id to current)
        } else {
            preGradeStates = preGradeStates +
                (verse.id to SRSStore.initialState(verse.srsKey, knew, Date.now()))
            unscheduledAtStart = unscheduledAtStart + (verse.id to knew)
        }
        SRSStore.shared.grade(verse, grade, alreadyKnew = knew)
        gradedOrder = gradedOrder + verse.id
    } else {
        preGradeStates[verse.id]?.let { prior ->
            SRSStore.shared.regrade(verse, grade, prior)
        }
    }
    sessionGrades = sessionGrades + (verse.id to grade)

    if ((grade == SRSGrade.good || grade == SRSGrade.easy) && learning.isCurrent(verse)) {
        learning.markLearnt(verse)
        autoLearntIds = autoLearntIds + verse.id
    }
}

fun TestSessionViewModel.undoLastGrade(): Int? {
    val lastId = gradedOrder.lastOrNull() ?: return null
    val index = verses.indexOfFirst { it.id == lastId }
    if (index < 0) return null
    val verse = verses[index]
    val learning = LearningStore.shared

    val wasReview = preGradeStates[lastId]?.phase == SRSPhase.review
    val knew = unscheduledAtStart[lastId]
    if (knew != null) {
        SRSStore.shared.revert(verse, null, wasNewlyIntroduced = !knew, wasReview = wasReview)
    } else {
        SRSStore.shared.revert(
            verse,
            preGradeStates[lastId],
            wasNewlyIntroduced = false,
            wasReview = wasReview,
        )
    }
    if (lastId in autoLearntIds) {
        autoLearntIds = autoLearntIds - lastId
        learning.unmarkLearnt(verse)
    }

    sessionGrades = sessionGrades - lastId
    preGradeStates = preGradeStates - lastId
    unscheduledAtStart = unscheduledAtStart - lastId
    gradedOrder = gradedOrder.dropLast(1)
    return index
}
