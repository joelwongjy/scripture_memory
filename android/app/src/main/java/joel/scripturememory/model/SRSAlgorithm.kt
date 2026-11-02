package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

fun updateSRS(
    state: SRSCardState,
    grade: SRSGrade,
    now: Date,
    config: SRSConfig = SRSConfig.default,
): SRSCardState {
    val s = state.copy(lastReviewed = now)
    return when (s.phase) {
        SRSPhase.learning -> applyLearning(s, grade, now, config)
        SRSPhase.review -> applyReview(s, grade, now, config)
    }
}

private fun applyLearning(
    s: SRSCardState,
    grade: SRSGrade,
    now: Date,
    config: SRSConfig,
): SRSCardState {
    val steps = config.learningSteps
    if (steps.isEmpty()) return graduate(s, grade == SRSGrade.easy, now, config)

    return when (grade) {
        SRSGrade.again -> s.copy(learningStep = 0, due = now.addingTimeInterval(steps[0]))

        SRSGrade.hard -> {
            val i = min(s.learningStep, steps.size - 1)
            val cur = steps[i]
            val nextStep = if (i + 1 < steps.size) steps[i + 1] else cur
            s.copy(due = now.addingTimeInterval((cur + nextStep) / 2))
        }

        SRSGrade.good -> {
            val next = s.learningStep + 1
            if (next >= steps.size) {
                graduate(s, false, now, config)
            } else {
                s.copy(learningStep = next, due = now.addingTimeInterval(steps[next]))
            }
        }

        SRSGrade.easy -> graduate(s, true, now, config)
    }
}

private fun graduate(
    s: SRSCardState,
    easy: Boolean,
    now: Date,
    config: SRSConfig,
): SRSCardState {
    val interval = if (easy) config.easyInterval else config.graduatingInterval
    return s.copy(
        phase = SRSPhase.review,
        interval = interval,
        ease = config.startingEase,
        reps = max(s.reps, 1),
        learningStep = 0,
        due = now.addingTimeInterval(interval * 86_400),
    )
}

private fun applyReview(
    s: SRSCardState,
    grade: SRSGrade,
    now: Date,
    config: SRSConfig,
): SRSCardState = when (grade) {
    SRSGrade.again -> s.copy(
        lapses = s.lapses + 1,
        phase = SRSPhase.learning,
        learningStep = 0,
        ease = max(config.easeFloor, s.ease - config.easePenaltyAgain),
        interval = 0.0,
        due = now.addingTimeInterval(config.learningSteps.firstOrNull() ?: 60.0),
    )

    SRSGrade.hard -> {
        val interval = max(1.0, s.interval * config.hardIntervalMultiplier)
        s.copy(
            ease = max(config.easeFloor, s.ease - config.easePenaltyHard),
            interval = interval,
            reps = s.reps + 1,
            due = now.addingTimeInterval(interval * 86_400),
        )
    }

    SRSGrade.good -> {
        val interval = max(1.0, s.interval * s.ease)
        s.copy(
            interval = interval,
            reps = s.reps + 1,
            due = now.addingTimeInterval(interval * 86_400),
        )
    }

    SRSGrade.easy -> {
        val ease = s.ease + config.easeBonus
        val interval = max(1.0, s.interval * ease * config.easyMultiplier)
        s.copy(
            ease = ease,
            interval = interval,
            reps = s.reps + 1,
            due = now.addingTimeInterval(interval * 86_400),
        )
    }
}

fun suggestedGrade(isAllCorrect: Boolean, mistakes: Int): SRSGrade {
    if (!isAllCorrect) return SRSGrade.again
    return if (mistakes == 0) SRSGrade.good else SRSGrade.hard
}

fun predictedIntervalLabel(
    state: SRSCardState,
    grade: SRSGrade,
    now: Date,
    config: SRSConfig = SRSConfig.default,
): String {
    val next = updateSRS(state, grade, now, config)
    return formatInterval(next.due.timeIntervalSince(now))
}

private fun formatInterval(seconds: Double): String {
    val s = max(0.0, seconds)
    if (s < 60) return "${s.toLong()}s"
    if (s < 3_600) return "${(s / 60).toLong()}m"
    if (s < 86_400) return "${(s / 3_600).toLong()}h"
    val days = s / 86_400
    if (days < 30) return "${days.roundedAwayFromZero().toLong()}d"
    if (days < 365) return "${(days / 30).roundedAwayFromZero().toLong()}mo"
    return "${(days / 365).roundedAwayFromZero().toLong()}y"
}
