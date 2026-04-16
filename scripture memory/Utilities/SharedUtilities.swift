import SwiftUI

// MARK: - String

extension String {
    /// Opening/closing marks we strip from each token’s ends so study input matches spoken/typed text
    /// (e.g. `"Until` → `Until`, `` `Man `` → `Man`, `said,"` → `said,`). Middle apostrophes stay (`don't`).
    fileprivate static let quotationDelimiterCharacters: Set<Character> = [
        "\"", "'", "`",
        "\u{2018}", "\u{2019}", "\u{201C}", "\u{201D}",
        "\u{00AB}", "\u{00BB}", "\u{2039}", "\u{203A}",
    ]

    /// Strips `quotationDelimiterCharacters` from both ends, repeatedly.
    func trimmingQuotationDelimitersOnEnds() -> String {
        var t = self
        while let c = t.first, Self.quotationDelimiterCharacters.contains(c) { t.removeFirst() }
        while let c = t.last, Self.quotationDelimiterCharacters.contains(c) { t.removeLast() }
        return String(t)
    }

    /// Splits into non-empty words on spaces and on `--` (em-dash style in stored text).
    /// Single `-` is kept (e.g. `God-breathed`, `us-whatever`) so only `--` adds a word boundary.
    var wordTokens: [String] {
        components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { piece -> [String] in
                piece
                    .components(separatedBy: "--")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            .map { $0.trimmingQuotationDelimitersOnEnds() }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Color

extension Color {
    /// Initialises a Color from a 6-digit hex string, with or without a leading `#`.
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }

    /// A desaturated, darker variant suitable for muted pack-cover backgrounds.
    var muted: Color {
        let uic = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.55), brightness: Double(b * 0.7))
    }
}

// MARK: - Flashcard Style

extension View {
    /// Applies the standard card appearance: parchment background, rounded corners, shadows.
    func flashcardStyle() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(flashcardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Adaptive parchment-style background shared by all card types.
let flashcardBackground = Color(uiColor: UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(white: 0.13, alpha: 1)
        : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
})

// MARK: - Study chrome (top bar + scrubber)

extension Image {
    /// Neutral glass circle — close, list, reset, etc.
    func studyChromeCircleButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    /// Prev/next chevrons beside the verse scrubber track.
    func studyScrubberChevronButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.7))
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    /// Toggle controls (shuffle, layout) — blue when active.
    func studyChromeToggle(isOn: Bool) -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(width: 36, height: 36)
            .background(
                isOn ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.ultraThinMaterial),
                in: Circle()
            )
            .shadow(
                color: isOn ? Color.blue.opacity(0.35) : Color.black.opacity(0.08),
                radius: isOn ? 8 : 6, x: 0, y: 2
            )
    }
}

// MARK: - Card Button Style

/// Press-to-scale feedback for tappable pack cards.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Peek Components

/// Compact hold-to-peek eye icon — inline with input controls.
/// Uses `DragGesture(minimumDistance: 0)` so press-down triggers reveal and release hides it.
struct PeekEyeButton: View {
    @Binding var isPeeking: Bool

    var body: some View {
        Image(systemName: isPeeking ? "eye.fill" : "eye")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(isPeeking ? .blue : .secondary)
            .frame(width: 48, height: 48)
            .background(isPeeking ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPeeking {
                            withAnimation(.easeInOut(duration: 0.1)) { isPeeking = true }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) { isPeeking = false }
                    }
            )
    }
}

/// Card-style overlay matching the real card but with all text in secondary color.
/// Shown while the user holds a `PeekEyeButton`.
struct PeekOverlayCard: View {
    let verse:     Verse
    let cardLabel: String
    let width:     CGFloat
    let height:    CGFloat
    let isPeeking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.secondary)

            Spacer().frame(height: 10)

            Text(verse.title)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(.secondary)
                .padding(.bottom, 6)

            Text(verse.verse)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(5)
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 6)

            Text(cardLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .flashcardStyle()
        .frame(width: width, height: height)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.1), value: isPeeking)
    }
}

// MARK: - Shake Animation

/// Fires a three-step horizontal shake by animating a `CGFloat` binding.
/// Used to signal wrong input. Runs on the main actor; timings match across the app.
@MainActor
func triggerShake(_ offset: Binding<CGFloat>) {
    withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) { offset.wrappedValue = 12 }
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { offset.wrappedValue = -8 }
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.spring()) { offset.wrappedValue = 0 }
    }
}
