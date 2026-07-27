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

    private var haloStrength: Double {
        switch kind {
        case .sun: return 1.0
        case .moon: return 0.55
        }
    }

    @ViewBuilder
    private var halo: some View {
        let haloDiameter = diameter * 2.6
        if reduceTransparency {
            Circle()
                .fill(tokens.glow.opacity(0.14 * haloStrength))
                .frame(width: diameter * 2.0, height: diameter * 2.0)
                .allowsHitTesting(false)
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tokens.glow.opacity(0.50 * haloStrength),
                            tokens.glow.opacity(0.16 * haloStrength),
                            tokens.glow.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: diameter * 0.30,
                        endRadius: haloDiameter / 2
                    )
                )
                .frame(width: haloDiameter, height: haloDiameter)
                .blendMode(onDarkGround ? .plusLighter : .normal)
                .allowsHitTesting(false)
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

    /// White-hot center (capped short of pure white), glow body,
    /// metal rim — three layered radial stops that read as an
    /// incandescent disc.
    private var sunCore: some View {
        let center = tokens.glowValue.scalingLightness(by: 1.22).color
        return Circle()
            .fill(
                RadialGradient(
                    colors: [center, tokens.glow, tokens.metal],
                    center: UnitPoint(x: 0.42, y: 0.38),
                    startRadius: 0,
                    endRadius: diameter * 0.62
                )
            )
            .overlay {
                if !reduceTransparency {
                    Circle()
                        .stroke(tokens.metalHighlight.opacity(0.55), lineWidth: 0.8)
                        .blur(radius: 0.4)
                }
            }
    }

    /// The lit limb at its true phase over a faint earthshine disc.
    private func moonCore(illuminatedFraction: Double, isWaxing: Bool) -> some View {
        let litColor = SRGBValue.mix(tokens.inkValue, tokens.metalHighlightValue, amount: 0.35).color
        let shadowColor = tokens.groundTopValue.scalingLightness(by: 1.35).color
        return ZStack {
            Circle()
                .fill(shadowColor.opacity(0.55))
            CrescentShape(
                illuminatedFraction: illuminatedFraction,
                isWaxing: isWaxing
            )
            .fill(litColor)
        }
    }
}
