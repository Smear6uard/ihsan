import SwiftUI

/// The sun or moon rendered as a genuine light source: a layered
/// radial-gradient core inside a soft additive halo, tuned per ground
/// polarity so the body reads as luminous against both jewel and
/// near-white grounds.
///
/// On dark grounds the halo composites additively (`plusLighter`), so
/// it lifts the sky around the body the way glare lifts a dark lens.
/// On the luminous day grounds additive blending would just clip to
/// white, so the halo switches to normal compositing and the body
/// instead carries concentrated warm saturation against the cool
/// near-white — the payoff of the v2 palette inversion.
///
/// The moon takes the already-computed phase (`illuminatedFraction`,
/// `isWaxing`) as input — this view never recomputes astronomy.
///
/// Everything here is static: no drift, no pulse, so Reduce Motion
/// needs no branch. Under Reduce Transparency the gradient halo
/// collapses to a single flat disc and the core loses its bloom ring.
///
/// The Metal shader variant of the halo (exponential falloff, in
/// `Celestial/Shaders/CelestialShaders.metal`, currently excluded
/// from the build) slots in behind the same API once the Metal
/// toolchain is available; these gradients are its exact fallback.
public struct LuminousBody: View {

    public enum Kind: Sendable, Equatable {
        case sun
        case moon(illuminatedFraction: Double, isWaxing: Bool)
    }

    public let kind: Kind
    /// Diameter of the body's disc in points. The halo extends to
    /// ~2.6× this and is purely decorative.
    public let diameter: CGFloat
    public let tokens: SkyPaletteTokens

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency

    private var reduceTransparency: Bool { systemReduceTransparency || forceReducedTransparency }

    public init(kind: Kind, diameter: CGFloat, tokens: SkyPaletteTokens) {
        self.kind = kind
        self.diameter = diameter
        self.tokens = tokens
    }

    private var onDarkGround: Bool {
        tokens.groundBottomValue.relativeLuminance < 0.5
    }

    public var body: some View {
        ZStack {
            halo
            core
                .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch kind {
        case .sun:
            return "Sun"
        case .moon(let fraction, _):
            return "Moon, \(Int((fraction * 100).rounded())) percent illuminated"
        }
    }

    // MARK: - Halo

    /// The sun's near-white core color — #FFF9EC, warming toward pure
    /// white at the very center.
    private static let sunCoreColor = Color(
        red: 1.0, green: 0.976, blue: 0.925
    )

    @ViewBuilder
    private var halo: some View {
        switch kind {
        case .sun:
            sunCorona
        case .moon:
            moonGlow
        }
    }

    /// The sun's corona: warm saturated gold dissolving outward, its
    /// inner region opaque enough to overlap the core's own falloff —
    /// so there is no radius at which a disc edge exists.
    @ViewBuilder
    private var sunCorona: some View {
        let coronaDiameter = diameter * 2.6
        if reduceTransparency {
            Circle()
                .fill(tokens.glow.opacity(0.14))
                .frame(width: diameter * 2.0, height: diameter * 2.0)
                .allowsHitTesting(false)
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: tokens.glow.opacity(0.85), location: 0.0),
                            .init(color: tokens.glow.opacity(0.45), location: 0.28),
                            .init(color: tokens.glow.opacity(0.14), location: 0.62),
                            .init(color: tokens.glow.opacity(0.0), location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: coronaDiameter / 2
                    )
                )
                .frame(width: coronaDiameter, height: coronaDiameter)
                .blendMode(onDarkGround ? .plusLighter : .normal)
                .allowsHitTesting(false)
        }
    }

    /// The moon's glow is cool where the sun's is warm — the ink pole
    /// of the palette, additive against jewel grounds. On the luminous
    /// day grounds the ink is a deep indigo and a dark halo would read
    /// as a smudge, so the moon stands as a lit object with no glow.
    @ViewBuilder
    private var moonGlow: some View {
        if onDarkGround {
            let glowDiameter = diameter * 2.2
            if reduceTransparency {
                Circle()
                    .fill(tokens.ink.opacity(0.10))
                    .frame(width: diameter * 1.8, height: diameter * 1.8)
                    .allowsHitTesting(false)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tokens.ink.opacity(0.30),
                                tokens.ink.opacity(0.10),
                                tokens.ink.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: diameter * 0.34,
                            endRadius: glowDiameter / 2
                        )
                    )
                    .frame(width: glowDiameter, height: glowDiameter)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Core

    @ViewBuilder
    private var core: some View {
        switch kind {
        case .sun:
            sunCore
        case .moon(let fraction, let waxing):
            moonCore(illuminatedFraction: fraction, isWaxing: waxing)
        }
    }

    /// The sun as light, not object: a small near-white core (#FFF9EC
    /// toward white at center, ~45% of the body diameter) whose own
    /// radial falloff dissolves before the corona's inner region ends.
    /// No stroke, no offset shading, no radius where an edge lives —
    /// zoomed in, there is no pixel at which the sun "stops".
    @ViewBuilder
    private var sunCore: some View {
        if reduceTransparency {
            // Flat-fill contract: a plain small disc; the corona above
            // is likewise flat.
            Circle()
                .fill(Self.sunCoreColor)
                .frame(width: diameter * 0.45, height: diameter * 0.45)
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: Self.sunCoreColor, location: 0.30),
                            .init(color: Self.sunCoreColor.opacity(0.55), location: 0.62),
                            .init(color: Self.sunCoreColor.opacity(0.0), location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 0.45
                    )
                )
                .frame(width: diameter * 0.9, height: diameter * 0.9)
                .blendMode(onDarkGround ? .plusLighter : .normal)
        }
    }

    /// The lit limb at its true phase over a faint earthshine disc.
    /// The moon keeps its defined edge — it is a lit object, not a
    /// light source.
    private func moonCore(illuminatedFraction: Double, isWaxing: Bool) -> some View {
        let litColor = SRGBValue.mix(tokens.inkValue, tokens.metalHighlightValue, amount: 0.35).color
        let earthshine = tokens.groundTopValue.scalingLightness(by: 1.35).color
        return ZStack {
            Circle()
                .fill(earthshine.opacity(0.55))
            CrescentShape(
                illuminatedFraction: illuminatedFraction,
                isWaxing: isWaxing
            )
            .fill(litColor)
        }
    }
}
