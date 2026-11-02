package joel.scripturememory.model

val quotationDelimiterCharacters: Set<Char> = setOf(
    '"', '\'', '`',
    '‘', '’', '“', '”',
    '«', '»', '‹', '›',
)

fun String.trimmingQuotationDelimitersOnEnds(): String =
    trimStart { it in quotationDelimiterCharacters }
        .trimEnd { it in quotationDelimiterCharacters }

val String.wordTokens: List<String>
    get() = split(" ")
        .map { it.trimmingWhitespaces() }
        .filter { it.isNotEmpty() }
        .flatMap { piece ->
            piece.split("--")
                .map { it.trimmingWhitespaces() }
                .filter { it.isNotEmpty() }
        }
        .map { it.trimmingQuotationDelimitersOnEnds() }
        .filter { it.isNotEmpty() }
