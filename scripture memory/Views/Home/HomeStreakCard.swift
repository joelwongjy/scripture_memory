import SwiftUI

/// Home's top row: the streak count and this week's days. Tapping it opens the
/// streak screen.
struct HomeStreakCard: View {
    @ObservedObject private var streak = StreakStore.shared

    var body: some View {
        let count = streak.current
        let lit = streak.isTodayDone
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundStyle(lit ? Color.orange : Color(.systemGray3))
                .symbolEffect(.bounce, options: .nonRepeating, value: count)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count) day streak")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                if !lit && count > 0 {
                    Text("Open the app today to keep it")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                ForEach(Array(streak.thisWeek().enumerated()), id: \.offset) { _, day in
                    ZStack {
                        Circle()
                            .fill(day.done ? Color.orange : Color(.systemGray5))
                            .frame(width: 17, height: 17)
                        if day.done {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        } else if day.isToday {
                            Circle().strokeBorder(Color.orange, lineWidth: 1.5).frame(width: 17, height: 17)
                        }
                    }
                    .opacity(day.isFuture ? 0.35 : 1)
                }
            }
        }
        .padding(.horizontal, AppLayout.panelPadding)
        .padding(.vertical, AppLayout.panelRowPadding)
        .frame(maxWidth: .infinity)
        .groupedPanel()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lit || count == 0 ? "\(count) day streak" : "\(count) day streak, open the app today to keep it")
        .accessibilityHint("Shows your streak")
    }
}
