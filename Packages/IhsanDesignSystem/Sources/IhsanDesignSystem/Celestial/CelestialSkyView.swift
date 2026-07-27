import SwiftUI

extension EnvironmentValues {
    /// Preview-only overrides: the system accessibility keys are
    /// read-only, so the gallery demonstrates Reduce Motion / Reduce
    /// Transparency behavior by OR-ing these in. Never set from app
    /// code — the system settings always win on their own.
    @Entry var celestialForceReducedMotion: Bool = false
    @Entry var celestialForceReducedTransparency: Bool = false
}

/// The plate's atmosphere: sky gradient, horizon band, terrain
/// filament, ground plane, and star field, drawn in a single `Canvas`
/// inside a `TimelineView`.
///
/// Composition rules this view enforces:
///
/// - **The horizon is a band, not a line.** An atmospheric gradient
///   zone (~8% of plate height) where the sky meets the ground plane,
///   with a glow that intensifies as the sun approaches the chord.
/// - **The ground plane is the same material, deeper** — the ground
///   tone one lightness step down, never a new color.
/// - **The terrain mark is a filament** — a single fine metal lens
///   with tapered ends, never an edge-to-edge rule.
/// - **Stars belong to the night** — two depth layers, fixed seed, no
///   shimmer; they fade in with `SkyPhase.nightness` rather than
///   popping at a threshold.
///
/// Accessibility contract: with Reduce Motion the timeline pauses and
/// every time-dependent term freezes at its base value; with Reduce
/// Transparency all gradients collapse to flat fills and the grain
/// overlay disappears. The view is decorative and hidden from
/// VoiceOver.
public struct CelestialSkyView: View {

    public let phase: SkyPhase
    /// Current sun altitude in degrees — drives the horizon glow.
    public let sunAltitudeDegrees: Double
    /// Preferred horizon height as a fraction of the view height,
    /// used when no explicit `horizonY` is given.
    public let horizonFraction: CGFloat
    /// Exact horizon chord position (pass `PlateGeometry.horizonY`
    /// when composing a full scene so the atmosphere and the markers
    /// agree). `nil` derives it from `horizonFraction`.
    public let horizonYOverride: CGFloat?
    /// Seed for the star field. Fixed by default so the night sky is
    /// the same sky every launch.
    public let starSeed: UInt64
    /// Optional frame-time probe for the render loop.
    public let probe: FrameTimeProbe?

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedMotion) private var forceReducedMotion
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency

    private var reduceMotion: Bool { systemReduceMotion || forceReducedMotion }
    private var reduceTransparency: Bool { systemReduceTransparency || forceReducedTransparency }

    public init(
        phase: SkyPhase,
        sunAltitudeDegrees: Double,
        horizonFraction: CGFloat = 0.62,
        horizonY: CGFloat? = nil,
        starSeed: UInt64 = 0x1A5F_0426,
        probe: FrameTimeProbe? = nil
    ) {
        self.phase = phase
        self.sunAltitudeDegrees = sunAltitudeDegrees
        self.horizonFraction = horizonFraction
        self.horizonYOverride = horizonY
        self.starSeed = starSeed
        self.probe = probe
    }

    /// The only time-dependent term is the horizon glow's breathing;
    /// when the sun is far from the chord the whole scene is static
    /// and the 60 fps timeline pauses rather than redrawing a
    /// still image.
    private var sceneAnimates: Bool {
        exp(-pow(sunAltitudeDegrees / 9.0, 2)) > 0.01
    }

    public var body: some View {
        let tokens = PaletteState.resolved(for: phase)
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion || !sceneAnimates)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let start = CFAbsoluteTimeGetCurrent()
                Self.draw(
                    into: &context,
                    size: size,
                    tokens: tokens,
                    nightness: phase.nightness,
                    sunAltitudeDegrees: sunAltitudeDegrees,
                    horizonY: horizonYOverride ?? size.height * horizonFraction,
                    time: time,
                    flat: reduceTransparency,
                    seed: starSeed
                )
                probe?.record(CFAbsoluteTimeGetCurrent() - start)
            }
        }
        .overlay {
            if !reduceTransparency {
                PlateGrainOverlay(tint: tokens.inkValue.color, seed: starSeed)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    static func draw(
        into context: inout GraphicsContext,
        size: CGSize,
        tokens: SkyPaletteTokens,
        nightness: Double,
        sunAltitudeDegrees: Double,
        horizonY: CGFloat,
        time: TimeInterval,
        flat: Bool,
        seed: UInt64
    ) {
        let bandHeight = size.height * 0.08

        // Sky.
        let skyRect = CGRect(origin: .zero, size: size)
        if flat {
            context.fill(Path(skyRect), with: .color(tokens.ground))
        } else {
            context.fill(
                Path(skyRect),
                with: .linearGradient(
                    Gradient(colors: [tokens.groundTopValue.color, tokens.groundBottomValue.color]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }

        // Star field — night only, two depth layers, fixed seed.
        if nightness > 0.02 {
            drawStars(
                into: &context,
                size: size,
                belowLimit: horizonY - bandHeight * 0.6,
                color: tokens.inkValue.color,
                nightness: nightness,
                seed: seed
            )
        }

        // Ground plane below the chord — the ground tone, one
        // lightness step deeper.
        let groundRect = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
        context.fill(Path(groundRect), with: .color(tokens.subterranean))

        // Horizon band: the atmospheric zone where sky meets ground.
        let washTop = CGRect(
            x: 0, y: horizonY - bandHeight, width: size.width, height: bandHeight
        )
        if flat {
            context.fill(
                Path(CGRect(x: 0, y: horizonY - bandHeight * 0.5, width: size.width, height: bandHeight * 0.5)),
                with: .color(tokens.horizonWashValue.color.opacity(0.35))
            )
        } else {
            context.fill(
                Path(washTop),
                with: .linearGradient(
                    Gradient(colors: [
                        tokens.horizonWashValue.color.opacity(0.0),
                        tokens.horizonWashValue.color.opacity(0.55)
                    ]),
                    startPoint: CGPoint(x: 0, y: washTop.minY),
                    endPoint: CGPoint(x: 0, y: washTop.maxY)
                )
            )
            // A shallower echo of the wash bleeds below the chord so
            // the band straddles the boundary instead of stopping at it.
            let washBelow = CGRect(x: 0, y: horizonY, width: size.width, height: bandHeight * 0.4)
            context.fill(
                Path(washBelow),
                with: .linearGradient(
                    Gradient(colors: [
                        tokens.horizonWashValue.color.opacity(0.30),
                        tokens.horizonWashValue.color.opacity(0.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: washBelow.minY),
                    endPoint: CGPoint(x: 0, y: washBelow.maxY)
                )
            )

            // Sun-approach glow: strongest when the sun sits on the
            // chord, fading as it climbs or sinks away. Breathes very
            // gently; frozen when the timeline is paused.
            let proximity = exp(-pow(sunAltitudeDegrees / 9.0, 2))
            if proximity > 0.01 {
                let breathing = time == 0 ? 1.0 : 1.0 + 0.06 * sin(time * 0.7)
                let glowRect = CGRect(
                    x: 0, y: horizonY - bandHeight * 1.4,
                    width: size.width, height: bandHeight * 2.2
                )
                context.fill(
                    Path(glowRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            tokens.glowValue.color.opacity(0.42 * proximity * breathing),
                            tokens.glowValue.color.opacity(0.0)
                        ]),
                        center: CGPoint(x: size.width / 2, y: horizonY),
                        startRadius: 0,
                        endRadius: max(size.width * 0.55, bandHeight * 2.2)
                    )
                )
            }
        }

        // Terrain filament: one fine metal lens, tapered ends.
        let filament = PlateGeometry.filamentPath(
            in: CGRect(origin: .zero, size: size),
            horizonY: horizonY,
            thickness: 1.4
        )
        context.fill(Path(filament), with: .color(tokens.metalValue.color.opacity(0.85)))
    }

    private static func drawStars(
        into context: inout GraphicsContext,
        size: CGSize,
        belowLimit: CGFloat,
        color: Color,
        nightness: Double,
        seed: UInt64
    ) {
        guard belowLimit > 4 else { return }
        // Far layer: small and dim. Near layer: fewer, slightly larger.
        let layers: [(count: Int, seed: UInt64, radius: ClosedRange<Double>, opacity: Double)] = [
            (72, seed, 0.45...0.85, 0.30),
            (26, seed ^ 0x9E37_79B9_7F4A_7C15, 0.85...1.5, 0.55)
        ]
        for layer in layers {
            var rng = SeededGenerator(state: layer.seed)
            for _ in 0..<layer.count {
                let x = rng.unit() * size.width
                let y = rng.unit() * belowLimit
                let radius = layer.radius.lowerBound
                    + rng.unit() * (layer.radius.upperBound - layer.radius.lowerBound)
                let twinkleWeight = 0.75 + 0.25 * rng.unit()
                let rect = CGRect(
                    x: x - radius, y: y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(color.opacity(layer.opacity * twinkleWeight * nightness))
                )
            }
        }
    }
}

// MARK: - Grain overlay

/// Static film-grain texture over the full plate — a fixed seeded
/// speckle field at ≤3% strength. Drawn once (no timeline
/// dependency), so it costs nothing per frame; under Reduce Motion it
/// is already static, and under Reduce Transparency the sky view
/// omits it entirely.
///
/// This is the graceful-degradation implementation of the plate
/// grain. The Metal shader variant (`Celestial/Shaders/
/// CelestialShaders.metal`, currently excluded from the build) adds
/// live filmic movement on hardware once the Metal toolchain is
/// available; this Canvas layer is its exact static fallback.
struct PlateGrainOverlay: View {

    let tint: Color
    let seed: UInt64
    var intensity: Double = 0.03

    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(state: seed ^ 0xF11A_9AA1_77E1_D05B)
            let strength = min(0.03, intensity)
            let count = Int((size.width * size.height / 210).rounded())
            for _ in 0..<count {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height
                let side = 0.7 + rng.unit() * 0.8
                context.fill(
                    Path(CGRect(x: x, y: y, width: side, height: side)),
                    with: .color(tint.opacity(strength * (0.4 + 0.6 * rng.unit())))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Seeded RNG

/// SplitMix64 — deterministic positions for stars and grain. The sky
/// must be the same sky on every launch; `SystemRandomNumberGenerator`
/// would reshuffle the heavens per frame tree rebuild.
struct SeededGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `[0, 1)`.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
