import Foundation

/// British and American spellings of the same word, treated as the same word.
///
/// The packs are printed in several editions and people learn from whichever
/// they own, so someone who writes `saviour` against an NIV card reading
/// `savior` has recalled the verse correctly and shouldn't be marked wrong.
///
/// A fixed list rather than a rule like "-our → -or". Scripture vocabulary is
/// small enough to enumerate, and suffix rules misfire on ordinary words —
/// `four`, `hour`, `pour`, `devour` all end in "our", and `wise`, `praise`,
/// `promise`, `paradise` all end in "ise". A rule would have to carry a longer
/// list of exceptions than this list of words.
///
/// Foundation-only so it stays unit-testable alongside `DiffEngine`.
enum SpellingVariants {

    /// British → American stems. Only the stem is listed; the common inflections
    /// are generated below, so `honour` also covers `honours`, `honoured`,
    /// `honouring` and `honourable`.
    private static let stems: [(british: String, american: String)] = [
        ("saviour",   "savior"),
        ("honour",    "honor"),
        ("favour",    "favor"),
        ("labour",    "labor"),
        ("neighbour", "neighbor"),
        ("colour",    "color"),
        ("splendour", "splendor"),
        ("vigour",    "vigor"),
        ("valour",    "valor"),
        ("armour",    "armor"),
        ("harbour",   "harbor"),
        ("odour",     "odor"),
        ("rumour",    "rumor"),
        ("clamour",   "clamor"),
        ("endeavour", "endeavor"),
        ("behaviour", "behavior"),
        ("humour",    "humor"),
        ("marvellous","marvelous"),
        ("counsellor","counselor"),
        ("traveller", "traveler"),
        ("worshipper","worshiper"),
        ("defence",   "defense"),
        ("offence",   "offense"),
        ("pretence",  "pretense"),
        ("realise",   "realize"),
        ("baptise",   "baptize"),
        ("recognise", "recognize"),
        ("apologise", "apologize"),
        ("centre",    "center"),
        ("fulfil",    "fulfill"),
        ("skilful",   "skillful"),
        ("wilful",    "willful"),
        ("judgement", "judgment"),
        ("grey",      "gray"),
        ("plough",    "plow"),
        ("enrolment", "enrollment"),
        ("practise",  "practice"),
    ]

    /// Suffixes applied to both sides of each pair. Some combinations aren't
    /// real words (`greys`, `centreing`); an unreachable key costs nothing and
    /// keeping the list uniform is simpler than curating per word.
    private static let suffixes = ["", "s", "es", "ed", "d", "ing", "er", "ers", "able", "ably"]

    /// Every accepted British form mapped to its American equivalent.
    private static let map: [String: String] = {
        var map: [String: String] = [:]
        for (british, american) in stems {
            for suffix in suffixes {
                map[british + suffix] = american + suffix
            }
            // `fulfil`/`fulfill` and friends double the consonant before a vowel
            // suffix, so the naive concatenation above misses `fulfilled`.
            if let last = british.last, british.count == american.count - 1 {
                for suffix in ["ed", "ing", "er", "ers"] {
                    map[british + String(last) + suffix] = american + suffix
                }
            }
        }
        return map
    }()

    /// The American spelling when `word` is a known British variant, otherwise
    /// `word` unchanged. Expects an already-lowercased, punctuation-stripped
    /// token.
    static func canonical(_ word: String) -> String {
        map[word] ?? word
    }
}
