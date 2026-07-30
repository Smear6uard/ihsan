import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The light of the approach — everything that happens *between* the
/// fixed index and the moving lancet. Drawn in screen coordinates
/// (this layer never rotates): the ring's faint warmth toward the
/// lancet's side, the luminance bridge that grows as index and
/// lancet close, and the fused luminous form when they become one.
///
/// Depth here is glow and layered opacity only — flat + luminous, no
/// shadows, no specular.
struct QiblaApproachOverlay: View {
    let tokens: SkyPaletteTokens
    /// The lancet's screen angle from twelve o'clock — exactly the
    /// signed delta to the qibla.
    let signedDelta: Double
    let approach: QiblaApproach
    let isAligned: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            drawRingWarmth(context: context, center: center, radius: radius)
            drawBridge(context: context, center: center, radius: radius)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The plate's warm metal-toned glow — the same mix the ornament
    /// halos use, never a neutral white.
    private var warmGlow: Color {
        SRGBValue.mix(tokens.glowValue, tokens.metalValue, amount: 0.45).color
    }

    // MARK: - Ring warmth (approach band)

    /// Almost imperceptible by design: a soft arc of warmth in the
    /// tick band on the lancet's side, at most 9% opacity.
    private func drawRingWarmth(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard approach.ringWarmth > 0.001 else { return }
        let lancetAngle = Angle.degrees(signedDelta - 90)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius * 0.93,
            startAngle: lancetAngle - .degrees(38),
            endAngle: lancetAngle + .degrees(38),
            clockwise: false
        )
        var layer = context
        if !reduceTransparency { layer.addFilter(.blur(radius: 7)) }
        layer.stroke(
            path,
            with: .color(warmGlow.opacity((reduceTransparency ? 0.06 : 0.09) * approach.ringWarmth)),
            style: StrokeStyle(lineWidth: radius * 0.13, lineCap: .round)
        )
    }

    // MARK: - The luminance bridge (near band)

    /// A soft arc of light along the inner band, spanning from the
    /// index tip to the lancet — intensifying as the gap closes.
    private func drawBridge(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard approach.bridgeStrength > 0.001, !isAligned, abs(signedDelta) > 0.5 else { return }
        let top = Angle.degrees(-90)
        let lancetAngle = Angle.degrees(signedDelta - 90)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius * 0.845,
            startAngle: signedDelta >= 0 ? top : lancetAngle,
            endAngle: signedDelta >= 0 ? lancetAngle : top,
            clockwise: false
        )
        var layer = context
        if !reduceTransparency { layer.addFilter(.blur(radius: 3.5)) }
        layer.stroke(
            path,
            with: .color(warmGlow.opacity((reduceTransparency ? 0.40 : 0.55) * approach.bridgeStrength)),
            style: StrokeStyle(lineWidth: reduceTransparency ? 2.5 : 4.5, lineCap: .round)
        )
    }

}

// MARK: - Fusion (aligned)

/// Index and lancet as one luminous form: a single column of glow
/// from the hub to the rim at twelve o'clock. A plain view (not
/// Canvas) so its opacity animates — alignment fades it in calmly
/// and breaking alignment reverses it gracefully, never a snap.
struct QiblaFusionGlow: View {
    let tokens: SkyPaletteTokens
    let ringRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let length = ringRadius * (0.96 - 0.14)
        Capsule()
            .fill(warmGlow.opacity(reduceTransparency ? 0.35 : 0.60))
            .frame(width: reduceTransparency ? 5 : 11, height: length)
            .blur(radius: reduceTransparency ? 0 : 7)
            .offset(y: -(ringRadius * 0.14 + length / 2))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var warmGlow: Color {
        SRGBValue.mix(tokens.glowValue, tokens.metalValue, amount: 0.45).color
    }
}

// MARK: - The bloom

/// One calm breath across the ring at the moment of arrival, then
/// stillness. Keyed to the view model's bloom counter, so it plays
/// exactly once per alignment entry; under Reduce Motion it never
/// renders (the fused form and inscription carry the state).
struct QiblaBloomView: View {
    let tokens: SkyPaletteTokens
    let trigger: Int

    private struct BloomPhase: Equatable {
        var opacity: Double = 0
        var scale: Double = 0.94
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        warmGlow.opacity(0.32),
                        warmGlow.opacity(0.12),
                        warmGlow.opacity(0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 320
                )
            )
            .keyframeAnimator(
                initialValue: BloomPhase(),
                trigger: trigger
            ) { view, phase in
                view
                    .opacity(trigger == 0 ? 0 : phase.opacity)
                    .scaleEffect(phase.scale)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(0.85, duration: 0.55)
                    CubicKeyframe(0.0, duration: 1.05)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.0, duration: 0.55)
                    CubicKeyframe(1.05, duration: 1.05)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var warmGlow: Color {
        SRGBValue.mix(tokens.glowValue, tokens.metalValue, amount: 0.45).color
    }
}
