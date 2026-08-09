import Foundation

/// The visible verses, flattened out of their packs — memoized.
///
/// `packs.flatMap(\.verses)` reads as free and isn't: it allocates a fresh
/// ~490-element array, and every `Verse` in it carries seven strings to retain.
/// Screens ask for it inside `body`, and `body` runs on every frame of any
/// animation touching the screen — the search bar sliding up, a row expanding.
/// At that rate the copying is enough to drop frames and make a system
/// animation look sluggish.
///
/// The pack set only changes when the translation, pack order or hidden set
/// does, so the flattened list is computed once per such change and handed back
/// unchanged in between (arrays are copy-on-write, so callers share storage).
@MainActor
enum Catalogue {

    private static var cached: (token: Int, verses: [Verse])?

    /// Every verse in `packs`, in pack order.
    static func verses(in packs: [Pack]) -> [Verse] {
        let token = fingerprint(packs)
        if let cached, cached.token == token { return cached.verses }
        let flattened = packs.flatMap(\.verses)
        cached = (token, flattened)
        return flattened
    }

    /// Cheap stand-in for "is this the same pack set?" — names and sizes. The
    /// three things that change it in practice (translation, pack order, pack
    /// visibility) all move one or the other.
    static func fingerprint(_ packs: [Pack]) -> Int {
        var hasher = Hasher()
        for pack in packs {
            hasher.combine(pack.name)
            hasher.combine(pack.verses.count)
        }
        return hasher.finalize()
    }
}
