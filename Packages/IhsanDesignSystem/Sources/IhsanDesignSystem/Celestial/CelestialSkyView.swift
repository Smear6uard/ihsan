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
/// - **Light is painted, never filmed.** The sun's horizon
///   interaction is a radial bloom centered on the sun's own
///   position, dying to nothing within ~35% of the width. The
///   banned list (see the package README): lens flares, horizontal
///   light streaks, anamorphic effects, specular hotspots, bokeh,
///   any camera-artifact rendering.
/// - **The ground plane is the same material, deeper** — the ground
///   deepens smoothly away from the chord, one value step down at
///   the bottom, never a new color.
/// - **The terrain mark is a filament** — a single fine metal lens
///   with tapered ends, never an edge-to-edge rule. It brightens and
///   warms only inside the sun's local bloom.
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
    /// The sun's horizontal position in this view's coordinate space,
    /// when the composer knows it (pass the x of
    /// `PlateGeometry.bodyPosition` for the sun). The horizon's light
    /// is LOCAL — a radial bloom around this point, dying to nothing
    /// within ~35% of the width — so without it the filament simply
    /// stays quiet. Never a full-width band either way.
    public let sunX: CGFloat?
    /// Preferred horizon height as a fraction of the view height,
    /// used when no explicit `horizonY` is given.
    public let horizonFraction: CGFloat
    /// Exact horizon chord position (pass `PlateGeometry.horizonY`
    /// when composing a full scene so the atmosphere and the markers
    /// agree). `nil` derives it from `horizonFraction`.
    public let horizonYOverride: CGFloat?
    /// Height of the instrument zone the horizon band is sized
    /// against. The band spec is 6–10% *of the plate*, not of the
    /// whole frame — pass `PlateGeometry.rect.height` when composing
    /// a full scene. `nil` falls back to the view's own height.
    public let plateHeight: CGFloat?
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
        sunX: CGFloat? = nil,
        horizonFraction: CGFloat = 0.62,
        horizonY: CGFloat? = nil,
        plateHeight: CGFloat? = nil,
        starSeed: UInt64 = 0x1A5F_0426,
        probe: FrameTimeProbe? = nil
    ) {
        self.phase = phase
        self.sunAltitudeDegrees = sunAltitudeDegrees
        self.sunX = sunX
        self.horizonFraction = horizonFraction
        self.horizonYOverride = horizonY
        self.plateHeight = plateHeight
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
                    sunX: sunX,
                    horizonY: horizonYOverride ?? size.height * horizonFraction,
                    plateHeight: plateHeight ?? size.height,
                    time: time,
                    flat: reduceTransparency,
                    seed: starSeed,
                    dawnProgress: phase.dawnProgress
                )
                probe?.record(CFAbsoluteTimeGetCurrent() - start)
            }
        }
        .overlay {
            if !reduceTransparency {
                // Vellum grain at the threshold of visibility at
                // arm's length on the day fields (~4.5%); the night
                // states keep their quieter film grain. The overlay
                // sits on the sky/ground field only — ornaments,
                // filaments, and text render in layers above it.
                PlateGrainOverlay(
                    tint: tokens.inkValue.color,
                    seed: starSeed,
                    intensity: tokens.groundBottomValue.relativeLuminance > 0.5
                        ? PlateGrainOverlay.dayIntensity
                        : 0.03
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - The sky ramp

    /// Where `groundTop` sits in the sky's vertical span. Above it the
    /// ramp travels zenith → groundTop; below it, groundTop →
    /// groundBottom at the chord.
    nonisolated static let skyBreakpoint: Double = 0.55
    /// Samples above and below the breakpoint. The upper segment gets
    /// far more because it carries the whole zenith→near-white
    /// journey; the lower one crosses two near-identical near-whites.
    nonisolated private static let zenithSegmentSamples = 11
    nonisolated private static let horizonSegmentSamples = 5

    /// The sky's stop table: zenith → groundTop → groundBottom,
    /// sampled in OKLCH so the ramp keeps its chroma, with `groundTop`
    /// pinned exactly at the breakpoint.
    /// How fully the worked-earth engraving draws, given the sun's
    /// altitude. See `groundEngravingRecedesWhenTheSunSitsOnTheChord`.
    /// Same `exp(-(alt/9)²)` proximity the horizon bloom uses, so the
    /// engraving and the light it yields to always agree.
    nonisolated static func groundEngravingPresence(
        sunAltitudeDegrees: Double
    ) -> Double {
        1.0 - 0.85 * exp(-pow(sunAltitudeDegrees / 9.0, 2))
    }

    nonisolated static func skyGradientStops(tokens: SkyPaletteTokens) -> [Gradient.Stop] {
        skySamples(tokens: tokens).map {
            .init(color: $0.value.color, location: $0.location)
        }
    }

    /// The same table as raw values. Internal rather than private so
    /// the contrast audit can walk the EXACT field the plate paints:
    /// the three ground tokens are only three points on a ramp that
    /// plate text sits anywhere along.
    nonisolated static func skySamples(
        tokens: SkyPaletteTokens
    ) -> [(location: Double, value: SRGBValue)] {
        let zenith = tokens.skyZenithValue
        let upper = tokens.groundTopValue
        let lower = tokens.groundBottomValue
        var samples: [(location: Double, value: SRGBValue)] = []
        for i in 0...zenithSegmentSamples {
            let f = Double(i) / Double(zenithSegmentSamples)
            samples.append((
                skyBreakpoint * f,
                .mixOKLCH(zenith, upper, amount: f)
            ))
        }
        for i in 1...horizonSegmentSamples {
            let f = Double(i) / Double(horizonSegmentSamples)
            samples.append((
                skyBreakpoint + (1 - skyBreakpoint) * f,
                .mixOKLCH(upper, lower, amount: f)
            ))
        }
        return samples
    }

    /// The one flat colour that stands in for the whole graded sky
    /// under Reduce Transparency: the ramp's length-weighted mean.
    ///
    /// `tokens.ground` — the midpoint of groundTop and groundBottom —
    /// used to be close enough, because the zenith was a near-white
    /// barely distinguishable from them. Corrective H made the day
    /// zenith a real blue occupying the top half of the field, and a
    /// flat fill that ignores it hands Reduce Transparency users a
    /// blank white page where everyone else sees a sky. The fallback
    /// cannot carry the gradient, but it can carry the sky's colour.
    nonisolated static func skyFlatValue(tokens: SkyPaletteTokens) -> SRGBValue {
        let samples = skySamples(tokens: tokens)
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for (a, b) in zip(samples, samples.dropFirst()) {
            let span = b.location - a.location
            red += (a.value.red + b.value.red) / 2 * span
            green += (a.value.green + b.value.green) / 2 * span
            blue += (a.value.blue + b.value.blue) / 2 * span
            weight += span
        }
        guard weight > 0 else { return tokens.groundTopValue }
        return SRGBValue(red: red / weight, green: green / weight, blue: blue / weight)
    }

    /// The painted sky colour at `fraction` of the way from the top of
    /// the frame to the horizon chord — stop-table lookup with the
    /// straight component interpolation SwiftUI applies between stops,
    /// so this is what a pixel there actually is.
    nonisolated static func skyValue(
        atFraction fraction: Double,
        tokens: SkyPaletteTokens
    ) -> SRGBValue {
        let samples = skySamples(tokens: tokens)
        let t = max(0, min(1, fraction))
        guard let upperIndex = samples.firstIndex(where: { $0.location >= t }) else {
            return samples[samples.count - 1].value
        }
        guard upperIndex > 0 else { return samples[0].value }
        let a = samples[upperIndex - 1]
        let b = samples[upperIndex]
        let span = b.location - a.location
        let f = span > 0 ? (t - a.location) / span : 0
        return SRGBValue(
            red: a.value.red + (b.value.red - a.value.red) * f,
            green: a.value.green + (b.value.green - a.value.green) * f,
            blue: a.value.blue + (b.value.blue - a.value.blue) * f
        )
    }

    // MARK: - Drawing

    static func draw(
        into context: inout GraphicsContext,
        size: CGSize,
        tokens: SkyPaletteTokens,
        nightness: Double,
        sunAltitudeDegrees: Double,
        sunX: CGFloat? = nil,
        horizonY: CGFloat,
        plateHeight: CGFloat? = nil,
        time: TimeInterval,
        flat: Bool,
        seed: UInt64,
        dawnProgress: Double = 0
    ) {
        // The horizon band: ~8% of the *plate* height, inside the
        // spec's 6–10% window.
        let bandHeight = (plateHeight ?? size.height) * 0.08
        let onDarkGround = tokens.groundBottomValue.relativeLuminance < 0.5

        // Sky: zenith blue at the top blending down to the warm
        // horizon — the manuscript chord's other voice, present even
        // on the day states. Stops are sampled through OKLCH so the
        // blue→warm ramp keeps its chroma instead of graying out in
        // the middle; the gradient is anchored to the chord, and the
        // ground plane paints over everything beneath it.
        //
        // Corrective H raised the day zeniths to a real lapis-leaning
        // blue, which roughly triples the perceptual distance the ramp
        // has to travel. Stop count went 7 → 17 with it: the stops are
        // OKLCH samples joined by SwiftUI's straight sRGB
        // interpolation, so each segment is a chord across a curve, and
        // a longer journey needs shorter chords to stay smooth.
        // Seventeen fills cost nothing measurable — this is still one
        // gradient.
        let skyRect = CGRect(origin: .zero, size: size)
        if flat {
            context.fill(Path(skyRect), with: .color(Self.skyFlatValue(tokens: tokens).color))
        } else {
            context.fill(
                Path(skyRect),
                with: .linearGradient(
                    Gradient(stops: Self.skyGradientStops(tokens: tokens)),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: max(horizonY, 1))
                )
            )
        }

        // First light: the dawn wash in the east — a soft painted
        // lift rising from the horizon around the sun's coming
        // position, growing with the phase's dawnProgress and gone
        // the moment morning owns the sky. Local like every light on
        // the plate: radial around the sunrise point, dying within
        // ~55% of the width. Skipped flat (Reduce Transparency) —
        // the dawn ground itself carries the state there.
        if !flat, dawnProgress > 0.01, let sunX {
            let washColor = SRGBValue.mix(
                tokens.horizonWashValue, tokens.glowValue, amount: 0.40
            ).color
            let radius = size.width * 0.55
            let strength = 0.30 * dawnProgress
            var wash = context
            wash.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY)))
            wash.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: washColor.opacity(strength), location: 0),
                        .init(color: washColor.opacity(strength * 0.35), location: 0.5),
                        .init(color: washColor.opacity(0), location: 1)
                    ]),
                    center: CGPoint(x: sunX, y: horizonY),
                    startRadius: 0,
                    endRadius: radius
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

        // Gold dust — the day's answer to the star field. Under Reduce
        // Transparency the whole field is flat fills, so it goes with
        // the gradients.
        if !flat, tokens.daylightPresence > 0.01 {
            drawGoldDust(
                into: &context,
                size: size,
                belowLimit: horizonY - bandHeight * 0.6,
                tokens: tokens,
                seed: seed
            )
        }

        // Ground plane below the chord — its own token, deepening
        // smoothly away from the horizon so the focused card sits on
        // calm ground. Same material, one value step down; never a new
        // color. Flat under Reduce Transparency.
        //
        // Corrective H item 5 front-loaded the day ramp. The old
        // two-stop light-ground gradient spent its whole (already
        // slight) ×0.94 range across the full ground height — but the
        // focused card covers nearly all of that height, so the only
        // strip anyone sees, the ~24 pt between the chord and the
        // card, was getting a couple of percent of the range and read
        // dead flat. The day band now takes most of its value in the
        // first fifth below the chord and continues to a deeper floor,
        // so the earth is modelled exactly where it is visible. Still
        // one token, scaled in lightness — same family, no new hues.
        let groundRect = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
        if flat {
            context.fill(Path(groundRect), with: .color(tokens.groundPlane))
        } else {
            let plane = tokens.groundPlaneValue
            let stops: [Gradient.Stop] = onDarkGround
                ? [
                    .init(color: plane.color, location: 0),
                    .init(color: plane.scalingLightness(by: 0.78).color, location: 1)
                ]
                : [
                    .init(color: plane.color, location: 0),
                    .init(color: plane.scalingLightness(by: 0.925).color, location: 0.22),
                    .init(color: plane.scalingLightness(by: 0.86).color, location: 1)
                ]
            context.fill(
                Path(groundRect),
                with: .linearGradient(
                    Gradient(stops: stops),
                    startPoint: CGPoint(x: 0, y: horizonY),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }

        // The worked earth: three engraved filaments echoing the
        // terrain mark below the chord, shortening and fading as they
        // deepen — the ground is drawn, not merely painted. Depths
        // stay within the exposed strip between the chord and the
        // focused card (~24 pt in the Today composition).
        //
        // Corrective H item 3: the day weights used to be roughly half
        // the night ones, which put them under the threshold of
        // arm's-length visibility — the ground read as drawn only
        // after dark. They now sit slightly ABOVE the night weights,
        // because the same alpha buys less on a near-white field:
        // `metal` measures ~6.4:1 against the night ground and ~2.6:1
        // against the day ground, so matching the night's presence
        // costs more ink, not less.
        let groundFilaments: [(depth: CGFloat, thickness: CGFloat, inset: CGFloat, opacity: Double)] =
            onDarkGround
                ? [
                    (7, 1.2, 0.11, 0.46),
                    (14, 1.0, 0.17, 0.30),
                    (21, 0.9, 0.24, 0.18)
                ]
                : [
                    (7, 1.2, 0.11, 0.52),
                    (14, 1.0, 0.17, 0.34),
                    (21, 0.9, 0.24, 0.21)
                ]
        // The engraving yields to the light. Three parallel full-width
        // marks lit by the sun's own bloom read as rays off it — the
        // one thing the painted-light ban exists to prevent — so as
        // the sun approaches the chord these recede and the ground
        // reads as ground. The terrain chord and its lapis hairline
        // stay: they are the horizon, not a field.
        let engravingPresence = Self.groundEngravingPresence(
            sunAltitudeDegrees: sunAltitudeDegrees
        )
        for filament in groundFilaments {
            let y = horizonY + filament.depth
            guard y < size.height - 4 else { continue }
            context.fill(
                Path(PlateGeometry.filamentPath(
                    in: CGRect(origin: .zero, size: size),
                    horizonY: y,
                    thickness: filament.thickness,
                    insetFraction: filament.inset
                )),
                with: .color(
                    tokens.metalValue.color.opacity(filament.opacity * engravingPresence)
                )
            )
        }

        // Terrain filament: one fine metal lens, tapered ends.
        let filament = PlateGeometry.filamentPath(
            in: CGRect(origin: .zero, size: size),
            horizonY: horizonY,
            thickness: 1.4
        )
        context.fill(Path(filament), with: .color(tokens.metalValue.color.opacity(0.85)))

        // The chord's paired voice: one fine lapis filament riding
        // just beneath the gold, slightly shorter — ultramarine and
        // gold together, as on the page.
        let lapisFilament = PlateGeometry.filamentPath(
            in: CGRect(origin: .zero, size: size),
            horizonY: horizonY + 3,
            thickness: 0.9,
            insetFraction: 0.085
        )
        context.fill(Path(lapisFilament), with: .color(tokens.lapisValue.color.opacity(0.55)))

        // The sun's horizon interaction — PAINTED light, strictly
        // local. No full-width band, no screen-center hotspot: a
        // radial bloom centered on the sun's own position, dying to
        // nothing within ~35% of the width. Inside that radius the
        // horizon filament brightens and warms and the glow bleeds a
        // few points into the ground; outside it, the chord stays the
        // quiet tapered gold above its lapis hairline. Gone under
        // Reduce Transparency (the filaments above are the flat
        // fallback), and gone with the sun — the strength peaks at
        // the chord and dies as the sun climbs away or sinks below
        // civil twilight.
        if !flat, let sunX {
            let proximity = exp(-pow(sunAltitudeDegrees / 9.0, 2))
            let breathing = time == 0 ? 1.0 : 1.0 + 0.06 * sin(time * 0.7)
            let strength = proximity * breathing
            if strength > 0.02 {
                let bloomRadius = size.width * 0.35
                let bloomCenter = CGPoint(x: sunX, y: horizonY)
                let warmed = SRGBValue.mix(
                    tokens.metalHighlightValue, tokens.glowValue, amount: 0.55
                ).color

                // The filament brightens ONLY within the bloom.
                var lit = context
                lit.clip(to: Path(PlateGeometry.filamentPath(
                    in: CGRect(origin: .zero, size: size),
                    horizonY: horizonY,
                    thickness: 1.8
                )))
                lit.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: warmed.opacity(0.95 * strength), location: 0),
                            .init(color: warmed.opacity(0.40 * strength), location: 0.55),
                            .init(color: warmed.opacity(0), location: 1)
                        ]),
                        center: bloomCenter,
                        startRadius: 0,
                        endRadius: bloomRadius
                    )
                )

                // The ground catches the glow — a few points deep,
                // the same local radius, nothing more.
                let bleedDepth: CGFloat = 7
                var bleed = context
                bleed.clip(to: Path(CGRect(
                    x: 0, y: horizonY, width: size.width, height: bleedDepth
                )))
                bleed.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: tokens.glowValue.color.opacity(0.30 * strength), location: 0),
                            .init(color: tokens.glowValue.color.opacity(0), location: 1)
                        ]),
                        center: bloomCenter,
                        startRadius: 0,
                        endRadius: bloomRadius * 0.8
                    )
                )
            }
        }
    }

    /// Illumination speckle — the day's answer to the star field
    /// (corrective H item 4).
    ///
    /// A leaf-gilded page never sits flat: burnished gold throws back
    /// stray points of light as the page moves. This is that, and only
    /// that. It is calibrated to stay UNDER the vellum grain the sky
    /// view already lays down, which is itself set at the threshold of
    /// visibility: the grain puts ~1 speck per 210 pt² at ≤4.5% alpha,
    /// which over a 393 × 300 sky is ~560 marks; this puts 44 across
    /// the same field. Two orders of magnitude sparser, marginally
    /// brighter each — the difference between a texture and a
    /// barely-caught glint, which is the whole acceptance criterion.
    ///
    /// Static, fixed seed, no twinkle: the same flecks in the same
    /// places every launch, exactly like the stars. Nothing here reads
    /// the clock, so Reduce Motion needs no branch.
    private static func drawGoldDust(
        into context: inout GraphicsContext,
        size: CGSize,
        belowLimit: CGFloat,
        tokens: SkyPaletteTokens,
        seed: UInt64
    ) {
        guard belowLimit > 4 else { return }
        // Density per point² matched to the reference 393 × 300 sky,
        // so the scatter thins and thickens with the plate rather than
        // clumping on a compact one.
        let count = max(6, Int((size.width * belowLimit / goldDustMarkArea).rounded()))
        let tint = SRGBValue.mix(
            tokens.metalHighlightValue, tokens.leafGoldValue, amount: 0.35
        ).color
        var rng = SeededGenerator(state: seed ^ 0x51ED_270B_D170_1A3F)
        for _ in 0..<count {
            let x = rng.unit() * size.width
            let y = rng.unit() * belowLimit
            let radius = 0.35 + rng.unit() * 0.55
            // A ×3 spread in weight: most flecks are barely present,
            // a few catch properly. An even scatter reads as a screen.
            let weight = 0.34 + 0.66 * pow(rng.unit(), 2.2)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius, y: y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(
                    tint.opacity(goldDustPeakOpacity * weight * tokens.daylightPresence)
                )
            )
        }
    }

    /// Peak alpha of a single fleck. Above the grain's own ceiling,
    /// deliberately: a fleck no brighter than the grain around it
    /// would simply BE grain, and the whole point of the dust is that
    /// it is a different kind of mark. Sparseness is what keeps the
    /// field quiet — see `goldDustLaysLessInkThanTheGrain`, which pins
    /// the two densities against each other so neither can be retuned
    /// into a texture.
    nonisolated static let goldDustPeakOpacity: Double = 0.13

    /// One fleck per this many point² of sky. Two orders of magnitude
    /// sparser than the grain's one-per-210.
    nonisolated static let goldDustMarkArea: Double = 2_680

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

/// Static film-grain texture over the plate's field — a fixed seeded
/// speckle at ≤5% strength (day vellum ~4.5%, night film ~3%). Drawn
/// once (no timeline dependency), so it costs nothing per frame;
/// under Reduce Motion it is already static, and under Reduce
/// Transparency the sky view omits it entirely.
///
/// This is the graceful-degradation implementation of the plate
/// grain. The Metal shader variant (`Celestial/Shaders/
/// CelestialShaders.metal`, currently excluded from the build) adds
/// live filmic movement on hardware once the Metal toolchain is
/// available; this Canvas layer is its exact static fallback.
public struct PlateGrainOverlay: View {

    /// One grain mark per this many point². The gold-dust scatter is
    /// calibrated against it.
    public static let markArea: Double = 210
    /// Grain strength on the near-white day fields — the threshold of
    /// visibility at arm's length. The night states keep 0.03.
    public static let dayIntensity: Double = 0.045

    public let tint: Color
    public let seed: UInt64
    public var intensity: Double

    public init(
        tint: Color,
        seed: UInt64,
        intensity: Double = 0.03
    ) {
        self.tint = tint
        self.seed = seed
        self.intensity = intensity
    }

    public var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(state: seed ^ 0xF11A_9AA1_77E1_D05B)
            let strength = min(0.05, intensity)
            let count = Int((size.width * size.height / Self.markArea).rounded())
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
