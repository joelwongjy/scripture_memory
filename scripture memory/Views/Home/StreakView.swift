import SwiftUI

/// The streak in full, Duolingo-style: the flame and count, whether today is
/// done, the next milestone, best and total, and a month calendar where
/// consecutive days join into one band.
struct StreakView: View {
    @ObservedObject private var streak = StreakStore.shared
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    var body: some View {
        ScrollView {
            VStack(spacing: AppLayout.spacing) {
                hero
                milestone
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
        return VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 72))
                .foregroundStyle(lit ? AnyShapeStyle(Self.flameGradient) : AnyShapeStyle(Color(.systemGray3)))
                .symbolEffect(.bounce, options: .nonRepeating, value: count)
                .padding(.top, 8)
            Text("\(count)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(lit ? Color.orange : Color.primary)
                .contentTransition(.numericText())
            Text("day streak")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(statusLine)
                .font(.subheadline)
                .foregroundStyle(lit ? Color.secondary : Color.orange)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            weekRow.padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(AppLayout.cardPadding)
        .groupedPanel()
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        let count = streak.current
        if streak.isTodayDone { return "Streak kept for today. See you tomorrow!" }
        if count > 0 { return "Open the app today to keep your streak going." }
        return "Open the app each day to build a streak."
    }

    private var weekRow: some View { StreakWeekRow() }

    // MARK: - Milestone

    private var milestone: some View {
        let count = streak.current
        let goal = streak.nextMilestone
        let left = goal - count
        return VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Next goal: \(goal)-day streak")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "trophy.fill").foregroundStyle(.orange)
            }
            ProgressView(value: Double(count), total: Double(goal))
                .tint(.orange)
            Text(left == 1 ? "1 more day" : "\(left) more days")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppLayout.panelPadding)
        .groupedPanel()
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: AppLayout.spacing) {
            statTile(value: streak.longest, label: "Best streak", systemImage: "flame.fill", tint: .orange)
            statTile(value: streak.totalDays, label: "Days active", systemImage: "calendar", tint: .blue)
        }
    }

    private func statTile(value: Int, label: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
    private let cell: CGFloat = 36

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

    /// The month's days laid out in six weeks, `nil` for the padding before
    /// day 1 and after the last day, so every month is the same height.
    private var weeks: [[Date?]] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for d in range { days.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        while days.count < 42 { days.append(nil) }
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
