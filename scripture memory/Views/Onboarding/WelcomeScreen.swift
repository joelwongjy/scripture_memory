import SwiftUI

// MARK: - Welcome (Apple-style hero + feature callouts)

struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 56)
                    .padding(.bottom, 22)

                Text("Welcome to\nScripture Memory")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)

                VStack(alignment: .leading, spacing: 30) {
                    FeatureRow(icon: "text.book.closed.fill",
                               title: "Memorize Scripture",
                               subtitle: "Learn verses one at a time, in order, at your own pace.",
                               tint: .blue)
                    FeatureRow(icon: "flame.fill",
                               title: "Build a daily streak",
                               subtitle: "A verse a day keeps your momentum going.",
                               tint: .orange)
                    FeatureRow(icon: "arrow.triangle.2.circlepath",
                               title: "Reviews that stick",
                               subtitle: "Spaced repetition brings verses back right before you'd forget.",
                               tint: .green)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            // Floating, not barred — a hero screen has nothing scrolling under it.
            PrimaryActionButton(title: "Continue", action: onContinue)
                .padding(.horizontal, AppLayout.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(tint)
                .frame(width: 42, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
