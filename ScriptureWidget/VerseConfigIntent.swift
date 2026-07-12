import AppIntents

// MARK: - Pack (first level)

struct PackEntity: AppEntity {
    let id: String   // pack name

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pack"
    static var defaultQuery = PackEntityQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct PackEntityQuery: EntityQuery {
    func entities(for identifiers: [PackEntity.ID]) async throws -> [PackEntity] {
        Self.packNames.filter { identifiers.contains($0) }.map { PackEntity(id: $0) }
    }
    func suggestedEntities() async throws -> [PackEntity] {
        Self.packNames.map { PackEntity(id: $0) }
    }

    /// Distinct pack names, in catalogue order.
    static let packNames: [String] = {
        var seen = Set<String>(), result = [String]()
        for v in VerseLibrary.allVerses where !seen.contains(v.packName) {
            seen.insert(v.packName); result.append(v.packName)
        }
        return result
    }()
}

// MARK: - Verse (second level — filtered by the chosen pack)

struct VerseEntity: AppEntity {
    let id:        String   // matches `WidgetVerse.id`
    let reference: String
    let packName:  String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Verse"
    static var defaultQuery = VerseEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(reference)", subtitle: "\(packName)")
    }

    /// Sentinel the picker offers at the top so the user can RESET a pinned verse
    /// back to "follow my current learning verse" (an optional entity param has no
    /// obvious clear control otherwise).
    static let currentSentinelID = "__current__"
    static var currentSentinel: VerseEntity {
        VerseEntity(id: currentSentinelID, reference: "Current learning verse", packName: "Follows your progress")
    }
}

struct VerseEntityQuery: EntityQuery {
    /// Read the pack the user picked in the same configuration so the verse list
    /// can be narrowed to it (the full ~480-verse list is too long).
    @IntentParameterDependency<VerseConfigIntent>(\.$pack)
    var config

    func entities(for identifiers: [VerseEntity.ID]) async throws -> [VerseEntity] {
        var result: [VerseEntity] = []
        for id in identifiers {
            if id == VerseEntity.currentSentinelID {
                result.append(VerseEntity.currentSentinel)
            } else if let v = VerseLibrary.verse(id: id) {
                result.append(v.entity)
            }
        }
        return result
    }

    func suggestedEntities() async throws -> [VerseEntity] {
        let all = VerseLibrary.allVerses
        let filtered: [WidgetVerse]
        if let packName = config?.pack.id {
            filtered = all.filter { $0.packName == packName }
        } else {
            filtered = all
        }
        // "Current learning verse" first so resetting is always one tap away.
        return [VerseEntity.currentSentinel] + filtered.map { $0.entity }
    }
}

extension WidgetVerse {
    var entity: VerseEntity { VerseEntity(id: id, reference: fullReference, packName: packName) }
}

// MARK: - Configuration

struct VerseConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Verse"
    static var description = IntentDescription("Show your current learning verse, or pin a specific one — pick a pack first to shorten the list.")

    @Parameter(title: "Pack", description: "Narrow the verse list to one pack.")
    var pack: PackEntity?

    @Parameter(title: "Verse", description: "Leave empty to follow your current learning verse.")
    var verse: VerseEntity?
}
