import SwiftUI

/// Home's daily review panel: how many cards are due, with Start, or the
/// caught-up state with when to come back.
///
/// Owns its own store observation and settings so its counts re-render when a
/// session or a Settings change moves them, even if Home's inputs didn't change.
struct DailyReviewCard: View {
    let activePacks: [Pack]
    let onStart: (TestSession) -> Void

    @ObservedObject private var store = SRSStore.shared

    @AppStorage(NewCardCap.amountKey) private var newCapAmount: Int        = NewCardCap.fallback.amount
    @AppStorage(NewCardCap.unitKey)   private var newCapUnit:   NewCapUnit = NewCardCap.fallback.unit
    @AppStorage(NewCardCap.dailyReviewCapKey) private var dailyReviewCap: Int = NewCardCap.dailyReviewCapDefault
    /// Not read directly; observed so the counts update when the setting flips.
    @AppStorage(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey)
    private var reviewsKnownVerses = SRSQueueBuilder.NewCardPolicy.reviewsKnownDefault

    private var newCap: NewCardCap { NewCardCap(amount: newCapAmount, unit: newCapUnit) }

    var body: some View {
        let counts = dueCounts()
        VStack(spacing: 16) {
            if activePacks.isEmpty {
                noActivePacks
            } else if counts.total > 0 {
                due(counts)
            } else {
                caughtUp(counts)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppLayout.panelRowPadding)
        .padding(.horizontal, AppLayout.panelPadding)
        .groupedPanel()
    }

    // MARK: - States

    private var noActivePacks: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No active packs")
                    .font(.system(size: 16, weight: .semibold))
                Text("Turn on a pack to start your daily review.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Anki's three counts, in Anki's colours and words, over one Start button.
    private func due(_ counts: DueCounts) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                count("New",   counts.newToday, color: ReviewColor.new)
                count("Learn", counts.learning, color: ReviewColor.learn)
                count("Due",   counts.review,   color: ReviewColor.due)
            }
            Button(action: start) {
                Text("Start review")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .accessibilityLabel("Start review, \(counts.total) \(counts.total == 1 ? "card" : "cards")")
        }
        .padding(.vertical, 4)
    }

    private func count(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(value > 0 ? color : Color(.tertiaryLabel))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func caughtUp(_ counts: DueCounts) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.reviewedToday() > 0 ? "Done for today" : "All caught up")
                    .font(.system(size: 17, weight: .semibold))
                Text(caughtUpMessage(counts))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    /// Whichever comes back soonest: a card due later today, the next batch of
    /// new verses, or the next scheduled review, or today's limit.
    private func caughtUpMessage(_ counts: DueCounts) -> String {
        let now      = Date()
        let next     = nextDue(after: now)
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(SRSStore.secondsPerDay)

        if counts.overLimit > 0 {
            return "You've reached today's limit of \(dailyReviewCap) reviews. "
                + "\(counts.overLimit) more \(counts.overLimit == 1 ? "is" : "are") waiting for tomorrow."
        }

        if let next, next < tomorrow {
            return "Your next review is in \(formatRelative(next))."
        }
        // A weekly cap doesn't reset at midnight, so don't say it does.
        if counts.newCandidates > 0 && newCap.amount > 0 {
            let n    = min(newCap.amount, counts.newCandidates)
            let when = newCap.unit == .day ? "tomorrow" : "next week"
            return n == 1
                ? "Come back \(when) for a new verse."
                : "Come back \(when) for \(n) new verses."
        }
        if let next {
            return "Your next review is in \(formatRelative(next))."
        }
        // New verses remain, but the new-verse limit is zero.
        if counts.newCandidates > 0 {
            return "Raise your daily new verses in Settings to keep going."
        }
        return "You've reviewed every verse in your active packs."
    }

    // MARK: - Counts

    private struct DueCounts {
        var learning      = 0
        var review        = 0
        var newToday      = 0
        /// All unscheduled cards, not just today's share.
        var newCandidates = 0
        /// Reviews waiting that today's limit holds back.
        var overLimit     = 0
        var total: Int { learning + review + newToday }
    }

    /// Counts the very cards Start would serve, so the number and the session agree.
    private func dueCounts() -> DueCounts {
        let now = Date()
        let policy = SRSQueueBuilder.NewCardPolicy.current
        var counts = DueCounts()
        let served = SRSQueueBuilder.reviewCards(packs: activePacks, store: store,
                                                 dailyReviewCap: dailyReviewCap,
                                                 policy: policy, now: now)
        counts.learning = served.filter { store.state(for: $0)?.phase == .learning }.count
        counts.review   = served.count - counts.learning
        counts.newCandidates = activePacks.reduce(0) { $0 + policy.fresh(in: $1.verses, store: store).count }
        counts.newToday = min(SRSQueueBuilder.globalNewRemaining(store: store, newCap: newCap, now: now),
                              counts.newCandidates)
        let unlimited = SRSQueueBuilder.reviewCards(packs: activePacks, store: store,
                                                    dailyReviewCap: .max, policy: policy, now: now)
        counts.overLimit = unlimited.count - served.count
        return counts
    }

    private func nextDue(after now: Date) -> Date? {
        activePacks.flatMap(\.verses)
            .compactMap { store.state(for: $0)?.due }
            .filter { $0 > now }
            .min()
    }

    private func formatRelative(_ date: Date) -> String {
        let dt = date.timeIntervalSince(Date())
        if dt <= 0 { return "now" }
        if dt < 60 { return "<1m" }
        if dt < 3_600 { return "\(Int(dt / 60))m" }
        if dt < SRSStore.secondsPerDay { return "\(Int(dt / 3_600))h" }
        let days = Int(dt / SRSStore.secondsPerDay)
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func start() {
        guard let session = TestSession.dailyReview(activePacks: activePacks, newCap: newCap,
                                                    dailyReviewCap: dailyReviewCap) else { return }
        TestSessionViewModel.clearPersistedProgress(for: .srs)
        onStart(session)
    }
}
