package joel.scripturememory.model

import java.time.DayOfWeek
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoldenVectorTests {

    private fun load(name: String): JsonObject =
        Json.parseToJsonElement(Repo.vectors.resolve(name).readText()).jsonObject

    private fun JsonObject.cases(name: String): List<JsonObject> {
        val cases = getValue(name).jsonArray.map { it.jsonObject }
        assertTrue("$name is empty", cases.isNotEmpty())
        return cases
    }

    private fun JsonElement.string(): String = jsonPrimitive.content
    private fun JsonElement.strings(): List<String> = jsonArray.map { it.string() }
    private fun JsonElement.ints(): List<Int> = jsonArray.map { it.jsonPrimitive.int }
    private fun JsonObject.s(key: String): String = getValue(key).string()
    private fun JsonObject.i(key: String): Int = getValue(key).jsonPrimitive.int
    private fun JsonObject.d(key: String): Double = getValue(key).jsonPrimitive.double
    private fun JsonObject.b(key: String): Boolean = getValue(key).jsonPrimitive.boolean

    private fun state(element: JsonElement): SRSCardState =
        ProgressJson.decodeFromJsonElement(SRSCardState.serializer(), element)

    private fun assertState(expected: SRSCardState, actual: SRSCardState, message: String) {
        assertEquals("$message key", expected.key, actual.key)
        assertEquals("$message phase", expected.phase, actual.phase)
        assertEquals("$message interval", expected.interval, actual.interval, tolerance)
        assertEquals("$message ease", expected.ease, actual.ease, tolerance)
        assertEquals("$message reps", expected.reps, actual.reps)
        assertEquals("$message lapses", expected.lapses, actual.lapses)
        assertEquals("$message learningStep", expected.learningStep, actual.learningStep)
        assertEquals(
            "$message due",
            expected.due.timeIntervalSinceReferenceDate,
            actual.due.timeIntervalSinceReferenceDate,
            tolerance,
        )
        assertEquals(
            "$message lastReviewed",
            expected.lastReviewed?.timeIntervalSinceReferenceDate,
            actual.lastReviewed?.timeIntervalSinceReferenceDate,
        )
    }

    private fun config(element: JsonElement?): SRSConfig {
        if (element == null || element is JsonNull) return SRSConfig.default
        val c = element.jsonObject
        return SRSConfig(
            learningSteps = c.getValue("learningSteps").jsonArray.map { it.jsonPrimitive.double },
            graduatingInterval = c.d("graduatingInterval"),
            easyInterval = c.d("easyInterval"),
            startingEase = c.d("startingEase"),
            easeFloor = c.d("easeFloor"),
            easeBonus = c.d("easeBonus"),
            easePenaltyHard = c.d("easePenaltyHard"),
            easePenaltyAgain = c.d("easePenaltyAgain"),
            hardIntervalMultiplier = c.d("hardIntervalMultiplier"),
            easyMultiplier = c.d("easyMultiplier"),
            knownCardInterval = c.d("knownCardInterval"),
        )
    }

    @Test
    fun srsSteps() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("steps")) {
            val name = c.s("name")
            val cfg = config(c["config"])
            val grade = SRSGrade.valueOf(c.s("grade"))
            val now = Date(c.d("now"))
            val input = state(c.getValue("state"))
            assertState(state(c.getValue("expected")), updateSRS(input, grade, now, cfg), name)
            assertEquals(name, c.s("label"), predictedIntervalLabel(input, grade, now, cfg))
        }
    }

    @Test
    fun srsSequences() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("sequences")) {
            var s = state(c.getValue("initial"))
            c.getValue("steps").jsonArray.forEachIndexed { i, element ->
                val step = element.jsonObject
                s = updateSRS(s, SRSGrade.valueOf(step.s("grade")), Date(step.d("now")))
                assertState(state(step.getValue("state")), s, "${c.s("name")} step $i")
            }
        }
    }

    @Test
    fun srsLabels() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("labels")) {
            val now = Date(c.d("now"))
            val cfg = SRSConfig(learningSteps = listOf(c.d("seconds")))
            val label = predictedIntervalLabel(SRSCardState.newCard("k", now), SRSGrade.again, now, cfg)
            assertEquals("${c.d("seconds")}", c.s("label"), label)
        }
    }

    @Test
    fun srsInitialStates() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("initialStates")) {
            val now = Date(c.d("now"))
            val actual = when (c.s("kind")) {
                "new" -> SRSCardState.newCard(c.s("key"), now)
                "known" -> SRSCardState.knownCard(c.s("key"), now)
                else -> SRSCardState.justLearnt(c.s("key"), now)
            }
            assertState(state(c.getValue("expected")), actual, c.s("kind"))
        }
    }

    @Test
    fun suggestedGrades() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("suggestedGrades")) {
            assertEquals(c.s("expected"), suggestedGrade(c.b("isAllCorrect"), c.i("mistakes")).name)
        }
    }

    @Test
    fun cardStateJsonRoundTripsThroughTheStoredFormat() {
        val v = load("srs_scheduling.json")
        for (c in v.cases("steps").take(200)) {
            val decoded = state(c.getValue("expected"))
            val encoded = ProgressJson.encodeToJsonElement(SRSCardState.serializer(), decoded)
            assertEquals(
                c.getValue("expected").jsonObject.keys,
                encoded.jsonObject.keys,
            )
            assertEquals(decoded, state(encoded))
        }
    }

    @Test
    fun dripBudget() {
        for (c in load("srs_math.json").cases("drip")) {
            val actual = SRSMath.dripBudget(c.i("budget"), c.getValue("candidates").ints())
            assertEquals(c.getValue("expected").ints(), actual)
        }
    }

    @Test
    fun wordTokens() {
        val v = load("text_tokens.json")
        for (section in listOf("tokens", "darwinTokens")) {
            for (c in v.cases(section)) {
                assertEquals(c.s("input"), c.getValue("expected").strings(), c.s("input").wordTokens)
            }
        }
    }

    @Test
    fun quoteTrimming() {
        for (c in load("text_tokens.json").cases("quotes")) {
            assertEquals(c.s("input"), c.s("expected"), c.s("input").trimmingQuotationDelimitersOnEnds())
        }
    }

    @Test
    fun legacyKeys() {
        for (c in load("text_tokens.json").cases("legacyKeys")) {
            assertEquals(c.s("expected"), SRSKey.make(c.s("pack"), c.s("book"), c.s("reference")))
        }
    }

    private class Digest {
        private var hash = 0xcbf29ce484222325uL
        var count = 0
            private set

        fun add(text: String) {
            for (byte in text.encodeToByteArray()) {
                hash = (hash xor byte.toUByte().toULong()) * 0x00000100000001B3uL
            }
            count += 1
        }

        val hex: String get() = hash.toString(16)
    }

    private fun bundledVerses(file: String): List<Verse> =
        Repo.openAsset(file).use { input ->
            ProgressJson.decodeFromString<List<Pack>>(input.readBytes().decodeToString())
        }.flatMap { it.verses }

    @Test
    fun catalogTokensMatchSwift() {
        for (c in load("text_tokens.json").cases("catalog")) {
            val digest = Digest()
            for (verse in bundledVerses(c.s("file"))) {
                (verse.titleWords + verse.verseWords).forEach(digest::add)
            }
            assertEquals(c.s("file"), c.i("count"), digest.count)
            assertEquals(c.s("file"), c.s("digest"), digest.hex)
        }
    }

    @Test
    fun catalogDiffsMatchSwift() {
        for (c in load("diff_engine.json").cases("catalog")) {
            val digest = Digest()
            for (verse in bundledVerses(c.s("file"))) {
                val target = verse.verseWords
                val typed = ArrayList<String>()
                target.forEachIndexed { i, token ->
                    when {
                        i % 7 == 3 -> Unit
                        i % 11 == 5 -> typed.add("xyzzy")
                        i % 5 == 0 -> typed.add(token.uppercase(java.util.Locale.ROOT))
                        else -> typed.add(token)
                    }
                }
                for (word in DiffEngine.buildDiffs(typed, target)) {
                    digest.add("${word.kind}|${word.text}|${word.correction ?: ""}")
                }
            }
            assertEquals(c.s("file"), c.i("count"), digest.count)
            assertEquals(c.s("file"), c.s("digest"), digest.hex)
        }
    }

    private fun assertRanges(
        name: String,
        ranges: JsonElement,
        matches: (Int) -> Boolean,
    ) {
        val expected = HashSet<Int>()
        for (range in ranges.jsonArray) {
            val (start, end) = range.ints()
            for (cp in start..end) expected.add(cp)
        }
        for (cp in 0 until 0x3400) {
            if (cp in 0xD800..0xDFFF) continue
            if (Character.getType(cp) == Character.UNASSIGNED.toInt()) continue
            assertEquals("$name U+${cp.toString(16)}", cp in expected, matches(cp))
        }
    }

    @Test
    fun whitespaceSetsMatchFoundation() {
        val sets = load("text_tokens.json").cases("darwinCharacterSets")
        val whitespaces = sets.first { it.s("name") == "whitespaces" }
        val newlines = sets.first { it.s("name") == "whitespacesAndNewlines" }
        assertRanges("whitespaces", whitespaces.getValue("ranges")) {
            String(Character.toChars(it)).trimmingWhitespaces().isEmpty()
        }
        assertRanges("whitespacesAndNewlines", newlines.getValue("ranges")) {
            String(Character.toChars(it)).trimmingWhitespacesAndNewlines().isEmpty()
        }
    }

    @Test
    fun punctuationSetMatchesFoundation() {
        val set = load("diff_engine.json").cases("darwinCharacterSets").single()
        assertRanges("punctuationAndSymbols", set.getValue("ranges"), ::isPunctuationOrSymbol)
    }

    @Test
    fun diffs() {
        for (c in load("diff_engine.json").cases("diffs")) {
            val actual = DiffEngine.buildDiffs(
                c.getValue("typed").strings(),
                c.getValue("target").strings(),
            )
            val expected = c.getValue("expected").jsonArray.map { it.jsonObject }
            assertEquals(c.s("name"), expected.map { it.s("kind") }, actual.map { it.kind.name })
            assertEquals(c.s("name"), expected.map { it.s("text") }, actual.map { it.text })
            assertEquals(
                c.s("name"),
                expected.map { it["correction"]?.string() },
                actual.map { it.correction },
            )
        }
    }

    @Test
    fun normalize() {
        for (c in load("diff_engine.json").cases("normalize")) {
            assertEquals(c.s("input"), c.s("expected"), DiffEngine.normalize(c.s("input")))
        }
    }

    @Test
    fun normalizedMatches() {
        for (c in load("diff_engine.json").cases("matches")) {
            assertEquals("${c.s("a")} / ${c.s("b")}", c.b("expected"), DiffEngine.normalizedMatch(c.s("a"), c.s("b")))
        }
    }

    @Test
    fun spellingVariants() {
        for (c in load("spelling_variants.json").cases("canonical")) {
            assertEquals(c.s("input"), c.s("expected"), SpellingVariants.canonical(c.s("input")))
        }
    }

    @Test
    fun reminderPlanBasics() {
        val v = load("reminder_plan.json")
        for (c in v.cases("shouldSchedule")) {
            assertEquals(c.b("expected"), ReminderPlan.shouldSchedule(c.b("enabled"), c.b("authorized")))
        }
        for (c in v.cases("normalizedTime")) {
            val time = ReminderPlan.normalizedTime(c.i("hour"), c.i("minute"))
            assertEquals(c.i("expectedHour"), time.hour)
            assertEquals(c.i("expectedMinute"), time.minute)
        }
        for (c in v.cases("reminderBody")) {
            assertEquals(c["expected"]?.string(), ReminderPlan.reminderBody(c.i("review"), c.i("new")))
        }
    }

    private fun assertFire(c: JsonObject) {
        val actual = ReminderPlan.nextFireDate(
            c.i("hour"),
            c.i("minute"),
            Date(c.d("after")),
            ZoneId.of(c.s("zone")),
        )
        assertEquals(
            "${c.s("zone")} ${c.i("hour")}:${c.i("minute")} after ${c.d("after")}",
            c.d("expected"),
            actual!!.timeIntervalSinceReferenceDate,
            tolerance,
        )
    }

    @Test
    fun nextFireDateUtc() {
        load("reminder_plan.json").cases("nextFireDate").forEach(::assertFire)
    }

    @Test
    fun nextFireDateAcrossDaylightSaving() {
        load("reminder_plan.json").cases("darwinNextFireDate").forEach(::assertFire)
    }

    @Test
    fun scrubberMath() {
        val v = load("scrubber_math.json")
        for (c in v.cases("fraction")) {
            assertEquals(c.d("expected"), ScrubberMath.fraction(c.i("index"), c.i("count")), tolerance)
        }
        for (c in v.cases("index")) {
            assertEquals(
                "${c.d("fraction")} of ${c.i("count")}",
                c.i("expected"),
                ScrubberMath.index(c.d("fraction"), c.i("count")),
            )
        }
        for (c in v.cases("trackTravel")) {
            val actual = ScrubberMath.trackTravel(c.d("containerHeight"), c.d("thumbSize"), c.d("inset"))
            assertEquals(c.d("expected"), actual, tolerance)
        }
        for (c in v.cases("thumbYIndex")) {
            val actual = ScrubberMath.thumbY(c.i("index"), c.i("count"), c.d("travel"), c.d("inset"))
            assertEquals(c.d("expected"), actual, tolerance)
        }
        for (c in v.cases("thumbYFraction")) {
            val actual = ScrubberMath.thumbY(c.d("fraction"), c.d("travel"), c.d("inset"))
            assertEquals(c.d("expected"), actual, tolerance)
        }
        for (c in v.cases("fractionForDrag")) {
            val actual = ScrubberMath.fractionForDrag(
                c.d("startThumbY"),
                c.d("translationY"),
                c.d("inset"),
                c.d("travel"),
            )
            assertEquals(c.d("expected"), actual, tolerance)
        }
        for (c in v.cases("indexForDrag")) {
            val actual = ScrubberMath.indexForDrag(
                c.d("startThumbY"),
                c.d("translationY"),
                c.d("inset"),
                c.d("travel"),
                c.i("count"),
            )
            assertEquals(c.i("expected"), actual)
        }
    }

    @Test
    fun packArranger() {
        val v = load("pack_arranger.json")
        for (c in v.cases("arranged")) {
            val actual = PackArranger.arrangedNames(c.getValue("order").strings(), c.getValue("all").strings())
            assertEquals(c.getValue("expected").strings(), actual)
        }
        for (c in v.cases("visible")) {
            val actual = PackArranger.visibleNames(
                c.getValue("order").strings(),
                c.getValue("hidden").strings().toSet(),
                c.getValue("all").strings(),
            )
            assertEquals(c.getValue("expected").strings(), actual)
        }
        for (c in v.cases("moved")) {
            val actual = PackArranger.movedOrder(
                c.getValue("arranged").strings(),
                c.getValue("source").ints().toSet(),
                c.i("destination"),
            )
            assertEquals(c.getValue("expected").strings(), actual)
        }
    }

    @Test
    fun calendar() {
        val previous = AppClock.current
        try {
            for (c in load("calendar.json").cases("darwinDays")) {
                val clock = TestClock(
                    date = Date(c.d("date")),
                    zone = ZoneId.of(c.s("zone")),
                    firstDayOfWeek = when (c.i("firstWeekday")) {
                        1 -> DayOfWeek.SUNDAY
                        2 -> DayOfWeek.MONDAY
                        else -> DayOfWeek.SATURDAY
                    },
                )
                AppClock.current = clock
                val message = "${c.s("zone")} ${c.d("date")}"
                assertEquals(message, c.s("dayKey"), SRSStore.dayKey(clock.date))
                assertEquals(message, c.getValue("weekDayKeys").strings(), SRSStore.weekDayKeys(clock.date))
                val cutoff = clock.date.atZone(clock.zone).minusDays(14).toLocalDate()
                assertEquals(message, c.s("pruneCutoffKey"), SRSStore.dayKey(cutoff))
            }
        } finally {
            AppClock.current = previous
        }
    }

    private companion object {
        const val tolerance = 1e-9
    }
}
