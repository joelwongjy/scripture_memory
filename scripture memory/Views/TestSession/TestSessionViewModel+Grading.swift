import Foundation

/// Daily review grading: the user rates each card Again / Hard / Good / Easy, and
/// the rating schedules it. Only used when the session is an SRS review.
///
/// A card can be re-rated (scrubbing back, or Undo) without the schedule
/// compounding: the first rating captures the card's pre-grade state, and any
/// later rating recomputes from that.
extension TestSessionViewModel {

    /// Every card in the session has a rating, so the session is over.
    var allCardsGraded: Bool {
        verses.allSatisfy { sessionGrades[$0.id] != nil }
    }

    /// Remember that the user peeked at `verse`, a failed recall.
    func notePeek(at verse: Verse) {
        peekedVerseIds.insert(verse.id)
    }

    /// The state the grading buttons predict from, which is the state a rating
    /// will actually be applied to. Once a card is rated this session that's its
    /// pre-grade state, so the "1d / 4d / 12d" labels show what each rating would
    /// do from where the card started.
    func displayState(for verse: Verse) -> SRSCardState {
        if let prior = preGradeStates[verse.id] { return prior }
        return SRSStore.shared.state(for: verse)
            ?? SRSStore.initialState(key: verse.srsKey,
                                     alreadyKnew: LearningStore.shared.isLearnt(verse),
                                     now: Date())
    }

    /// The recommended rating, shown with the "Suggested" tag. Only Entire Verse
    /// mode scores an answer, so the typing modes leave the choice to the user.
    func suggestedGradeFor(_ verse: Verse) -> SRSGrade? {
        guard studyMode == .submit else { return nil }
        // Peeking at the answer is a failed recall.
        if peekedVerseIds.contains(verse.id) { return .again }
        let allCorrect = submitResults[verse.id]?.isAllCorrect == true
        return suggestedGrade(isAllCorrect: allCorrect, mistakes: mistakes(for: verse.id))
    }

    /// Rates the current card and schedules it. A Good or Easy rating of the
    /// current learning verse also marks it learnt, moving the learning cursor on.
    func grade(_ grade: SRSGrade) {
        guard let verse = currentVerse else { return }
        let learning = LearningStore.shared
        StreakStore.shared.recordToday()

        if sessionGrades[verse.id] == nil {
            // Capture where the card starts, decided once: a Good/Easy rating
            // below marks the verse learnt, which mustn't change how a re-rating
            // or Undo treats it.
            let knew = learning.isLearnt(verse)
            if let current = SRSStore.shared.state(for: verse) {
                preGradeStates[verse.id] = current
            } else {
                preGradeStates[verse.id] = SRSStore.initialState(key: verse.srsKey, alreadyKnew: knew, now: Date())
                unscheduledAtStart[verse.id] = knew
            }
            SRSStore.shared.grade(verse: verse, grade: grade, alreadyKnew: knew)
            gradedOrder.append(verse.id)
        } else if let prior = preGradeStates[verse.id] {
            // Re-rating: recompute from the captured state so it doesn't compound.
            SRSStore.shared.regrade(verse: verse, grade: grade, from: prior)
        }
        sessionGrades[verse.id] = grade

        if grade == .good || grade == .easy, learning.isCurrent(verse) {
            learning.markLearnt(verse)
            autoLearntIds.insert(verse.id)
        }
    }

    /// Undoes the most recent rating: the card's schedule goes back to its
    /// pre-grade state, and the learning cursor too if that rating moved it.
    /// Returns the index of the card to go back to, or `nil` if there's nothing
    /// to undo.
    func undoLastGrade() -> Int? {
        guard let lastId = gradedOrder.last,
              let index = verses.firstIndex(where: { $0.id == lastId }) else { return nil }
        let verse = verses[index]
        let learning = LearningStore.shared

        // A card with no schedule before this session goes back to having none,
        // and hands back the new-card slot unless the user already knew it (a
        // known verse never took one).
        let wasReview = preGradeStates[lastId]?.phase == .review
        if let knew = unscheduledAtStart[lastId] {
            SRSStore.shared.revert(verse: verse, to: nil, wasNewlyIntroduced: !knew, wasReview: wasReview)
        } else {
            SRSStore.shared.revert(verse: verse, to: preGradeStates[lastId], wasNewlyIntroduced: false,
                                   wasReview: wasReview)
        }
        if autoLearntIds.remove(lastId) != nil {
            learning.unmarkLearnt(verse)
        }

        sessionGrades.removeValue(forKey: lastId)
        preGradeStates.removeValue(forKey: lastId)
        unscheduledAtStart.removeValue(forKey: lastId)
        gradedOrder.removeLast()
        return index
    }
}
