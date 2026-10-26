import SwiftUI
import UIKit

// The printed cards that live in the pouch. Sized off the card's width so the
// same face reads right on a phone and on the iPhone Duo's inner display.
//
// Styled after the physical TMS cards: bold grey sans title, a small serif
// "NIV", the reference, the verse in Optima, the reference again on the right,
// and the series code along the bottom.

/// Paper colour and ink, shared by every card face.
enum PouchInk {
    static let paper     = adaptive(light: (0.965, 0.962, 0.950), dark: (0.180, 0.178, 0.170))
    static let paperBack = adaptive(light: (0.925, 0.921, 0.905), dark: (0.145, 0.143, 0.137))
    static let paperEdge = adaptive(light: (0.890, 0.890, 0.890), dark: (0.235, 0.233, 0.225))
    static let title     = adaptive(light: (0.33, 0.33, 0.33), dark: (0.74, 0.74, 0.72))
    static let body      = adaptive(light: (0.14, 0.14, 0.14), dark: (0.90, 0.90, 0.88))
    static let caption   = adaptive(light: (0.30, 0.30, 0.30), dark: (0.62, 0.62, 0.60))
    static let green     = adaptive(light: (0.12, 0.55, 0.37), dark: (0.36, 0.78, 0.56))
    static let mint      = adaptive(light: (0.80, 0.91, 0.86), dark: (0.16, 0.30, 0.24))
    static let edgeLine  = adaptive(light: (0, 0, 0), dark: (1, 1, 1)).opacity(0.10)

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { tc in
            let c = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// The printed card's typefaces: a bold sans title, the reference and verse in
/// Optima.
enum CardFont {
    enum Style {
        case title, reference, body

        fileprivate var name: String {
            switch self {
            case .title:     return "AvenirNext-Bold"
            case .reference: return "Optima-Bold"
            case .body:      return "Optima-Regular"
            }
        }
    }

    static func font(_ style: Style, size: CGFloat) -> Font { .custom(style.name, size: size) }

    static func uiFont(_ style: Style, size: CGFloat) -> UIFont {
        UIFont(name: style.name, size: size) ?? .systemFont(ofSize: size)
    }
}

/// How the paper cards follow the system appearance.
enum CardAppearance: String, CaseIterable {
    case alwaysLight
    case matchSystem

    static let storageKey = "cardAppearance.v1"

    var displayName: String {
        switch self {
        case .matchSystem: return "Match Appearance"
        case .alwaysLight: return "Always Light"
        }
    }
}

extension View {
    func paperAppearance() -> some View { modifier(PaperAppearance()) }
}

private struct PaperAppearance: ViewModifier {
    @AppStorage(CardAppearance.storageKey) private var appearance: CardAppearance = .alwaysLight

    @ViewBuilder
    func body(content: Content) -> some View {
        if appearance == .alwaysLight {
            content.environment(\.colorScheme, .light)
        } else {
            content
        }
    }
}

/// One verse card, front face.
struct PouchVerseCard<Accessory: View>: View {
    let verse: Verse
    let isLearnt: Bool
    let width: CGFloat
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        let u = width / 100                       // one percent of the card's width
        let footer = CardFooter.label(for: verse).components(separatedBy: " · ")

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verse.title)
                    .font(CardFont.font(.title, size: 5.4 * u))
                    .foregroundStyle(PouchInk.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2 * u)
                Text(verse.pinnedVersion ?? "NIV")
                    .font(.custom("TimesNewRomanPSMT", size: 3.4 * u))
                    .foregroundStyle(PouchInk.caption)
            }
            Text(reference)
                .font(CardFont.font(.body, size: 4.6 * u))
                .foregroundStyle(PouchInk.body)
                .padding(.top, 1.2 * u)
            Text(verse.verse)
                .font(CardFont.font(.body, size: 4.6 * u))
                .foregroundStyle(PouchInk.body)
                .lineSpacing(0.9 * u)
                .minimumScaleFactor(0.55)
                .padding(.top, 0.6 * u)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            Text(reference)
                .font(CardFont.font(.body, size: 4.6 * u))
                .foregroundStyle(PouchInk.body)
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(spacing: 1.6 * u) {
                Text(footer.first ?? "")
                if footer.count > 1 { Text(footer[1]) }
                Spacer(minLength: 0)
                if isLearnt {
                    Label("Learnt", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 2.9 * u, weight: .bold))
                        .foregroundStyle(PouchInk.green)
                }
                accessory()
            }
            .font(.system(size: 2.9 * u))
            .foregroundStyle(PouchInk.caption)
            .padding(.top, 1.4 * u)
        }
        .padding(.horizontal, 7 * u)
        .padding(.top, 6.4 * u)
        .padding(.bottom, 4.2 * u)
        .frame(width: width, height: width / PouchMetrics.cardAspect)
        .background(PaperFace())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(verse.title), \(reference). \(verse.verse)")
    }

    private var reference: String { "\(verse.book) \(verse.reference)" }
}

extension PouchVerseCard where Accessory == EmptyView {
    init(verse: Verse, isLearnt: Bool, width: CGFloat) {
        self.init(verse: verse, isLearnt: isLearnt, width: width) { EmptyView() }
    }
}

/// The last card in the pack, behind the final verse: what the pack is, and
/// how far you've come.
struct PouchBackPageCard: View {
    let packName: String
    let verseCount: Int
    let learntCount: Int
    let width: CGFloat

    var body: some View {
        let u = width / 100
        VStack(alignment: .leading, spacing: 2.4 * u) {
            Text("End of \(packName)")
                .font(CardFont.font(.title, size: 5.4 * u))
                .foregroundStyle(PouchInk.green)
            Text("You've turned every card in the pack. Turn them back to go over them again.")
                .font(CardFont.font(.body, size: 4.2 * u))
                .foregroundStyle(PouchInk.body)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6 * u) {
                stat("\(learntCount)", "learnt", u)
                stat("\(verseCount - learntCount)", "to go", u)
            }
        }
        .padding(.horizontal, 7 * u)
        .padding(.vertical, 6.4 * u)
        .frame(width: width, height: width / PouchMetrics.cardAspect, alignment: .topLeading)
        .background(PaperFace(tint: PouchInk.paperBack))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String, _ u: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 9 * u, weight: .semibold, design: .rounded))
                .foregroundStyle(PouchInk.green)
            Text(label)
                .font(.system(size: 3.2 * u))
                .foregroundStyle(PouchInk.caption)
        }
    }
}

/// Card stock: flat paper with a faint grain and a hairline edge, nearly square
/// corners like a die-cut card.
struct PaperFace: View {
    var tint: Color = PouchInk.paper

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        shape
            .fill(tint)
            .overlay(
                Image(uiImage: PaperGrain.tile)
                    .resizable(resizingMode: .tile)
                    .opacity(0.35)
                    .blendMode(.multiply)
                    .clipShape(shape)
            )
            .overlay(shape.strokeBorder(PouchInk.edgeLine, lineWidth: 0.5))
    }
}

/// A small tile of random speckle, generated once, tiled across every card.
/// Procedural rather than a photo so the paper stays neutral white.
enum PaperGrain {
    static let tile: UIImage = {
        let side = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            var rng = SeededRandom(seed: 0x5EED)
            for _ in 0..<900 {
                let x = Double(rng.next() % UInt64(side * 4)) / 4
                let y = Double(rng.next() % UInt64(side * 4)) / 4
                let shade = 0.80 + Double(rng.next() % 18) / 100
                let size = rng.next() % 5 == 0 ? 0.9 : 0.5
                UIColor(white: shade, alpha: 1).setFill()
                ctx.fill(CGRect(x: x, y: y, width: size, height: size))
            }
        }
    }()
}

/// Deterministic generator so the grain is identical on every launch.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
}
