import SwiftUI

// `String.wordTokens` / `trimmingQuotationDelimitersOnEnds()` now live in
// Model/TextTokens.swift (Foundation-only) so they can be unit-tested.

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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    /// Neutral circular icon button — close, list, reset, etc. Accent icon on a
    /// solid neutral fill. 36pt visual circle inside a 44pt hit target (HIG min).
    func studyChromeCircleButton() -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 36, height: 36)
            .background(Color(.secondarySystemBackground), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    /// Prev/next chevrons beside the verse scrubber track.
    func studyScrubberChevronButton() -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 36, height: 36)
            .background(Color(.secondarySystemBackground), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    /// Toggle controls (shuffle, layout). Background flips: neutral when off,
    /// accent when on. Icon goes white on the accent background so there's no
    /// accent-on-accent visibility issue. 36pt visual / 44pt hit target.
    func studyChromeToggle(isOn: Bool) -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.accentColor))
            .frame(width: 36, height: 36)
            .background(
                isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemBackground)),
                in: Circle()
            )
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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

/// App-wide layout constants. One canonical horizontal screen margin so every
/// screen — pack grid, daily dashboard, settings list, and the immersive study
/// / review screens (card, chrome, and controls) — lines up to the same edge.
/// 16pt matches the iOS `.insetGrouped` list inset that Settings and Daily use.
enum AppLayout {
    static let screenMargin: CGFloat = 16
    /// Corner radius for content cards (flashcards, pack covers).
    static let cardRadius:    CGFloat = 10
    /// Corner radius for grouped-list containers (Daily hero / packs panels) —
    /// matched to the iOS 26 system `.insetGrouped` section corners so the Daily
    /// dashboard's white panels line up with Settings / Review.
    static let groupedRadius: CGFloat = 20
    /// Corner radius for buttons and control chips.
    static let controlRadius: CGFloat = 12
}

extension View {
    /// Clips to a continuous ("squircle") rounded rectangle — the iOS-standard
    /// corner style. Used app-wide so every card and control shares one corner
    /// shape instead of mixing `.continuous` with the default circular style
    /// (which made the Daily panels look subtly different from other screens).
    func roundedRect(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The shared 48×48 control-button metrics used across the study/review bottom
/// bar (mic, keyboard-dismiss, peek). Centralized so every control in that row
/// is the same size and corner radius.
enum StudyControlMetrics {
    static let buttonSize:   CGFloat = 48
    static let cornerRadius: CGFloat = 12
    static let rowSpacing:   CGFloat = 10
}

/// Single, always-present hold-to-peek control for the study/review controls.
///
/// One consistent control across every test/review screen and every state
/// within them (before submit, after submit, while grading, on a finished
/// card, in all study modes). Press and hold to reveal the full verse via the
/// card overlay; release to hide.
///
/// Anchored to the leading edge of the bottom control band so it sits in the
/// same place regardless of which state-specific controls are showing, and is
/// visually subordinate to the centered primary action. Compact (matches the
/// mic / keyboard-dismiss buttons). Wrapped in a `Button` (with a no-op action)
/// so pressing it never resigns the focused text field — otherwise the keyboard
/// would dismiss mid-review. The `DragGesture(minimumDistance: 0)` rides
/// alongside for press-and-hold: press down reveals, release hides.
struct PeekHoldButton: View {
    @Binding var isPeeking: Bool

    /// One-time discoverability hint (icon-only press-and-hold isn't obvious).
    @AppStorage("peekHintSeen") private var hintSeen = false
    @State private var showHint = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: isPeeking ? "eye.fill" : "eye")
                .font(.system(size: 18, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isPeeking ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: StudyControlMetrics.cornerRadius, style: .continuous)
                        .fill(isPeeking ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Peek at answer")
        .accessibilityHint("Press and hold to reveal the verse")
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .top) {
            if showHint {
                Text("Hold to peek")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(Color.accentColor))
                    .fixedSize()
                    .offset(y: -34)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPeeking {
                        withAnimation(.easeInOut(duration: 0.1)) { isPeeking = true }
                        HapticEngine.light()
                        dismissHint()
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPeeking = false }
                }
        )
        .task {
            guard !hintSeen else { return }
            try? await Task.sleep(for: .milliseconds(700))   // let the screen settle
            guard !hintSeen else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showHint = true }
            try? await Task.sleep(for: .seconds(4))
            dismissHint()
        }
    }

    private func dismissHint() {
        if showHint { withAnimation(.easeOut(duration: 0.25)) { showHint = false } }
        hintSeen = true
    }
}

/// Card-style overlay matching the real card but with all text in secondary color.
/// Shown while the user holds a `PeekHoldButton`.
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

// MARK: - Verse Text Fitting

/// Measure-to-fit sizing for verse body text. Replaces the old word-count
/// heuristic: finds the largest font size whose *rendered* height fits the
/// space the card layout actually leaves, so short verses grow to fill the card
/// and long verses shrink just enough to never truncate.
enum VerseFit {
    /// Rendered height of `text` at `size` (serif) with `lineSpacing`, wrapped to `width`.
    static func height(_ text: String, width: CGFloat, size: CGFloat,
                       weight: UIFont.Weight = .regular, lineSpacing: CGFloat) -> CGFloat {
        guard width > 1 else { return .greatestFiniteMagnitude }
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = font.fontDescriptor.withDesign(.serif) { font = UIFont(descriptor: d, size: size) }
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: para], context: nil)
        return ceil(rect.height)
    }

    /// Largest font size in [minSize, maxSize] whose text fits within `width × height`.
    /// Snaps to a 0.5pt grid. Returns `minSize` if even that overflows (so the
    /// floor governs readability; it won't go smaller).
    static func fontSize(_ text: String, width: CGFloat, height: CGFloat,
                         weight: UIFont.Weight = .regular, lineSpacing: CGFloat,
                         minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard width > 1, height > 1, !text.isEmpty else { return maxSize }
        if Self.height(text, width: width, size: maxSize, weight: weight, lineSpacing: lineSpacing) <= height { return maxSize }
        var lo = minSize, hi = maxSize
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if Self.height(text, width: width, size: mid, weight: weight, lineSpacing: lineSpacing) <= height {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo * 2).rounded(.down) / 2
    }
}

/// Renders verse body text at the largest size that fills its allotted space
/// without truncating. Measures its own allocated geometry, so it adapts to
/// whatever height the surrounding card layout leaves for it.
struct FittedVerseText: View {
    let text:        String
    let lineSpacing: CGFloat
    let minSize:     CGFloat
    let maxSize:     CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = VerseFit.fontSize(text, width: geo.size.width, height: geo.size.height,
                                         lineSpacing: lineSpacing, minSize: minSize, maxSize: maxSize)
            Text(text)
                .font(.system(size: size, design: .serif))
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
