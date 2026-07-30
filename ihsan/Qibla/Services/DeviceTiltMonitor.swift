import CoreMotion
import Foundation

/// Watches device pitch for the one case the compass card can't
/// absorb: a phone held near-vertical, where magnetic heading gets
/// unreliable and the flat-dial metaphor stops matching the hand.
/// Publishes a single boolean; the screen shows one quiet line.
///
/// Hysteresis (enter tilted below |gravity.z| = 0.45, recover above
/// 0.60) keeps the hint from flickering at the boundary.
@Observable
@MainActor
final class DeviceTiltMonitor {

    private(set) var needsFlattening = false

    private let manager = CMMotionManager()
    /// `-IhsanQiblaSimulateTilt` — simulator has no motion hardware.
    private let simulateTilt = ProcessInfo.processInfo.arguments
        .contains("-IhsanQiblaSimulateTilt")

    func start() {
        #if DEBUG
        if simulateTilt {
            needsFlattening = true
            return
        }
        #endif
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 0.25
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let gravity = motion?.gravity else { return }
            let flatness = abs(gravity.z)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.needsFlattening {
                    if flatness > 0.60 { self.needsFlattening = false }
                } else {
                    if flatness < 0.45 { self.needsFlattening = true }
                }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
