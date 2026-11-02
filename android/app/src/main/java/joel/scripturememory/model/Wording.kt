package joel.scripturememory.model

object Wording {
    fun verses(n: Int): String = "$n ${if (n == 1) "verse" else "verses"}"
}
