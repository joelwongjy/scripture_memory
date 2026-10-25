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
    static let paper    = Color(red: 0.965, green: 0.962, blue: 0.950)
    static let paperBack = Color(red: 0.925, green: 0.921, blue: 0.905)
    static let title    = Color(white: 0.33)
    static let body     = Color(white: 0.14)
    static let caption  = Color(white: 0.30)
    static let green    = Color(red: 0.12, green: 0.55, blue: 0.37)
    static let mint     = Color(red: 0.80, green: 0.91, blue: 0.86)
}

/// One verse card, front face.
struct PouchVerseCard: View {
    let verse: Verse
    let isLearnt: Bool
    let width: CGFloat

    var body: some View {
        let u = width / 100                       // one percent of the card's width
        let footer = CardFooter.label(for: verse).components(separatedBy: " · ")

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verse.title)
                    .font(.custom("AvenirNext-Bold", size: 5.4 * u))
                    .foregroundStyle(PouchInk.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2 * u)
                Text(verse.pinnedVersion ?? "NIV")
                    .font(.custom("TimesNewRomanPSMT", size: 3.4 * u))
                    .foregroundStyle(PouchInk.caption)
            }
            Text(reference)
                .font(.custom("Optima-Regular", size: 4.6 * u))
                .foregroundStyle(PouchInk.body)
                .padding(.top, 1.2 * u)
            Text(verse.verse)
                .font(.custom("Optima-Regular", size: 4.6 * u))
                .foregroundStyle(PouchInk.body)
                .lineSpacing(0.9 * u)
                .minimumScaleFactor(0.55)
                .padding(.top, 0.6 * u)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            Text(reference)
                .font(.custom("Optima-Regular", size: 4.6 * u))
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
                .font(.custom("AvenirNext-Bold", size: 5.4 * u))
                .foregroundStyle(PouchInk.green)
            Text("You've turned every card in the pack. Turn them back to go over them again.")
                .font(.custom("Optima-Regular", size: 4.2 * u))
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
        .background(PaperFace(tint: .white))
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
            .overlay(shape.strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5))
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
