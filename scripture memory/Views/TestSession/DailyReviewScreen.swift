import SwiftUI

/// Today's review from start to finish: the cards, another look at any you
/// missed, then a short summary before you're back on Home.
///
/// A missed card goes back into learning a few minutes out. Like Anki, it comes
/// round again before the review ends rather than turning up on Home later.
struct DailyReviewScreen: View {
    let onFinished: () -> Void

    @State private var session: TestSession
    @State private var firstRound: [SRSGrade] = []
    @State private var finished = false

    init(session: TestSession, onFinished: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            if finished {
                ReviewCompleteView(grades: firstRound, onContinue: onFinished)
                    .transition(.opacity)
            } else {
                TestSessionView(session: session, onSessionEnded: onFinished, onRoundEnded: roundEnded)
                    .id(session.id)
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.content, value: finished)
        .animation(AppMotion.content, value: session.id)
    }

    private func roundEnded(_ grades: [SRSGrade], _ missed: [Verse]) {
        if session.round == 1 { firstRound = grades }
        if missed.isEmpty {
            HapticEngine.success()
            finished = true
        } else {
            session = TestSession(verses: missed, kind: .srs, round: session.round + 1)
        }
    }
}

/// The end of a review: what you did, your streak, and what's waiting tomorrow.
struct ReviewCompleteView: View {
    let grades: [SRSGrade]
    let onContinue: () -> Void

    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @AppStorage(NewCardCap.amountKey) private var newCapAmount: Int        = NewCardCap.fallback.amount
    @AppStorage(NewCardCap.unitKey)   private var newCapUnit:   NewCapUnit = NewCardCap.fallback.unit
    @AppStorage(NewCardCap.dailyReviewCapKey) private var dailyReviewCap: Int = NewCardCap.dailyReviewCapDefault
    @ObservedObject private var streak = StreakStore.shared

    @State private var appeared = false

    private var remembered: Int { grades.filter { $0 != .again }.count }
    private var percent: Int { grades.isEmpty ? 0 : Int((Double(remembered) / Double(grades.count) * 100).rounded()) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                .scaleEffect(appeared || AppMotion.reduceMotion ? 1 : 0.6)
                .padding(.bottom, 20)
            Text("Review complete")
                .font(.title.weight(.bold))
            Text(tomorrowLine)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                stat("Cards", value: "\(grades.count)", color: .blue)
                stat("Remembered", value: "\(percent)%", color: .green)
                stat("Streak", value: "\(streak.current)", color: .orange, symbol: "flame.fill")
            }
            .padding(.top, 32)
            .padding(.horizontal, AppLayout.screenMargin)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || AppMotion.reduceMotion ? 0 : 12)

            Spacer()
            Button(action: onContinue) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .tint(.green)
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.bottom, 24)
        }
        .readableColumn(520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            withAnimation(AppMotion.movement.delay(0.05)) { appeared = true }
        }
    }

    private func stat(_ label: String, value: String, color: Color, symbol: String? = nil) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                }
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppLayout.panelRowPadding)
        .groupedPanel()
        .accessibilityElement(children: .combine)
    }

    /// What tomorrow's review will hold, counted the way Home will count it.
    private var tomorrowLine: String {
        let cal = Calendar.current
        guard let endOfTomorrow = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date()))?
                .addingTimeInterval(-1) else { return "" }
        let store = SRSStore.shared
        let active = store.activePacks(PackPreferencesStore.shared.visible(from: bibleVersion.packs))
        let n = SRSQueueBuilder.dueSummary(activePacks: active, store: store,
                                           newCap: NewCardCap(amount: newCapAmount, unit: newCapUnit),
                                           dailyReviewCap: dailyReviewCap, now: endOfTomorrow).total
        switch n {
        case 0:  return "That's everything for now. Nothing is due tomorrow."
        case 1:  return "That's it for today. 1 card is waiting tomorrow."
        default: return "That's it for today. \(n) cards are waiting tomorrow."
        }
    }
}
