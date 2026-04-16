import Foundation

/// Pure SM-2-style scheduling. No I/O, no singletons — fully unit-testable.
///
/// Behavior summary:
/// - **Learning phase** walks through `config.learningSteps`. Again resets to step 0;
///   Hard repeats the current step; Good advances; Easy graduates immediately
///   with `easyInterval`.
/// - **Review phase**: Again sends the card back to learning (lapse). Hard scales
///   the interval by `hardIntervalMultiplier` and trims ease. Good multiplies by
///   ease (unchanged). Easy multiplies by ease × `easyMultiplier` and boosts ease.
/// - Ease is floored at `config.easeFloor`.
///
/// `lastReviewed` is set to `now` on every grade.
func updateSRS(
    state:  SRSCardState,
    grade:  SRSGrade,
    now:    Date,
    config: SRSConfig = .default
) -> SRSCardState {
    var s = state
    s.lastReviewed = now

    switch s.phase {
    case .learning:
        return applyLearning(state: &s, grade: grade, now: now, config: config)
    case .review:
        return applyReview(state: &s, grade: grade, now: now, config: config)
    }
}

// MARK: - Learning Phase

private func applyLearning(
    state s: inout SRSCardState,
    grade:   SRSGrade,
    now:     Date,
    config:  SRSConfig
) -> SRSCardState {
    let steps = config.learningSteps
    guard !steps.isEmpty else {
        // No learning steps configured — graduate on anything but Again.
        return graduate(state: &s, easy: grade == .easy, now: now, config: config)
    }

    switch grade {
    case .again:
        s.learningStep = 0
        s.due = now.addingTimeInterval(steps[0])
        return s

    case .hard:
        let i = min(s.learningStep, steps.count - 1)
        s.due = now.addingTimeInterval(steps[i])
        return s

    case .good:
        let next = s.learningStep + 1
        if next >= steps.count {
            return graduate(state: &s, easy: false, now: now, config: config)
        }
        s.learningStep = next
        s.due = now.addingTimeInterval(steps[next])
        return s

    case .easy:
        return graduate(state: &s, easy: true, now: now, config: config)
    }
}

private func graduate(
    state s: inout SRSCardState,
    easy:    Bool,
    now:     Date,
    config:  SRSConfig
) -> SRSCardState {
    s.phase        = .review
    s.interval     = easy ? config.easyInterval : config.graduatingInterval
    s.ease         = config.startingEase
    s.reps         = max(s.reps, 1)
    s.learningStep = 0
    s.due          = now.addingTimeInterval(s.interval * 86_400)
    return s
}

// MARK: - Review Phase

private func applyReview(
    state s: inout SRSCardState,
    grade:   SRSGrade,
    now:     Date,
    config:  SRSConfig
) -> SRSCardState {
    switch grade {
    case .again:
        // Lapse: back to learning, ease penalty.
        s.lapses       += 1
        s.phase         = .learning
        s.learningStep  = 0
        s.ease          = max(config.easeFloor, s.ease - config.easePenaltyAgain)
        s.interval      = 0
        s.due           = now.addingTimeInterval(config.learningSteps.first ?? 60)
        return s

    case .hard:
        s.ease     = max(config.easeFloor, s.ease - config.easePenaltyHard)
        s.interval = max(1.0, s.interval * config.hardIntervalMultiplier)
        s.reps    += 1
        s.due      = now.addingTimeInterval(s.interval * 86_400)
        return s

    case .good:
        s.interval = max(1.0, s.interval * s.ease)
        s.reps    += 1
        s.due      = now.addingTimeInterval(s.interval * 86_400)
        return s

    case .easy:
        s.ease     = s.ease + config.easeBonus
        s.interval = max(1.0, s.interval * s.ease * config.easyMultiplier)
        s.reps    += 1
        s.due      = now.addingTimeInterval(s.interval * 86_400)
        return s
    }
}

// MARK: - Auto-Grade Suggestion

/// Maps the existing submit-mode result onto an auto-suggested grade.
/// User can always override via the grading buttons.
///
/// - `isAllCorrect && mistakes == 0` → `.good`
/// - `isAllCorrect && mistakes > 0`  → `.hard`
/// - `!isAllCorrect`                  → `.again`
/// - `.easy` is never auto-suggested — user must pick it manually.
func suggestedGrade(isAllCorrect: Bool, mistakes: Int) -> SRSGrade {
    if !isAllCorrect { return .again }
    return mistakes == 0 ? .good : .hard
}

// MARK: - Predicted Interval Label

/// Human-readable preview of the next interval each grade would produce.
/// Used by `SRSGradingButtons` to show "1m / 10m / 1d / 4d" labels.
func predictedIntervalLabel(
    state:  SRSCardState,
    grade:  SRSGrade,
    now:    Date,
    config: SRSConfig = .default
) -> String {
    let next = updateSRS(state: state, grade: grade, now: now, config: config)
    let dt   = next.due.timeIntervalSince(now)
    return formatInterval(dt)
}

private func formatInterval(_ seconds: TimeInterval) -> String {
    let s = max(0, seconds)
    if s < 60          { return "\(Int(s))s" }
    if s < 3_600       { return "\(Int(s / 60))m" }
    if s < 86_400      { return "\(Int(s / 3_600))h" }
    let days = s / 86_400
    if days < 30       { return "\(Int(days.rounded()))d" }
    if days < 365      { return "\(Int((days / 30).rounded()))mo" }
    return "\(Int((days / 365).rounded()))y"
}
