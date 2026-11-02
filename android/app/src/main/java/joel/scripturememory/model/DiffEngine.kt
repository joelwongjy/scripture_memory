package joel.scripturememory.model

object DiffEngine {

    fun buildDiffs(typed: List<String>, target: List<String>): List<DiffWord> {
        val typedWords = typed.filter { normalize(it).isNotEmpty() }
        val targetWords = target.filter { normalize(it).isNotEmpty() }
        if (typedWords.isEmpty()) return targetWords.map { DiffWord(it, DiffWord.Kind.missing) }
        if (targetWords.isEmpty()) return typedWords.map { DiffWord(it, DiffWord.Kind.extra) }

        val dp = editDistanceTable(typedWords, targetWords)
        return backtrack(dp, typedWords, targetWords)
    }

    fun normalizedMatch(a: String, b: String): Boolean =
        normalize(a).canonicallyEquals(normalize(b))

    fun normalize(word: String): String {
        val stripped = word.trimmingQuotationDelimitersOnEnds()
            .lowercasedByScalar()
            .removingPunctuationAndSymbols()
            .trimmingWhitespaces()
        return SpellingVariants.canonical(stripped)
    }

    private fun editDistanceTable(typed: List<String>, target: List<String>): Array<IntArray> {
        val m = typed.size
        val n = target.size
        val dp = Array(m + 1) { IntArray(n + 1) }
        for (i in 0..m) dp[i][0] = i
        for (j in 0..n) dp[0][j] = j
        for (i in 1..m) {
            for (j in 1..n) {
                dp[i][j] = if (normalizedMatch(typed[i - 1], target[j - 1])) {
                    dp[i - 1][j - 1]
                } else {
                    1 + minOf(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        return dp
    }

    private fun backtrack(
        dp: Array<IntArray>,
        typed: List<String>,
        target: List<String>,
    ): List<DiffWord> {
        val diffs = ArrayList<DiffWord>()
        var i = typed.size
        var j = target.size
        while (i > 0 || j > 0) {
            if (i > 0 && j > 0 && normalizedMatch(typed[i - 1], target[j - 1])) {
                diffs.add(DiffWord(target[j - 1], DiffWord.Kind.correct))
                i -= 1
                j -= 1
            } else if (i > 0 && j > 0 &&
                dp[i][j] == dp[i - 1][j - 1] + 1 &&
                (j <= i || dp[i][j] < dp[i][j - 1] + 1)
            ) {
                diffs.add(DiffWord(typed[i - 1], DiffWord.Kind.wrong, target[j - 1]))
                i -= 1
                j -= 1
            } else if (j > 0 && (i == 0 || dp[i][j - 1] <= dp[i - 1][j])) {
                diffs.add(DiffWord(target[j - 1], DiffWord.Kind.missing))
                j -= 1
            } else {
                diffs.add(DiffWord(typed[i - 1], DiffWord.Kind.extra))
                i -= 1
            }
        }
        return diffs.asReversed().toList()
    }
}
