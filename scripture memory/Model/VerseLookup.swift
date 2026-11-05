import Foundation

struct VerseLookupResult: Equatable {
    let text: String
    let title: String
}

extension VerseTranslation {

    static func bundledPacks(for code: String) -> [Pack]? {
        switch code.uppercased() {
        case niv:   return packsNIV11
        case niv84: return packsNIV84
        default:    return nil
        }
    }
}

enum VerseLookup {

    static func bundled(_ reference: BibleReference, translation: String) -> VerseLookupResult? {
        guard let packs = VerseTranslation.bundledPacks(for: translation) else { return nil }
        let wanted = SRSKey.normalizedReference(reference.reference)
        for pack in packs {
            for verse in pack.verses where verse.pinnedVersion == nil {
                guard SRSKey.normalizedReference(verse.reference) == wanted,
                      BibleBooks.book(named: verse.book) == reference.book else { continue }
                return VerseLookupResult(text: verse.verse, title: verse.title)
            }
        }
        return nil
    }
}
