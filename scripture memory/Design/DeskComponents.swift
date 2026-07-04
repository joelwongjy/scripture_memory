import SwiftUI

// MARK: - Today's stack

/// Today's due cards as a physical banded stack sitting on the desk.
/// Thickness shows the workload — you can see how much is left the way you'd
/// see it on a real desk — and the whole stack is the start button.
struct TodayStack: View {
    let count: Int

    @Environment(\.colorScheme) private var scheme

    private var layers: Int { min(max(count, 1), 7) }
    private static let step: CGFloat = 3.5

    var body: some View {
        ZStack {
            // Under-cards: squared-up but human, each a hair off true.
            ForEach(1..<layers, id: \.self) { i in
                RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                    .fill(underTone)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                    )
                    .offset(y: CGFloat(i) * Self.step)
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? 0.7 : -0.7))
            }

            // Top card carries the count and the call to action.
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(count == 1 ? "card due today" : "cards due today")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Start Review")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(ParchmentSurface(cornerRadius: AppLayout.cardRadius))
        }
        // Reserve layout room for the under-card edges peeking out below.
        .padding(.bottom, CGFloat(layers - 1) * Self.step)
        .overlay { RubberBand() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 card due today" : "\(count) cards due today")
        .accessibilityHint("Starts the review")
    }

    private var underTone: Color {
        scheme == .dark ? Color(white: 0.135) : Color(red: 0.955, green: 0.936, blue: 0.899)
    }
}

// MARK: - Rubber band

/// The band around today's stack — off-centre so it never covers the count,
/// slightly askew, with a catch-light along one edge.
struct RubberBand: View {
    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(colors: [bandTone, bandTone.opacity(0.82)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 2.5)
                        .padding(.leading, 3)
                }
                .frame(width: 14, height: geo.size.height + 10)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: 1.5, y: 0)
                .rotationEffect(.degrees(1.6))
                .position(x: geo.size.width * 0.22, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    private var bandTone: Color { Color(red: 0.70, green: 0.30, blue: 0.27) }
}
