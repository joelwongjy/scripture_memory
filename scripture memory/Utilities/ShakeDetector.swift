import UIKit

extension Notification.Name {
    /// Posted whenever the user physically shakes the device.
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

extension UIWindow {
    /// Broadcasts shake gestures app-wide. UIKit delivers shakes to the first
    /// responder; intercepting at the window means no view has to fight for
    /// responder status — SwiftUI views just listen for `.deviceDidShake`.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
