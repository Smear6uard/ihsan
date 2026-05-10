import SwiftUI
import IhsanDesignSystem

/// A culturally-respectful, geometric representation of the Kaaba: a black
/// cubic body crossed by a thin gold band evoking the hizam — the
/// embroidered band of the Kiswah. Drawn natively in SwiftUI (no asset),
/// abstract enough to read as a symbol rather than an image.
///
/// Color literals here are intentional and scoped to the Kaaba: the Kaaba's
/// near-black and the hizam's brass are not part of the time-of-day palette
/// and would be incorrect to derive from `IhsanColor`.
struct KaabaIndicator: View {
    /// 0 = at rest, 1 = aligned. Drives the brass radial halo and a small
    /// scale lift to telegraph the alignment moment without being noisy.
    let alignmentGlow: Double
    var size: CGFloat = 28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let brass = Color(
        red: 0xC9 / 255.0,
        green: 0xA8 / 255.0,
        blue: 0x76 / 255.0
    )
    private static let kaabaBlack = Color(
        red: 0x0A / 255.0,
        green: 0x0A / 255.0,
        blue: 0x0A / 255.0
    )

    var body: some View {
        ZStack {
            // Halo telegraphs the alignment moment. Under Reduce Motion
            // we still fade the halo in/out via opacity (driven by the
            // alignmentGlow value the parent passes), but the parent's
            // own animation modifier — which is gated on Reduce Motion
            // up in QiblaCompassDial — is what controls whether the
            // transition itself moves. The scale lift below is the part
            // that's pure motion, so it's clamped to 1.0 when Reduce
            // Motion is on.
            if alignmentGlow > 0 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Self.brass.opacity(0.55 * alignmentGlow),
                                Self.brass.opacity(0.18 * alignmentGlow),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 1.6
                        )
                    )
                    .frame(width: size * 3.2, height: size * 3.2)
                    .blendMode(.screen)
            }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Self.kaabaBlack)
                    .frame(height: size * 0.30)

                Rectangle()
                    .fill(Self.brass)
                    .frame(height: size * 0.08)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.clear,
                                        Color.black.opacity(0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )

                Rectangle()
                    .fill(Self.kaabaBlack)
                    .frame(height: size * 0.62)
            }
            .frame(width: size, height: size)
            .overlay {
                Rectangle()
                    .strokeBorder(Self.brass.opacity(0.55), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
            .scaleEffect(reduceMotion ? 1.0 : 1 + 0.06 * alignmentGlow)
        }
        .accessibilityLabel("Kaaba")
    }
}

#Preview {
    VStack(spacing: IhsanSpacing.lg) {
        KaabaIndicator(alignmentGlow: 0)
        KaabaIndicator(alignmentGlow: 1)
        KaabaIndicator(alignmentGlow: 0, size: 56)
    }
    .padding(IhsanSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
