import SwiftUI

/// One-shot celebration: gold-leaf flakes (gold, lapis and cream slivers)
/// burst upward from a point and flutter down under gravity. Pure
/// Canvas + TimelineView — no assets, no UIKit emitters — and deterministic,
/// so the same summary always celebrates the same way.
///
/// Fire-and-forget: mount it when the moment happens; it draws for
/// `duration` seconds, then pauses its timeline and stays inert (and clear)
/// until removed. It never intercepts touches.
struct GoldLeafBurst: View {
    /// Launch point in unit coordinates of the burst's own bounds.
    var origin: UnitPoint = .init(x: 0.5, y: 0.4)
    var flakeCount: Int = 80
    var duration: Double = 2.6

    @State private var startDate: Date?
    @State private var finished = false

    private let flakes: [Flake]

    init(origin: UnitPoint = .init(x: 0.5, y: 0.4), flakeCount: Int = 80, duration: Double = 2.6) {
        self.origin = origin
        self.flakeCount = flakeCount
        self.duration = duration
        var rng = SplitMix64(seed: 0x1EAF_601D)
        self.flakes = (0..<flakeCount).map { _ in Flake(using: &rng) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: finished)) { context in
            Canvas { gc, size in
                guard let start = startDate else { return }
                let t = context.date.timeIntervalSince(start)
                guard t > 0, t < duration else { return }
                let launch = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
                for flake in flakes {
                    draw(flake, at: t, from: launch, in: gc)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { startDate = Date() }
        .task {
            try? await Task.sleep(for: .seconds(duration + 0.1))
            finished = true
        }
    }

    // MARK: - Drawing

    private func draw(_ flake: Flake, at time: Double, from launch: CGPoint, in gc: GraphicsContext) {
        let t = time - flake.delay
        guard t > 0 else { return }

        // Ballistic launch with gravity, plus a horizontal flutter-sway.
        let gravity = 640.0
        let x = launch.x + cos(flake.angle) * flake.speed * t
              + sin(t * flake.swayRate + flake.phase) * flake.swayAmount
        let y = launch.y - sin(flake.angle) * flake.speed * t + 0.5 * gravity * t * t

        // Fade out over the last third of the flight.
        let life = (time / duration)
        let alpha = life < 0.66 ? 1.0 : max(0, 1.0 - (life - 0.66) / 0.34)
        guard alpha > 0.01 else { return }

        // Tumble: rotate in-plane and fake the third axis by collapsing the
        // flake's height, so slivers glint as they turn over.
        let tumble = abs(cos(t * flake.spin + flake.phase))
        let rect = CGRect(x: -flake.size.width / 2,
                          y: -flake.size.height * (0.3 + 0.7 * tumble) / 2,
                          width: flake.size.width,
                          height: flake.size.height * (0.3 + 0.7 * tumble))

        var ctx = gc
        ctx.opacity = alpha
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .radians(t * flake.spin * 0.6 + flake.phase))
        ctx.fill(Path(roundedRect: rect, cornerRadius: rect.height * 0.4),
                 with: .color(flake.color))
    }

    // MARK: - Flake model

    private struct Flake {
        let angle: Double        // launch direction, radians (π/2 = straight up)
        let speed: Double        // points/second
        let size: CGSize
        let spin: Double         // tumble rate, radians/second
        let phase: Double
        let swayRate: Double
        let swayAmount: Double
        let delay: Double
        let color: Color

        init(using rng: inout SplitMix64) {
            angle      = Double.random(in: (.pi * 0.20)...(.pi * 0.80), using: &rng)
            speed      = Double.random(in: 220...560, using: &rng)
            let w      = Double.random(in: 5...11, using: &rng)
            size       = CGSize(width: w, height: w * Double.random(in: 0.5...0.9, using: &rng))
            spin       = Double.random(in: 5...13, using: &rng)
            phase      = Double.random(in: 0...(2 * .pi), using: &rng)
            swayRate   = Double.random(in: 1.5...3.5, using: &rng)
            swayAmount = Double.random(in: 4...18, using: &rng)
            delay      = Double.random(in: 0...0.12, using: &rng)
            color      = Self.palette.randomElement(using: &rng) ?? Theme.gold
        }

        /// Weighted toward gold — this is gold leaf with lapis and cream accents.
        static let palette: [Color] = [
            Theme.gold, Theme.gold, Theme.gold,
            Theme.gold.lightened(by: 0.12),
            Theme.flame,
            Color.accentColor,
            Color(red: 0.97, green: 0.95, blue: 0.89),
        ]
    }
}

/// Tiny deterministic RNG (SplitMix64) so the burst is identical every run —
/// no flaky visuals, and previews stay stable.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        GoldLeafBurst()
    }
}
