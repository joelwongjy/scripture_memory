import SwiftUI

/// Daily review dashboard.
///
/// One primary action — Start Review across all active packs. Per-pack rows
/// show progress and an Active toggle on the right (iOS standard placement).
/// New cards are gated by a single GLOBAL daily cap shared across active packs.
struct SRSDashboardView: View {

    @AppStorage("bibleVersion")       private var bibleVersion:   BibleVersion = .niv84
    @AppStorage("srs.dailyNewCap")    private var dailyNewCap:    Int          = 5
    @AppStorage("srs.dailyReviewCap") private var dailyReviewCap: Int          = 50

    @ObservedObject private var store = SRSStore.shared

    @State private var session: TestSession?

    // MARK: - Design Tokens (iOS-standard continuous corners + 8/12/16 spacing)

    private enum Layout {
        // Match the system `.insetGrouped` list (used by SettingsView) which
        // renders sections with 10pt continuous corners. The hero card and
        // packs container are visual siblings to those sections.
        static let containerRadius: CGFloat = 10
        static let buttonRadius:    CGFloat = 12
        static let chipRadius:      CGFloat = 8
        static let cardPadding:     CGFloat = 20
        static let rowPaddingH:     CGFloat = 16
        static let rowPaddingV:     CGFloat = 12
        static let sectionSpacing:  CGFloat = 16
        static let edgeMargin:      CGFloat = 16
    }

    private var packs:        [Pack] { bibleVersion.packs }
    private var activePacks:  [Pack] { packs.filter { store.isActive($0.name) } }
    private var now:          Date   { Date() }

    private var globalNewRemaining: Int {
        SRSQueueBuilder.globalNewRemaining(store: store, dailyNewCap: dailyNewCap, now: now)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                heroCard
                packsSection
            }
            .padding(.horizontal, Layout.edgeMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Daily")
        .fullScreenCover(item: $session) { s in
            TestSessionView(session: s, onSessionEnded: { session = nil })
        }
    }

    // MARK: - Hero Card

    @ViewBuilder
    private var heroCard: some View {
        let agg = aggregate()
        VStack(spacing: 16) {
            if activePacks.isEmpty {
                heroNoActivePacks
            } else if agg.queueSize > 0 {
                heroQueue(agg: agg)
            } else {
                heroCaughtUp
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.cardPadding)
        .padding(.horizontal, Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.containerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var heroNoActivePacks: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No active packs")
                .font(.system(size: 17, weight: .semibold))
            Text("Turn on a pack below to start your daily review.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func heroQueue(agg: Aggregate) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(agg.queueSize)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(agg.queueSize == 1 ? "card due today" : "cards due today")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Button {
                startSession(forPacks: activePacks)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Review")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Layout.buttonRadius, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                breakdownChip(label: "Learning", value: agg.learning,     color: .orange)
                breakdownChip(label: "Review",   value: agg.review,       color: .blue)
                breakdownChip(label: "New",      value: agg.newProjected, color: .green)
            }
        }
    }

    private var heroCaughtUp: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.system(size: 17, weight: .semibold))
            if let next = nextDueAcrossActivePacks() {
                Text("Next card returns in \(formatRelative(next))")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Text("Turn on more packs to add new verses to your queue.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func breakdownChip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value) \(label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Packs Section

    private var packsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Packs")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(packs.enumerated()), id: \.element.id) { idx, pack in
                    packRow(pack)
                    if idx < packs.count - 1 {
                        Divider().padding(.leading, Layout.rowPaddingH)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Layout.containerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func packRow(_ pack: Pack) -> some View {
        let counts = SRSQueueBuilder.counts(
            packName: pack.name,
            allVerses: pack.verses,
            store: store,
            now: now
        )
        let active = store.isActive(pack.name)
        let projectedNew = min(globalNewRemaining, counts.newCandidates)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(packSubtitle(counts: counts, active: active, projectedNew: projectedNew))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { active },
                set: { store.setActive(pack.name, $0) }
            ))
            .labelsHidden()
            .tint(.accentColor)
        }
        .padding(.horizontal, Layout.rowPaddingH)
        .padding(.vertical, Layout.rowPaddingV)
        .contentShape(Rectangle())
    }

    private func packSubtitle(counts: SRSQueueBuilder.DailyCounts, active: Bool, projectedNew: Int) -> String {
        if !active {
            if counts.totalScheduled > 0 {
                return "Paused · \(counts.totalScheduled) scheduled"
            }
            return counts.newCandidates > 0
                ? "Off · \(counts.newCandidates) verses to learn"
                : "Off"
        }
        let queueSize = counts.learning + counts.review + projectedNew
        if queueSize == 0 {
            return counts.totalScheduled == 0 ? "Ready to start" : "Caught up"
        }
        // Show only non-zero categories so typical days read cleanly:
        // "4 new"  rather than  "0 learning · 0 review · 4 new".
        var parts: [String] = []
        if counts.learning > 0 { parts.append("\(counts.learning) learning") }
        if counts.review   > 0 { parts.append("\(counts.review) review") }
        if projectedNew    > 0 { parts.append("\(projectedNew) new") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Session Launch

    private func startSession(forPacks targetPacks: [Pack]) {
        let verses = SRSQueueBuilder.buildAllPacksSession(
            packs: targetPacks,
            store: store,
            dailyNewCap: dailyNewCap,
            dailyReviewCap: dailyReviewCap,
            now: now
        )
        guard !verses.isEmpty else { return }
        TestSessionViewModel.clearPersistedProgress()
        session = TestSession(verses: verses, kind: .srs)
    }

    // MARK: - Aggregates

    private struct Aggregate {
        var learning:     Int = 0
        var review:       Int = 0
        var newProjected: Int = 0
        var queueSize: Int { learning + review + newProjected }
    }

    private func aggregate() -> Aggregate {
        var agg = Aggregate()
        var totalCandidates = 0
        for pack in activePacks {
            let c = SRSQueueBuilder.counts(
                packName: pack.name,
                allVerses: pack.verses,
                store: store,
                now: now
            )
            agg.learning    += c.learning
            agg.review      += c.review
            totalCandidates += c.newCandidates
        }
        agg.newProjected = min(globalNewRemaining, totalCandidates)
        return agg
    }

    private func nextDueAcrossActivePacks() -> Date? {
        activePacks.flatMap { $0.verses }
            .compactMap { store.state(for: $0)?.due }
            .filter { $0 > now }
            .min()
    }

    private func formatRelative(_ date: Date) -> String {
        let dt = date.timeIntervalSince(Date())
        if dt <= 0 { return "now" }
        if dt < 60 { return "<1m" }
        if dt < 3_600 { return "\(Int(dt / 60))m" }
        if dt < 86_400 { return "\(Int(dt / 3_600))h" }
        let days = Int(dt / 86_400)
        return days == 1 ? "1 day" : "\(days) days"
    }
}
