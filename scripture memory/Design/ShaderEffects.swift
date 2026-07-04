import SwiftUI

// SwiftUI-side wrappers for the shaders in Effects.metal. Keep call sites on
// these modifiers (not raw ShaderLibrary lookups) so usage stays discoverable
// and the docs/DESIGN.md restraint rules are easy to audit.

extension View {
    /// Parchment paper tooth — a few percent of static luminance noise.
    /// Always on flashcard surfaces; nowhere else.
    func paperGrain(strength: Double) -> some View {
        colorEffect(ShaderLibrary.paperGrain(.float(Float(strength))))
    }

    /// The gilt sheen: a soft band of light sweeping the view every few
    /// seconds. Reserved for gold moments — the live streak flame and the
    /// session-complete seal. Keep the modified view small; this runs a
    /// 30 fps timeline while `isActive`.
    func giltSheen(isActive: Bool = true) -> some View {
        modifier(GiltSheenModifier(isActive: isActive))
    }
}

struct GiltSheenModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { context in
            // Wrapped to keep the float uniform precise; the shader only uses
            // fract(time/period), so the wrap point is invisible as long as it
            // is a multiple of the 3.4 s period.
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 340)
            let active = isActive
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.giltSheen(
                        .float2(proxy.size),
                        .float(Float(t)),
                        .color(Theme.sheen)
                    ),
                    isEnabled: active
                )
            }
        }
    }
}
