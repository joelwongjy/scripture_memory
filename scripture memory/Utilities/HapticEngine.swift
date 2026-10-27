import CoreHaptics
import UIKit

/// Thin wrappers around UIKit feedback generators for consistent haptic responses.
enum HapticEngine {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft()    { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    struct Beat {
        var time: TimeInterval
        var intensity: Float
        var sharpness: Float
        var duration: TimeInterval = 0
    }

    static let packOpen: [Beat] = [
        Beat(time: 0, intensity: 0.5, sharpness: 0.25),
        Beat(time: 0.02, intensity: 0.18, sharpness: 0.1, duration: 0.3),
        Beat(time: 0.32, intensity: 0.4, sharpness: 0.45),
        Beat(time: 0.34, intensity: 0.22, sharpness: 0.3, duration: 0.22),
        Beat(time: 0.6, intensity: 0.75, sharpness: 0.7),
        Beat(time: 0.67, intensity: 0.55, sharpness: 0.75),
        Beat(time: 0.74, intensity: 0.42, sharpness: 0.8),
        Beat(time: 0.81, intensity: 0.3, sharpness: 0.85),
    ]

    static let packClose: [Beat] = [
        Beat(time: 0, intensity: 0.3, sharpness: 0.85),
        Beat(time: 0.06, intensity: 0.42, sharpness: 0.8),
        Beat(time: 0.12, intensity: 0.55, sharpness: 0.75),
        Beat(time: 0.22, intensity: 0.2, sharpness: 0.3, duration: 0.2),
        Beat(time: 0.66, intensity: 0.85, sharpness: 0.3),
    ]

    private static var engine: CHHapticEngine?
    private static var player: CHHapticPatternPlayer?
    private static var pending: [DispatchWorkItem] = []

    static func play(_ beats: [Beat]) {
        stop()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            playWithGenerators(beats)
            return
        }
        do {
            let engine = try runningEngine()
            let events = beats.map { beat in
                let params = [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: beat.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness),
                ]
                return beat.duration > 0
                    ? CHHapticEvent(eventType: .hapticContinuous, parameters: params,
                                    relativeTime: beat.time, duration: beat.duration)
                    : CHHapticEvent(eventType: .hapticTransient, parameters: params,
                                    relativeTime: beat.time)
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {
            playWithGenerators(beats)
        }
    }

    static func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        pending.forEach { $0.cancel() }
        pending = []
    }

    private static func runningEngine() throws -> CHHapticEngine {
        if let engine {
            try engine.start()
            return engine
        }
        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        try engine.start()
        self.engine = engine
        return engine
    }

    private static func playWithGenerators(_ beats: [Beat]) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        pending = beats.filter { $0.duration == 0 }.map { beat in
            let item = DispatchWorkItem {
                generator.impactOccurred(intensity: CGFloat(beat.intensity))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + beat.time, execute: item)
            return item
        }
    }
}
