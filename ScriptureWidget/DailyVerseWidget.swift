import WidgetKit
import SwiftUI

// MARK: - Timeline

struct VerseEntry: TimelineEntry {
    let date:     Date
    let verse:    WidgetVerse?
    /// True when `verse` is a user-pinned spotlight (vs the live cursor).
    let isPinned: Bool
    let streak:   Int
    let dueToday: Int
    let learned:  Int
    let week:     [SharedStore.WeekDay]
}

struct VerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: Date(), verse: VerseLibrary.allVerses.first, isPinned: false,
                   streak: 0, dueToday: 0, learned: 0, week: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(resolve())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        // The app reloads us whenever the featured verse changes; this re-poll is a safety net.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [resolve()], policy: .after(next)))
    }

    /// The widget mirrors whatever the app is featuring — a pinned verse or the
    /// live cursor — both chosen in-app, so the widget itself has no configuration.
    private func resolve() -> VerseEntry {
        let snap  = SharedStore.snapshot()
        let verse = SharedStore.displayedVerse() ?? VerseLibrary.allVerses.first
        return VerseEntry(date: Date(), verse: verse, isPinned: SharedStore.isPinned(),
                          streak: snap?.streak ?? 0, dueToday: snap?.dueToday ?? 0,
                          learned: snap?.learned ?? 0, week: snap?.week ?? [])
    }
}

// MARK: - Appearance

/// Adaptive parchment background — matches the app's flashcards.
private let parchment = Color(uiColor: UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(white: 0.13, alpha: 1)
        : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
})

// MARK: - View

struct VerseEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    var body: some View {
        Group {
            if let v = entry.verse {
                content(v).widgetURL(v.deepLinkURL)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scripture Memory")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Open the app to set the verse you're learning.")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(parchment, for: .widget)
    }

    /// Mirrors the app's read-mode flashcard: title (bold serif) → reference
    /// (plain) → verse (serif) → pack label (small, bottom).
    @ViewBuilder
    private func content(_ v: WidgetVerse) -> some View {
        switch family {
        case .systemSmall:
            cardLayout(v, titleSize: 12, refSize: 10.5, verseSize: 10.5, packSize: 8,
                       gap1: 3, gap2: 3, verseSpacing: 1, titleLines: 2)
        case .systemLarge:
            largeContent(v)
        default: // systemMedium
            cardLayout(v, titleSize: 15, refSize: 13, verseSize: 13, packSize: 9,
                       gap1: 6, gap2: 5, verseSpacing: 2, titleLines: 2)
        }
    }

    private func cardLayout(_ v: WidgetVerse,
                            titleSize: CGFloat, refSize: CGFloat, verseSize: CGFloat, packSize: CGFloat,
                            gap1: CGFloat, gap2: CGFloat, verseSpacing: CGFloat, titleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(v.title)
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(titleLines)
                .minimumScaleFactor(0.8)
            Spacer().frame(height: gap1)
            Text(v.fullReference)
                .font(.system(size: refSize))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer().frame(height: gap2)
            Text(v.verse)
                .font(.system(size: verseSize, design: .serif))
                .foregroundStyle(.primary)
                .lineSpacing(verseSpacing)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: packSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(v.packName)
                    .font(.system(size: packSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Large size: the verse takes the top half; the bottom half is a retention
    /// block — streak + a week-consistency strip + a "review due" CTA. The verse
    /// is capped (taps still open full Read mode) so the stats always have room.
    private func largeContent(_ v: WidgetVerse) -> some View {
        VStack(spacing: 0) {
            // ── Top half: the verse ───────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Text(v.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2).minimumScaleFactor(0.75)
                Spacer().frame(height: 5)
                Text(v.fullReference)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer().frame(height: 7)
                Text(v.verse)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineSpacing(4)
                    .lineLimit(5)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(v.packName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // ── Bottom half: retention (centred to fill) ──────────────
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("\(entry.streak)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text("day streak")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.learned) learned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer().frame(height: 11)
                weekStrip
                Spacer().frame(height: 14)
                reviewCTA
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Duolingo-style 7-day strip: filled flame on studied days, ring on today.
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(entry.week.enumerated()), id: \.offset) { _, d in
                VStack(spacing: 4) {
                    Text(d.letter)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(d.today ? Color.orange : .secondary)
                    ZStack {
                        Circle()
                            .fill(d.done ? Color.orange : Color.primary.opacity(0.07))
                            .frame(width: 21, height: 21)
                        if d.done {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else if d.today {
                            Circle().stroke(Color.orange, lineWidth: 1.5).frame(width: 21, height: 21)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The conversion action — opens today's review session.
    private var reviewCTA: some View {
        let due = entry.dueToday
        return Link(destination: URL(string: "scripturememory://review")!) {
            HStack(spacing: 7) {
                Image(systemName: due > 0 ? "play.fill" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(due > 0 ? "Review \(due) due today" : "All caught up today")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(due > 0 ? Color.accentColor : Color.green))
        }
    }
}

// MARK: - Shared stats row

/// Three stat columns (streak · due today · learned) split by thin separators.
/// Shared by the large verse widget and the progress widget; sizes are tunable.
struct StatsColumnsView: View {
    let streak:   Int
    let dueToday: Int
    let learned:  Int
    var valueSize: CGFloat = 17
    var iconSize:  CGFloat = 11
    var labelSize: CGFloat = 10
    var sepHeight: CGFloat = 26

    var body: some View {
        HStack(spacing: 0) {
            column("flame.fill", .orange, "\(streak)", "day streak")
            separator
            column("rectangle.stack.fill", .accentColor, "\(dueToday)", "due today")
            separator
            column("checkmark.seal.fill", .green, "\(learned)", "learned")
        }
    }

    private func column(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: valueSize, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1, height: sepHeight)
    }
}

// MARK: - Widget

struct ScriptureVerseWidget: Widget {
    let kind = "ScriptureVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseEntryView(entry: entry)
        }
        .configurationDisplayName("Scripture Verse")
        .description("Your current learning verse — or one you pin in the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Progress Widget (medium)

struct ProgressEntry: TimelineEntry {
    let date:     Date
    let verse:    WidgetVerse?
    let streak:   Int
    let dueToday: Int
    let learned:  Int
}

struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }
    private func entry() -> ProgressEntry {
        let snap = SharedStore.snapshot()
        return ProgressEntry(date: Date(),
                             verse: SharedStore.displayedVerse() ?? VerseLibrary.allVerses.first,
                             streak: snap?.streak ?? 0,
                             dueToday: snap?.dueToday ?? 0,
                             learned: snap?.learned ?? 0)
    }
}

struct ProgressEntryView: View {
    let entry: ProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UP NEXT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Spacer().frame(height: 6)
            if let v = entry.verse {
                Text(v.title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.65)
                Spacer().frame(height: 3)
                Text(v.fullReference)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Open the app to begin")
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(.secondary)
            }

            // Flexible spacers above/below the rule split the slack evenly so the
            // big stat columns anchor the bottom without a lone gap up top.
            Spacer(minLength: 9)
            Divider()
            Spacer(minLength: 9)
            StatsColumnsView(streak: entry.streak, dueToday: entry.dueToday, learned: entry.learned,
                             valueSize: 26, iconSize: 15, labelSize: 12, sepHeight: 38)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(parchment, for: .widget)
        .widgetURL(entry.verse?.deepLinkURL)
    }
}

struct ScriptureProgressWidget: Widget {
    let kind = "ScriptureProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressEntryView(entry: entry)
        }
        .configurationDisplayName("Progress")
        .description("Your streak, today's reviews, and what's up next.")
        .supportedFamilies([.systemMedium])
    }
}
