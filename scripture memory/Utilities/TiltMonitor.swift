import CoreMotion
import SwiftUI

/// How far the phone is tipped left or right, smoothed, for light that moves
/// across the pouch's plastic as you tilt it. -1…1, 0 when held level or when
/// there is no motion data (the Simulator, Reduce Motion).
@MainActor
final class TiltMonitor: ObservableObject {
    @Published private(set) var roll: CGFloat = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !AppMotion.reduceMotion, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let target = CGFloat(max(-1, min(1, motion.attitude.roll / 0.6)))
            MainActor.assumeIsolated {
                guard let self else { return }
                // Ease toward the reading so the highlight glides rather than jitters.
                self.roll += (target - self.roll) * 0.18
            }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}
