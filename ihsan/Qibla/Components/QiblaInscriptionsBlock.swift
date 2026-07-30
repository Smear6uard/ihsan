import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The two engraved lines beneath the ring — distance, then the live
/// relative direction — and nothing else. Above the ring: nothing.
struct QiblaInscriptionsBlock: View {
    let tokens: SkyPaletteTokens
    let distanceKm: Double
    /// Signed shortest rotation to the qibla; `nil` before the first
    /// heading sample (the direction line waits, the distance shows).
    let signedDelta: Double?
    let isAligned: Bool
    var typeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 7) {
            Text(QiblaInscriptions.distance(km: distanceKm))
                .font(QiblaType.inscription(typeScale))
                .tracking(1.8)
                .monospacedDigit()
                .foregroundStyle(tokens.inkSecondary)

            directionLine
        }
        // "FACING QIBLA" arrives and departs as a calm crossfade —
        // the reversal is as graceful as the arrival.
        .animation(.easeInOut(duration: 0.35), value: isAligned)
        .accessibilityHidden(true) // Spoken through the instrument element.
    }

    @ViewBuilder
    private var directionLine: some View {
        if isAligned {
            // Gold text sings on the night grounds but dies on the
            // day vellum — there the engraved ink carries the words
            // and the fused golden column carries the celebration.
            Text("FACING QIBLA")
                .font(QiblaType.inscription(typeScale))
                .tracking(2.4)
                .foregroundStyle(
                    tokens.groundBottomValue.relativeLuminance > 0.5
                        ? tokens.ink
                        : tokens.leafGold
                )
        } else if let signedDelta {
            Text(QiblaInscriptions.relativeDirection(signedDelta: signedDelta))
                .font(QiblaType.inscription(typeScale))
                .tracking(1.8)
                .monospacedDigit()
                .foregroundStyle(tokens.inkSecondary)
        } else {
            // Reserve the line so the block doesn't jump when the
            // first sample lands.
            Text(" ")
                .font(QiblaType.inscription(typeScale))
        }
    }
}
