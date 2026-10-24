import SwiftUI

/// Shown when today's first practice extends the streak, Duolingo-style: once
/// you leave the study or review screen, the flame and the new count fill the
/// screen with this week's progress, until you tap Continue.
struct StreakCelebration: View {
    let count: Int
    let onContinue: () -> Void

    @State private var shown = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 96))
                .foregroundStyle(StreakView.flameGradient)
                .symbolEffect(.bounce, options: .nonRepeating, value: shown)
                .scaleEffect(appeared || AppMotion.reduceMotion ? 1 : 0.6)
            Text("\(shown)")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText(value: Double(shown)))
            Text("day streak!")
                .font(.title2.weight(.bold))
            Text(count == 1 ? "You've started a streak. Come back tomorrow to grow it."
                            : "Come back tomorrow to keep it going.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            StreakWeekRow()
                .padding(.top, 20)
            Spacer()
            Button(action: onContinue) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.bottom, 24)
            .readableColumn(520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task {
            shown = max(0, count - 1)
            withAnimation(AppMotion.movement) { appeared = true }
            HapticEngine.success()
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(AppMotion.content) { shown = count }
        }
    }
}

/// This week as seven days: practised days are filled with a check, today is
/// ringed. Used on the streak screen and the celebration.
struct StreakWeekRow: View {
    @ObservedObject private var streak = StreakStore.shared

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(streak.thisWeek().enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    Text(day.initial)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(day.isToday ? Color.orange : Color.secondary)
                    ZStack {
                        Circle()
                            .fill(day.done ? Color.orange : Color(.systemGray5))
                            .frame(width: 30, height: 30)
                        if day.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        } else if day.isToday {
                            Circle().strokeBorder(Color.orange, lineWidth: 2).frame(width: 30, height: 30)
                        }
                    }
                    .opacity(day.isFuture ? 0.4 : 1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: \(streak.thisWeek().filter(\.done).count) of 7 days practised")
    }
}

/// Counts open study and review screens, so the celebration waits until you're
/// back on a tab instead of covering the card you're answering.
@MainActor
final class StudyScreenTracker: ObservableObject {
    static let shared = StudyScreenTracker()
    @Published private(set) var openCount = 0
    func opened() { openCount += 1 }
    func closed() { openCount = max(0, openCount - 1) }
}

extension View {
    /// Marks this view as a study or review screen (see `StudyScreenTracker`).
    func tracksStudyScreen() -> some View {
        onAppear { StudyScreenTracker.shared.opened() }
            .onDisappear { StudyScreenTracker.shared.closed() }
    }

    /// Shows the streak celebration over this screen once today's streak is
    /// earned and no study screen is open. Attach to the app's root view.
    func streakCelebration() -> some View {
        modifier(StreakCelebrationModifier())
    }
}

private struct StreakCelebrationModifier: ViewModifier {
    @ObservedObject private var streak  = StreakStore.shared
    @ObservedObject private var tracker = StudyScreenTracker.shared

    func body(content: Content) -> some View {
        content.overlay {
            if let count = streak.celebration, tracker.openCount == 0 {
                StreakCelebration(count: count) {
                    withAnimation(AppMotion.content) { streak.celebration = nil }
                }
                .transition(.opacity)
            }
        }
    }
}
