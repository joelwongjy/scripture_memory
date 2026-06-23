import Foundation
import WidgetKit

/// Bridges a small snapshot (current learning verse + streak + cards due today)
/// into the shared App Group so the widget can render it. Call ``update`` whenever
/// any of those might have changed; it reloads widget timelines only when the
/// stored snapshot actually differs, so it's cheap to call often.
enum WidgetBridge {
    /// Shared between the app and the widget extension (see both .entitlements).
    static let appGroup    = "group.joel.scripture-memory"
    static let snapshotKey = "widget.snapshot.v1"

    /// Compact, Codable mirror of a verse — enough to render and to deep-link back.
    struct SharedVerse: Codable, Equatable {
        var title:     String
        var verse:     String
        var book:      String
        var reference: String
        var packName:  String
    }

    /// One day in the week-consistency strip.
    struct WeekDay: Codable, Equatable {
        var letter: String
        var done:   Bool
        var today:  Bool
    }

    struct Snapshot: Codable, Equatable {
        var verse:    SharedVerse?
        /// True when `verse` is a user-pinned spotlight rather than the live cursor.
        var isPinned: Bool = false
        var streak:   Int
        var dueToday: Int
        var learned:  Int
        var week:     [WeekDay]
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Persist the verse to feature (pinned or current) + stats. Reloads widget
    /// timelines only when the snapshot changes.
    static func update(verse: Verse?, isPinned: Bool, streak: Int, dueToday: Int, learned: Int, week: [WeekDay]) {
        guard let defaults else { return }
        let snap = Snapshot(
            verse: verse.map {
                SharedVerse(title: $0.title, verse: $0.verse, book: $0.book,
                            reference: $0.reference, packName: $0.packName)
            },
            isPinned: isPinned,
            streak: streak,
            dueToday: dueToday,
            learned: learned,
            week: week
        )
        let newData = try? JSONEncoder().encode(snap)
        guard newData != defaults.data(forKey: snapshotKey) else { return }   // no change → no reload
        if let newData { defaults.set(newData, forKey: snapshotKey) }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
