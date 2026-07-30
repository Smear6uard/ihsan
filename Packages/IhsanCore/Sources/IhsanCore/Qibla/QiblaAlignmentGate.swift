import Foundation

/// Hysteresis state machine for the qibla alignment band.
///
/// Alignment *enters* when the absolute delta to the qibla drops to
/// `enterDegrees` or less, and *exits* only once it climbs strictly
/// beyond `exitDegrees`. The asymmetric band (default 3° in, 6° out)
/// means a hand hovering at the boundary can never machine-gun the
/// alignment moment: after entry, the state holds through the whole
/// 3–6° margin, and after exit, that same margin does not re-arm it.
public struct QiblaAlignmentGate: Sendable {
    public enum Event: Sendable {
        /// No state change this update.
        case unchanged
        /// Crossed into the aligned band — fire the one haptic here.
        case entered
        /// Drifted beyond the exit band — reverse gracefully, no feedback.
        case exited
    }

    /// Absolute delta at or below which alignment begins.
    public let enterDegrees: Double
    /// Absolute delta strictly beyond which alignment ends.
    public let exitDegrees: Double

    public private(set) var isAligned = false

    public init(enterDegrees: Double = 3, exitDegrees: Double = 6) {
        self.enterDegrees = enterDegrees
        self.exitDegrees = exitDegrees
    }

    /// Feeds the current signed delta (shortest rotation to the qibla,
    /// wraparound already resolved) and reports any state transition.
    public mutating func update(signedDelta: Double) -> Event {
        let magnitude = abs(signedDelta)
        if isAligned {
            guard magnitude > exitDegrees else { return .unchanged }
            isAligned = false
            return .exited
        } else {
            guard magnitude <= enterDegrees else { return .unchanged }
            isAligned = true
            return .entered
        }
    }
}
