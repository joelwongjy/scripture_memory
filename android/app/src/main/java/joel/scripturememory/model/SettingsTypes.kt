package joel.scripturememory.model

enum class NewCapUnit {
    day,
    week;

    val rawValue: String get() = name

    val settingTitle: String get() = if (this == day) "New Cards per Day" else "New Cards per Week"
    val pickerLabel: String get() = if (this == day) "Day" else "Week"

    companion object {
        fun fromRawValue(raw: String?): NewCapUnit? = entries.firstOrNull { it.rawValue == raw }
    }
}

data class NewCardCap(val amount: Int, val unit: NewCapUnit) {

    companion object {
        const val amountKey = "srs.newCap"
        const val dailyReviewCapKey = "srs.dailyReviewCap"
        const val dailyReviewCapDefault = 5
        const val unitKey = "srs.newCapUnit"
        const val legacyDailyKey = "srs.dailyNewCap"

        val fallback = NewCardCap(2, NewCapUnit.week)

        fun current(defaults: KeyValueStore = AppDefaults.standard): NewCardCap {
            val amount = defaults.getInt(amountKey) ?: fallback.amount
            val unit = NewCapUnit.fromRawValue(defaults.getString(unitKey)) ?: fallback.unit
            return NewCardCap(amount, unit)
        }

        fun migrateIfNeeded(defaults: KeyValueStore = AppDefaults.standard) {
            if (defaults.getInt(amountKey) != null) return
            val legacy = defaults.getInt(legacyDailyKey) ?: return
            defaults.putInt(amountKey, legacy)
            defaults.putString(unitKey, NewCapUnit.day.rawValue)
        }
    }
}

enum class StudyMode {
    firstLetter,
    fullWord,
    submit;

    val rawValue: String get() = name

    val displayName: String
        get() = when (this) {
            firstLetter -> "First Letter"
            fullWord -> "Full Word"
            submit -> "Entire Verse"
        }

    val instructions: String
        get() = when (this) {
            firstLetter -> "Type the first letter of each word to reveal it."
            fullWord -> "Type each word in full."
            submit -> "Type the whole verse, then tap Submit to check it."
        }

    val inputPlaceholder: String
        get() = if (this == fullWord) "Type each word" else "First letter of each word"

    companion object {
        const val storageKey = "studyMode"

        fun saved(defaults: KeyValueStore = AppDefaults.standard): StudyMode {
            val raw = defaults.getString(storageKey)
            return entries.firstOrNull { it.rawValue == raw } ?: firstLetter
        }
    }
}

enum class BibleVersion(val rawValue: String) {
    niv84("NIV84"),
    niv11("NIV11");

    val displayName: String
        get() = when (this) {
            niv84 -> "NIV 1984"
            niv11 -> "NIV 2011"
        }

    val packs: List<Pack> get() = if (this == niv11) niv11Packs else packsNIV84

    companion object {
        const val storageKey = "bibleVersion"

        val niv11PackNames: Set<String> = setOf("TMS 60")

        fun saved(defaults: KeyValueStore = AppDefaults.standard): BibleVersion {
            val raw = defaults.getString(storageKey)
            return entries.firstOrNull { it.rawValue == raw } ?: niv84
        }

        private val niv11Packs: List<Pack> by lazy {
            packsNIV84.map { niv84 ->
                if (niv84.name !in niv11PackNames) return@map niv84
                val pack = packsNIV11.firstOrNull { it.name == niv84.name } ?: return@map niv84
                val ids = HashMap<String, Int>()
                for (v in niv84.verses) {
                    val uid = v.cardUid ?: continue
                    if (uid !in ids) ids[uid] = v.id
                }
                pack.copy(
                    verses = pack.verses.map { v ->
                        v.copy(id = v.cardUid?.let { ids[it] } ?: v.id)
                    },
                )
            }
        }
    }
}

enum class CardAppearance {
    alwaysLight,
    matchSystem;

    val rawValue: String get() = name

    val displayName: String
        get() = when (this) {
            matchSystem -> "Match Appearance"
            alwaysLight -> "Always Light"
        }

    companion object {
        const val storageKey = "cardAppearance.v1"

        fun saved(defaults: KeyValueStore = AppDefaults.standard): CardAppearance {
            val raw = defaults.getString(storageKey)
            return entries.firstOrNull { it.rawValue == raw } ?: alwaysLight
        }
    }
}
