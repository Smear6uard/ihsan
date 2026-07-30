import Foundation

/// Exponential moving average over compass headings, corrected for the
/// actual time between samples and wraparound-safe across the 360/0 seam.
///
/// ## Why a time constant, and why 0.18 s
///
/// CoreLocation delivers heading at an uneven cadence (roughly 5–20 Hz
/// depending on hardware and motion), so a fixed per-sample alpha would
/// make the dial's damping change with delivery rate. Instead the blend
/// factor is derived from the elapsed time: `alpha = 1 − exp(−dt / τ)`,
/// which behaves identically at any sample rate.
///
/// τ = 0.18 s is tuned for the feel of a weighted instrument card:
///
/// - **Jitter:** sensor noise of ±1–2° arriving at ~10 Hz is attenuated
///   to sub-degree shimmer — invisible at dial scale, so the ring never
///   sizzles at rest.
/// - **Lag:** at fine-aiming turn rates (~10°/s, how a hand moves when
///   homing in), the steady-state lag is τ·ω ≈ 1.8° — inside the ±3°
///   alignment band, so the moment of alignment lands where the eye
///   says it should.
/// - **Settle:** after the hand stops, the dial glides to rest over
///   ~3τ ≈ 0.5 s — reads as mass and damping, not as software lag.
///
/// Alignment decisions are made downstream from the *smoothed* value, so
/// the haptic and the visual always agree.
public struct HeadingFilter: Sendable {
    /// The tuned default damping. See the type documentation.
    public static let defaultTimeConstant: TimeInterval = 0.18

    /// Time constant τ in seconds. Larger is heavier.
    public let timeConstant: TimeInterval

    private var current: Double?
    private var lastTimestamp: Date?

    public init(timeConstant: TimeInterval = HeadingFilter.defaultTimeConstant) {
        self.timeConstant = timeConstant
    }

    /// Blends a raw heading sample into the smoothed value and returns
    /// the new smoothed heading in [0, 360).
    ///
    /// The first sample passes through unfiltered. Samples whose
    /// timestamp does not advance are ignored (the previous smoothed
    /// value is returned) — the filter never divides time by zero and
    /// never steps backward. After a long gap the blend factor
    /// approaches 1, so a stale filter snaps to the fresh reading
    /// rather than dragging half-second-old state across it.
    public mutating func smooth(_ raw: Double, at timestamp: Date) -> Double {
        guard let last = current, let lastTime = lastTimestamp else {
            let normalized = QiblaMath.normalized(raw)
            current = normalized
            lastTimestamp = timestamp
            return normalized
        }

        let dt = timestamp.timeIntervalSince(lastTime)
        guard dt > 0 else { return last }

        let alpha = 1 - exp(-dt / timeConstant)
        let step = alpha * QiblaMath.signedDelta(from: last, to: raw)
        let next = QiblaMath.normalized(last + step)
        current = next
        lastTimestamp = timestamp
        return next
    }

    /// Forgets all history; the next sample passes through unfiltered.
    public mutating func reset() {
        current = nil
        lastTimestamp = nil
    }
}
