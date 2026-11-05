package joel.scripturememory.model

data class AnkiVerseCandidate(
    val deck: String,
    val reference: BibleReference,
    val text: String,
    val title: String,
    val version: String?,
    val schedule: AnkiCardSchedule? = null,
) {
    val hasProgress: Boolean get() = schedule?.let { it.kind != AnkiCardSchedule.Kind.New } ?: false
}

data class AnkiImportPlan(
    val decks: List<Deck>,
    val matches: List<Match>,
    val skipped: List<String>,
) {
    data class Deck(val name: String, val verses: List<AnkiVerseCandidate>)

    data class Match(val cardUid: String, val candidate: AnkiVerseCandidate)
}

enum class AnkiFieldRole { reference, text, title }

object AnkiVerseImport {

    fun plan(
        source: AnkiImport,
        bundledKeys: Map<String, String> = emptyMap(),
        fallbackName: String = "OYO",
    ): AnkiImportPlan {
        val roles = source.notes.map { it.noteType }.toSet().associateWith { type ->
            guessRoles(source.notes.filter { it.noteType == type })
        }

        val decks = mutableListOf<AnkiImportPlan.Deck>()
        val matches = mutableListOf<AnkiImportPlan.Match>()
        val skipped = mutableListOf<String>()
        val seen = HashSet<String>()

        for (note in source.notes) {
            val found = candidate(note, roles[note.noteType].orEmpty())
            if (found == null) {
                skipped += note.fields.firstOrNull { it.isNotEmpty() }.orEmpty()
                continue
            }
            val candidate = found.copy(schedule = bestSchedule(note.cards))
            val key = referenceKey(candidate.reference.book.name, candidate.reference.reference)
            val uid = bundledKeys[key]
            if (uid != null) {
                if (matches.none { it.cardUid == uid }) matches += AnkiImportPlan.Match(uid, candidate)
                continue
            }
            if (!seen.add(note.deck + "|" + key)) continue
            val name = deckDisplayName(note.deck, fallbackName)
            val i = decks.indexOfFirst { it.name == name }
            if (i >= 0) {
                decks[i] = decks[i].copy(verses = decks[i].verses + candidate)
            } else {
                decks += AnkiImportPlan.Deck(name, listOf(candidate))
            }
        }
        return AnkiImportPlan(decks, matches, skipped)
    }

    fun referenceKey(book: String, reference: String): String =
        (BibleBooks.book(book)?.usfm ?: book.lowercase()) + "|" + SRSKey.normalizedReference(reference)

    fun deckDisplayName(deck: String, fallback: String = "OYO"): String {
        val leaf = deck.split("::").last().trimmingWhitespaces()
        return if (leaf.isEmpty() || leaf == "Default") fallback else leaf
    }

    private val referenceNames = listOf("reference", "ref", "address", "verse reference", "passage")
    private val textNames = listOf("text", "verse", "verse text", "scripture", "back", "answer")
    private val titleNames = listOf("topic", "title", "theme", "heading", "subject", "category")

    fun guessRoles(notes: List<AnkiNote>): List<AnkiFieldRole?> {
        val count = notes.maxOfOrNull { it.fields.size } ?: 0
        if (count <= 0 || notes.isEmpty()) return emptyList()
        val names = notes.first().fieldNames.map { it.lowercase().trimmingWhitespaces() }
        fun values(i: Int): List<String> = notes.map { it.fields.getOrElse(i) { "" } }
        fun share(i: Int, test: (String) -> Boolean): Double {
            val filled = values(i).filter { it.isNotEmpty() }
            return if (filled.isEmpty()) 0.0 else filled.count(test).toDouble() / filled.size
        }
        fun averageLength(i: Int): Double {
            val filled = values(i).filter { it.isNotEmpty() }
            return if (filled.isEmpty()) 0.0 else filled.sumOf { it.length }.toDouble() / filled.size
        }

        val roles = MutableList<AnkiFieldRole?>(count) { null }
        val referenceScores = (0 until count).map { i -> share(i) { BibleReference.parse(it) != null } }
        val best = referenceScores.indices.maxByOrNull { referenceScores[it] }
        val named = names.indexOfFirst { it in referenceNames }
        if (best != null && referenceScores[best] >= 0.6) {
            roles[best] = AnkiFieldRole.reference
        } else if (named in 0 until count) {
            roles[named] = AnkiFieldRole.reference
        }

        val open = (0 until count).filter { roles[it] == null }
        val textIndex = open.firstOrNull { i -> i < names.size && names[i] in textNames && averageLength(i) > 20 }
            ?: open.maxByOrNull { averageLength(it) }
        if (textIndex != null && averageLength(textIndex) > 0) roles[textIndex] = AnkiFieldRole.text

        val rest = (0 until count).filter { roles[it] == null && averageLength(it) > 0 }
        val titleIndex = rest.firstOrNull { i -> i < names.size && names[i] in titleNames }
            ?: rest.firstOrNull { i -> averageLength(i) <= 60 && share(i) { BibleReference.parse(it) == null } >= 0.8 }
        if (titleIndex != null) roles[titleIndex] = AnkiFieldRole.title
        return roles
    }

    fun candidate(note: AnkiNote, roles: List<AnkiFieldRole?>): AnkiVerseCandidate? {
        fun field(role: AnkiFieldRole): String? {
            val i = roles.indexOf(role)
            if (i < 0 || i >= note.fields.size) return null
            return note.fields[i].trimmingWhitespacesAndNewlines().ifEmpty { null }
        }
        val title = field(AnkiFieldRole.title)?.replace("\n", " ").orEmpty()
        val hint = versionHint(note.deck + " " + note.noteType + " " + note.tags.joinToString(" "))

        val raw = field(AnkiFieldRole.reference)
        val text = field(AnkiFieldRole.text)
        if (raw != null && text != null) {
            val pastedRef = PastedVerse.parse(raw)
            val reference = BibleReference.parse(raw) ?: pastedRef.reference
            val body = PastedVerse.parse(text)
            if (reference != null && body.text.isNotEmpty()) {
                return AnkiVerseCandidate(
                    deck = note.deck,
                    reference = reference,
                    text = PastedVerse.cleaned(body.text, reference),
                    title = title,
                    version = pastedRef.version ?: body.version ?: hint,
                )
            }
        }

        val ordered = roles.indices.filter { roles[it] != AnkiFieldRole.title } +
            roles.indices.filter { roles[it] == AnkiFieldRole.title }
        val combined = (if (ordered.isEmpty()) note.fields.indices.toList() else ordered)
            .filter { it < note.fields.size && note.fields[it].isNotEmpty() && roles.getOrNull(it) != AnkiFieldRole.title }
            .joinToString("\n") { note.fields[it] }
        val pasted = PastedVerse.parse(combined)
        val reference = pasted.reference ?: return null
        if (pasted.text.swiftSplit(' ').size < 3) return null
        return AnkiVerseCandidate(note.deck, reference, pasted.text, title, pasted.version ?: hint)
    }

    private fun versionHint(text: String): String? {
        val words = text.uppercase().splitWhere { !it.isLetterOrDigit() }.filter { it.isNotEmpty() }.toSet()
        return listOf("NIV84", "NIV", "ESV", "NKJV", "KJV", "NLT", "NASB", "CSB", "BSB", "NRSV").firstOrNull { it in words }
    }

    private fun String.splitWhere(isSeparator: (Char) -> Boolean): List<String> {
        val parts = mutableListOf<String>()
        val part = StringBuilder()
        for (c in this) {
            if (isSeparator(c)) {
                parts += part.toString()
                part.clear()
            } else {
                part.append(c)
            }
        }
        parts += part.toString()
        return parts
    }

    fun bestSchedule(cards: List<AnkiCardSchedule>): AnkiCardSchedule? {
        val pool = if (cards.any { !it.isSuspended }) cards.filter { !it.isSuspended } else cards
        return pool.maxWithOrNull(compareBy({ it.intervalDays }, { rank(it.kind) }))
    }

    private fun rank(kind: AnkiCardSchedule.Kind): Int = when (kind) {
        AnkiCardSchedule.Kind.New -> 0
        AnkiCardSchedule.Kind.Learning -> 1
        AnkiCardSchedule.Kind.Relearning -> 2
        AnkiCardSchedule.Kind.Review -> 3
    }

    fun state(
        schedule: AnkiCardSchedule,
        key: String,
        now: Date,
        config: SRSConfig = SRSConfig.default,
    ): SRSCardState? {
        val ease = if (schedule.ease > 0) maxOf(schedule.ease, config.easeFloor) else config.startingEase
        val due = schedule.due ?: now
        val lastReviewed = schedule.lastReviewed ?: now
        return when (schedule.kind) {
            AnkiCardSchedule.Kind.New -> null
            AnkiCardSchedule.Kind.Learning -> SRSCardState(
                key, SRSPhase.learning, 0.0, ease, schedule.reps, schedule.lapses, 0, due, lastReviewed,
            )
            AnkiCardSchedule.Kind.Relearning -> SRSCardState(
                key, SRSPhase.learning, maxOf(schedule.intervalDays, 1.0), ease, schedule.reps, schedule.lapses, 0,
                due, lastReviewed,
            )
            AnkiCardSchedule.Kind.Review -> SRSCardState(
                key, SRSPhase.review, maxOf(schedule.intervalDays, 1.0), ease, maxOf(schedule.reps, 1),
                schedule.lapses, 0, due, lastReviewed,
            )
        }
    }
}
