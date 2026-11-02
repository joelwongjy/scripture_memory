package joel.scripturememory.model

object HintFill {

    fun words(text: String): List<String> =
        text.split(Regex("[ \\n\\u000B\\u000C\\r\\u0085\\u2028\\u2029]+")).filter { it.isNotEmpty() }

    fun next(target: String, typed: String): String? {
        val targetWords = words(target)
        val typedCount = words(typed).size
        if (typedCount >= targetWords.size) return null
        return targetWords.take(typedCount + 1).joinToString(" ")
    }
}
