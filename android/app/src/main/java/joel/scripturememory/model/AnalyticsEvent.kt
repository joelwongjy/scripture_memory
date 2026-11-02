package joel.scripturememory.model

sealed class AnalyticsEvent {
    data class ScreenViewed(val screen: AnalyticsScreen) : AnalyticsEvent()
    data class OnboardingFinished(val start: OnboardingStart, val bibleVersion: String) : AnalyticsEvent()
    data class OpenedFromWidget(val destination: WidgetDestination) : AnalyticsEvent()

    data class PackOpened(val pack: String, val from: PackSource) : AnalyticsEvent()
    data class PackClosed(val how: PackCloseMethod, val seconds: Double) : AnalyticsEvent()
    data class LearntChanged(val learnt: Boolean, val from: VerseActionSource) : AnalyticsEvent()
    data class StarChanged(val starred: Boolean, val from: VerseActionSource) : AnalyticsEvent()
    data object PacksReordered : AnalyticsEvent()
    data class PackVisibilityChanged(val hidden: Boolean) : AnalyticsEvent()

    data class SessionStarted(val start: StudySessionStart) : AnalyticsEvent()
    data class SessionEnded(val summary: StudySessionSummary) : AnalyticsEvent()

    data class SearchPerformed(val results: Int) : AnalyticsEvent()
    data class SearchResultOpened(val rank: Int, val matchedOnReference: Boolean) : AnalyticsEvent()
    data object SearchFoundNothing : AnalyticsEvent()

    data class SettingChanged(val setting: String, val value: String) : AnalyticsEvent()

    val name: String
        get() = when (this) {
            is ScreenViewed -> "Screen.viewed"
            is OnboardingFinished -> "Onboarding.finished"
            is OpenedFromWidget -> "App.openedFromWidget"
            is PackOpened -> "Pack.opened"
            is PackClosed -> "Pack.closed"
            is LearntChanged -> "Verse.learntChanged"
            is StarChanged -> "Verse.starChanged"
            PacksReordered -> "Packs.reordered"
            is PackVisibilityChanged -> "Packs.visibilityChanged"
            is SessionStarted -> "${start.kind.signalPrefix}.started"
            is SessionEnded -> "${summary.kind.signalPrefix}.ended"
            is SearchPerformed -> "Search.performed"
            is SearchResultOpened -> "Search.resultOpened"
            SearchFoundNothing -> "Search.foundNothing"
            is SettingChanged -> "Settings.changed"
        }

    val parameters: Map<String, String>
        get() = when (this) {
            is ScreenViewed -> mapOf("screen" to screen.rawValue)
            is OnboardingFinished ->
                mapOf("start" to start.rawValue, "bibleVersion" to bibleVersion)
            is OpenedFromWidget -> mapOf("destination" to destination.rawValue)
            is PackOpened -> mapOf("pack" to pack, "from" to from.rawValue)
            is PackClosed ->
                mapOf("how" to how.rawValue, "timeOpen" to AnalyticsRange.duration(seconds))
            is LearntChanged -> mapOf("learnt" to learnt.toString(), "from" to from.rawValue)
            is StarChanged -> mapOf("starred" to starred.toString(), "from" to from.rawValue)
            PacksReordered, SearchFoundNothing -> emptyMap()
            is PackVisibilityChanged -> mapOf("hidden" to hidden.toString())
            is SessionStarted -> start.parameters
            is SessionEnded -> summary.parameters
            is SearchPerformed -> mapOf("results" to AnalyticsRange.count(results))
            is SearchResultOpened -> mapOf(
                "rank" to AnalyticsRange.count(rank),
                "matchedOn" to if (matchedOnReference) "reference" else "text",
            )
            is SettingChanged -> mapOf("setting" to setting, "value" to value)
        }
}

enum class AnalyticsScreen {
    home, packs, quiz, settings, search,
    pack, dailyReview, quizSession, practice,
    streak, organizePacks, pinPicker, currentVersePicker, onboarding;

    val rawValue: String get() = name
}

enum class OnboardingStart {
    beginning, pickedVerse, restoredFromICloud;

    val rawValue: String get() = name
}

enum class WidgetDestination {
    read, review;

    val rawValue: String get() = name
}

enum class PackSource {
    shelf, search, homeCard, widget;

    val rawValue: String get() = name
}

enum class PackCloseMethod {
    edgeSwipe, closeButton;

    val rawValue: String get() = name
}

enum class VerseActionSource {
    card, menu;

    val rawValue: String get() = name
}

enum class StudySessionKind {
    review, extraRound, quiz, practice;

    val rawValue: String get() = name

    val signalPrefix: String
        get() = when (this) {
            review -> "Review"
            extraRound -> "Review.extraRound"
            quiz -> "Quiz"
            practice -> "Practice"
        }
}

data class StudySessionStart(
    val kind: StudySessionKind,
    val cards: Int,
    val studyMode: String,
    val hardMode: Boolean,
    val newCards: Int = 0,
    val learningCards: Int = 0,
    val dueCards: Int = 0,
    val knownCards: Int = 0,
    val reviewedToday: Int = 0,
    val pack: String? = null,
) {
    val parameters: Map<String, String>
        get() = buildMap {
            put("cards", AnalyticsRange.count(cards))
            put("studyMode", studyMode)
            put("hardMode", hardMode.toString())
            if (kind == StudySessionKind.review) {
                put("new", AnalyticsRange.count(newCards))
                put("learning", AnalyticsRange.count(learningCards))
                put("due", AnalyticsRange.count(dueCards))
                put("known", AnalyticsRange.count(knownCards))
                put("reviewedToday", AnalyticsRange.count(reviewedToday))
            }
            pack?.let { put("pack", it) }
        }
}

data class StudySessionSummary(
    val kind: StudySessionKind,
    val finished: Boolean,
    val cards: Int,
    val cardsDone: Int,
    val seconds: Double,
    val again: Int = 0,
    val hard: Int = 0,
    val good: Int = 0,
    val easy: Int = 0,
    val peeks: Int = 0,
    val undos: Int = 0,
    val mistakes: Int = 0,
    val usedVoice: Boolean = false,
) {
    val parameters: Map<String, String>
        get() = buildMap {
            put("finished", finished.toString())
            put("cards", AnalyticsRange.count(cards))
            put("cardsDone", AnalyticsRange.count(cardsDone))
            put("time", AnalyticsRange.duration(seconds))
            put("peeks", AnalyticsRange.count(peeks))
            put("usedVoice", usedVoice.toString())
            when (kind) {
                StudySessionKind.review, StudySessionKind.extraRound -> {
                    put("again", AnalyticsRange.count(again))
                    put("hard", AnalyticsRange.count(hard))
                    put("good", AnalyticsRange.count(good))
                    put("easy", AnalyticsRange.count(easy))
                    put("undos", AnalyticsRange.count(undos))
                }
                StudySessionKind.quiz, StudySessionKind.practice -> {
                    put("mistakes", AnalyticsRange.count(mistakes))
                    put("allCorrect", (finished && mistakes == 0).toString())
                }
            }
        }
}

object AnalyticsBuild {
    fun isTest(isDebug: Boolean, isEmulator: Boolean): Boolean = isDebug || isEmulator
}

class ActiveTimer(now: Date = Date.now()) {
    private var total = 0.0
    private var resumedAt: Date? = now

    fun pause(now: Date = Date.now()) {
        total = elapsed(now)
        resumedAt = null
    }

    fun resume(now: Date = Date.now()) {
        if (resumedAt == null) resumedAt = now
    }

    fun elapsed(now: Date = Date.now()): Double =
        total + (resumedAt?.let { now.timeIntervalSince(it) } ?: 0.0)
}

object AnalyticsRange {
    fun count(n: Int): String = when {
        n < 1 -> "0"
        n == 1 -> "1"
        n <= 5 -> "2-5"
        n <= 10 -> "6-10"
        n <= 20 -> "11-20"
        n <= 50 -> "21-50"
        else -> "50+"
    }

    fun duration(seconds: Double): String = when {
        seconds < 30 -> "<30s"
        seconds < 60 -> "30s-1m"
        seconds < 180 -> "1-3m"
        seconds < 600 -> "3-10m"
        seconds < 1800 -> "10-30m"
        else -> "30m+"
    }
}
