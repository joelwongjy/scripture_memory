import SwiftUI

/// Home's top row: the streak count and this week's days.
struct HomeStreakCard: View {
    @ObservedObject private var streak = StreakStore.shared

    var body: some View {
        let count = streak.current
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundStyle(count > 0 ? Color.orange : Color(.systemGray3))
                .symbolEffect(.bounce, options: .nonRepeating, value: count)
            Text("\(count) day streak")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) day streak")
    }
}
