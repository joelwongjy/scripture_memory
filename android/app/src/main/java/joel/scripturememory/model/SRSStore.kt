package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.time.temporal.TemporalAdjusters
import java.util.Locale

class SRSStore(private val storage: ProgressStorage) {

    var states: Map<String, SRSCardState> by mutableStateOf(emptyMap())
        private set

    var dailyNewByDate: Map<String, Map<String, Int>> by mutableStateOf(emptyMap())
        private set

    var reviewedByDate: Map<String, Set<String>> by mutableStateOf(emptyMap())
        private set

    var inactivePackNames: Set<String> by mutableStateOf(emptySet())
        private set

    init {
        load()
    }

    fun state(verse: Verse): SRSCardState? = states[verse.srsKey]

    fun dueCards(verses: List<Verse>, now: Date = Date.now()): List<Verse> =
        verses.filter { v ->
            val s = states[v.srsKey] ?: return@filter false
            s.due <= now
        }

    fun newIntroducedToday(now: Date = Date.now()): Int =
        dailyNewByDate[dayKey(now)]?.values?.sum() ?: 0

    fun newIntroducedThisWeek(now: Date = Date.now()): Int =
        weekDayKeys(now).sumOf { key -> dailyNewByDate[key]?.values?.sum() ?: 0 }

    fun reviewedToday(now: Date = Date.now()): Int = reviewedByDate[dayKey(now)]?.size ?: 0

    fun newIntroduced(unit: NewCapUnit, now: Date = Date.now()): Int =
        if (unit == NewCapUnit.day) newIntroducedToday(now) else newIntroducedThisWeek(now)

    fun activePacks(packs: List<Pack>): List<Pack> = packs.filter { isActive(it.name) }

    fun isActive(packName: String): Boolean = packName !in inactivePackNames

    fun setActive(packName: String, active: Boolean) {
        inactivePackNames = if (active) inactivePackNames - packName else inactivePackNames + packName
        persist()
    }

    fun importStates(incoming: List<SRSCardState>) {
        if (incoming.isEmpty()) return
        val updated = states.toMutableMap()
        for (state in incoming) {
            val existing = updated[state.key]
            val existingSeen = existing?.lastReviewed?.timeIntervalSinceReferenceDate ?: Double.NEGATIVE_INFINITY
            val incomingSeen = state.lastReviewed?.timeIntervalSinceReferenceDate ?: Double.NEGATIVE_INFINITY
            if (existing == null || incomingSeen > existingSeen) updated[state.key] = state
        }
        states = updated
        persist()
    }

    fun renamePack(oldName: String, newName: String) {
        if (oldName !in inactivePackNames) return
        inactivePackNames = inactivePackNames - oldName + newName
        persist()
    }

    fun grade(
        verse: Verse,
        grade: SRSGrade,
        alreadyKnew: Boolean = false,
        now: Date = Date.now(),
    ): SRSCardState {
        val key = verse.srsKey
        val isFirstGrade = key !in states
        val prior = states[key] ?: initialState(key, alreadyKnew, now)
        val next = updateSRS(prior, grade, now)
        states = states + (key to next)

        if (isFirstGrade && !alreadyKnew && verse.packName.isNotEmpty()) {
            bumpDailyNew(verse.packName, now)
        }
        if (prior.phase == SRSPhase.review) {
            val day = dayKey(now)
            reviewedByDate = reviewedByDate + (day to (reviewedByDate[day].orEmpty() + key))
        }
        persist()
        return next
    }

    fun regrade(
        verse: Verse,
        grade: SRSGrade,
        from: SRSCardState,
        now: Date = Date.now(),
    ): SRSCardState {
        val next = updateSRS(from, grade, now)
        states = states + (verse.srsKey to next)
        persist()
        return next
    }

    fun revert(
        verse: Verse,
        to: SRSCardState?,
        wasNewlyIntroduced: Boolean,
        wasReview: Boolean = false,
        now: Date = Date.now(),
    ) {
        val key = verse.srsKey
        if (wasReview) {
            val day = dayKey(now)
            reviewedByDate[day]?.let { reviewedByDate = reviewedByDate + (day to (it - key)) }
        }
        states = if (to != null) states + (key to to) else states - key
        if (wasNewlyIntroduced && verse.packName.isNotEmpty()) {
            unbumpDailyNew(verse.packName, now)
        }
        persist()
    }

    fun scheduleLearnt(verse: Verse, now: Date = Date.now()) {
        val key = verse.srsKey
        if (key.isEmpty() || key in states) return
        states = states + (key to SRSCardState.justLearnt(key, now))
        persist()
    }

    fun unscheduleLearnt(verse: Verse) {
        val key = verse.srsKey
        if (states[key]?.isUngraded != true) return
        states = states - key
        persist()
    }

    fun resetAll() {
        states = emptyMap()
        dailyNewByDate = emptyMap()
        reviewedByDate = emptyMap()
        persist()
    }

    private fun bumpDailyNew(packName: String, now: Date) {
        val day = dayKey(now)
        val perPack = dailyNewByDate[day].orEmpty()
        dailyNewByDate = dailyNewByDate +
            (day to (perPack + (packName to ((perPack[packName] ?: 0) + 1))))
    }

    private fun unbumpDailyNew(packName: String, now: Date) {
        val day = dayKey(now)
        val perPack = dailyNewByDate[day] ?: return
        val count = perPack[packName] ?: return
        if (count <= 0) return
        dailyNewByDate = dailyNewByDate + (day to (perPack + (packName to (count - 1))))
    }

    private fun pruneDailyNew(now: Date = Date.now()) {
        val cutoffKey = dayKey(now.atZone(AppClock.current.zone).minusDays(14).toLocalDate())
        dailyNewByDate = dailyNewByDate.filterKeys { it >= cutoffKey }
        reviewedByDate = reviewedByDate.filterKeys { it >= cutoffKey }
    }

    private fun persist() {
        pruneDailyNew()
        storage.encode(states, statesKey)
        storage.encode(dailyNewByDate, dailyNewKey)
        storage.encode(inactivePackNames.toList(), inactivePacksKey)
        storage.encode(reviewedByDate, reviewedKey)
    }

    private fun load() {
        storage.decode<Map<String, SRSCardState>>(statesKey)?.let { states = it }
        storage.decode<Map<String, Map<String, Int>>>(dailyNewKey)?.let { dailyNewByDate = it }
        storage.decode<List<String>>(inactivePacksKey)?.let { inactivePackNames = it.toSet() }
        storage.decode<Map<String, Set<String>>>(reviewedKey)?.let { reviewedByDate = it }
    }

    companion object {
        lateinit var shared: SRSStore
            internal set

        const val secondsPerDay = 86_400.0

        private const val statesKey = "srs.cardStates.v1"
        private const val dailyNewKey = "srs.dailyNewByDate.v1"
        private const val inactivePacksKey = "srs.inactivePackNames.v1"
        private const val reviewedKey = "srs.reviewedByDate.v1"

        fun initialState(key: String, alreadyKnew: Boolean, now: Date): SRSCardState =
            if (alreadyKnew) SRSCardState.knownCard(key, now) else SRSCardState.newCard(key, now)

        fun weekDayKeys(containing: Date): List<String> {
            val clock = AppClock.current
            val start = containing.localDate(clock.zone)
                .with(TemporalAdjusters.previousOrSame(clock.firstDayOfWeek))
            return (0L until 7L).map { dayKey(start.plusDays(it)) }
        }

        fun dayKey(date: Date): String = dayKey(date.localDate(AppClock.current.zone))

        internal fun dayKey(date: java.time.LocalDate): String = String.format(
            Locale.ROOT,
            "%04d-%02d-%02d",
            date.year,
            date.monthValue,
            date.dayOfMonth,
        )
    }
}
