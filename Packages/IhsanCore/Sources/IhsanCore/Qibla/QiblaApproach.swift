import Foundation

/// The choreography of approach, as pure math: every light on the
/// instrument is a continuous, monotone function of how far the
/// smoothed heading sits from the qibla — a gradient of arrival,
/// never a binary switch.
///
/// Bands (degrees of absolute delta):
///
/// - **Far (>60°)** — rest. The lancet keeps its faint standing glow.
/// - **Approach (60→15°)** — the lancet's glow builds; the ring's
///   metal warms almost imperceptibly toward the lancet's side.
/// - **Near (15→3°)** — the fixed index warms toward gold and the
///   luminance bridge between index and lancet grows as they close.
/// - **Aligned** — every curve saturates. Alignment is the *gate's*
///   state (±3° in, ±6° out), so the visuals hold with the hysteresis
///   rather than flickering at the raw boundary.
///
/// All ramps are smootherstep-eased and meet their band boundaries at
/// equal values — no seam is visible at 60° or 15°. Under Reduce
/// Motion (`discrete: true`) each band renders one fixed value: the
/// stages remain readable while every glow ramp stops moving.
public struct QiblaApproach: Sendable, Equatable {

    public enum Stage: Sendable {
        case far
        case approach
        case near
        case aligned
    }

    /// The lancet's glow at rest — present even far off-axis, so the
    /// one gold element always reads as the element that matters.
    public static let standingGlow = 0.22

    public let stage: Stage
    /// Lancet glow strength, `standingGlow...1`.
    public let lancetGlow: Double
    /// Fixed index blend from engraved metal (0) toward gold (1).
    public let indexWarmth: Double
    /// Strength of the luminance bridge between index and lancet.
    public let bridgeStrength: Double
    /// Warmth of the ring's metal toward the lancet's side — subtle;
    /// callers scale it well below legibility of a "state".
    public let ringWarmth: Double

    public init(absDelta: Double, isAligned: Bool, discrete: Bool = false) {
        let delta = abs(absDelta)

        if isAligned {
            stage = .aligned
            lancetGlow = 1
            indexWarmth = 1
            bridgeStrength = 1
            ringWarmth = 1
            return
        }

        // Ramp positions: 0 at the far edge of a band, 1 at its close
        // edge. The near band closes at 3° (the gate's entry), so the
        // curves arrive at ~1 exactly as alignment can take over.
        let approachRamp = Self.smootherstep((60 - delta) / (60 - 15))
        let nearRamp = Self.smootherstep((15 - delta) / (15 - 3))

        if delta > 60 {
            stage = .far
        } else if delta > 15 {
            stage = .approach
        } else {
            stage = .near
        }

        if discrete {
            // One value per band — legible states, no moving ramps.
            switch stage {
            case .far:
                lancetGlow = Self.standingGlow
                ringWarmth = 0
                indexWarmth = 0
                bridgeStrength = 0
            case .approach:
                lancetGlow = 0.55
                ringWarmth = 0.5
                indexWarmth = 0
                bridgeStrength = 0
            case .near:
                lancetGlow = 0.85
                ringWarmth = 1
                indexWarmth = 0.7
                bridgeStrength = 0.7
            case .aligned:
                lancetGlow = 1
                ringWarmth = 1
                indexWarmth = 1
                bridgeStrength = 1
            }
            return
        }

        // The lancet brightens across BOTH bands: standing → 0.85 over
        // the approach, 0.85 → ~1 over the near band.
        lancetGlow = Self.standingGlow
            + (0.85 - Self.standingGlow) * approachRamp
            + (1.0 - 0.85) * nearRamp
        ringWarmth = approachRamp
        indexWarmth = nearRamp
        bridgeStrength = nearRamp
    }

    static func smootherstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}

/// Single-fire latch for the approach detents (the two soft ticks at
/// 15° and 5°, like a fine instrument finding its seat). Fires once
/// when the delta first drops under the threshold; jitter around the
/// boundary cannot re-fire it — it re-arms only after the heading
/// retreats past `threshold + rearmMargin`.
public struct QiblaDetentLatch: Sendable {
    public let threshold: Double
    public let rearmMargin: Double

    private var isArmed = true

    public init(threshold: Double, rearmMargin: Double = 5) {
        self.threshold = threshold
        self.rearmMargin = rearmMargin
    }

    /// Feeds the current absolute delta; returns `true` exactly when
    /// the detent clicks.
    public mutating func update(absDelta: Double) -> Bool {
        if isArmed {
            guard absDelta <= threshold else { return false }
            isArmed = false
            return true
        } else {
            if absDelta > threshold + rearmMargin { isArmed = true }
            return false
        }
    }
}
