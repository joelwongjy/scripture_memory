import SwiftUI

/// The streak in full: the flame and count with this week, best and total,
/// and a month calendar where
/// consecutive days join into one band.
struct StreakView: View {
    @ObservedObject private var streak = StreakStore.shared
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    var body: some View {
        ScrollView {
            VStack(spacing: AppLayout.spacing) {
                hero
                stats
                calendar
            }
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .readableColumn()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Streak")
        .analyticsScreen(.streak)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        let count = streak.current
        let lit = streak.isTodayDone
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(lit ? AnyShapeStyle(Self.flameGradient) : AnyShapeStyle(Color(.systemGray3)))
                    .symbolEffect(.bounce, options: .nonRepeating, value: count)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(lit ? Color.orange : Color.primary)
                        .contentTransition(.numericText())
                    Text("day streak")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            StreakWeekRow()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppLayout.panelPadding)
        .padding(.horizontal, AppLayout.cardPadding)
        .groupedPanel()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: AppLayout.spacing) {
            statTile(value: streak.longest, label: "Best streak", systemImage: "flame.fill", tint: .orange)
            statTile(value: streak.totalDays, label: "Days active", systemImage: "calendar", tint: .blue)
        }
    }

    private func statTile(value: Int, label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppLayout.panelPadding)
        .groupedPanel()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Calendar

    private var calendar: some View {
        VStack(spacing: 12) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Previous month")
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .frame(width: 44, height: 44)
                    .disabled(isCurrentMonth)
                    .accessibilityLabel("Next month")
            }
            MonthGrid(month: month, isDone: streak.isDone)
        }
        .padding(AppLayout.panelPadding)
        .groupedPanel()
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ by: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: by, to: month) else { return }
        withAnimation(AppMotion.content) { month = next }
    }

    static let flameGradient = LinearGradient(colors: [.yellow, .orange, .red],
                                              startPoint: .top, endPoint: .bottom)
}

/// One month, a week per row. Practised days are orange; back-to-back practised
/// days in the same row are joined by a band, the way Duolingo draws a streak.
private struct MonthGrid: View {
    let month: Date
    let isDone: (Date) -> Bool

    private let cal = Calendar.current
    private let cell: CGFloat = 34

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                        dayCell(day, column: column)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?, column: Int) -> some View {
        if let day {
            let done = isDone(day)
            let joinsLeft  = done && column > 0 && isDone(shift(day, -1))
            let joinsRight = done && column < 6 && isDone(shift(day, 1))
            let isToday = cal.isDateInToday(day)
            ZStack {
                // The band: half-width bars toward each practised neighbour.
                HStack(spacing: 0) {
                    Rectangle().fill(joinsLeft ? Color.orange.opacity(0.35) : .clear)
                    Rectangle().fill(joinsRight ? Color.orange.opacity(0.35) : .clear)
                }
                .frame(height: cell * 0.8)
                Circle()
                    .fill(done ? Color.orange : .clear)
                    .frame(width: cell, height: cell)
                if isToday && !done {
                    Circle().strokeBorder(Color.orange, lineWidth: 2).frame(width: cell, height: cell)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(.subheadline.weight(done ? .bold : .regular))
                    .foregroundStyle(done ? Color.white : (day > Date() ? Color.secondary.opacity(0.5) : Color.primary))
            }
            .frame(height: cell)
        } else {
            Color.clear.frame(height: cell)
        }
    }

    private func shift(_ d: Date, _ by: Int) -> Date { cal.date(byAdding: .day, value: by, to: d) ?? d }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The month's days laid out by week, `nil` for the padding before day 1
    /// and after the last day.
    private var weeks: [[Date?]] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for d in range { days.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    private var accessibilitySummary: String {
        let all = weeks.flatMap { $0 }.compactMap { $0 }
        let practised = all.filter(isDone).count
        return "\(practised) of \(all.count) days active this month"
    }
}

#Preview {
    NavigationStack { StreakView() }
}

/// This week as seven days: practised days are filled with a check, today is
/// ringed.
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
        .accessibilityLabel("This week: \(streak.thisWeek().filter(\.done).count) of 7 days active")
    }
}
