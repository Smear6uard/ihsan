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

    var body: some View {
        VStack(spacing: 7) {
            Text(QiblaInscriptions.distance(km: distanceKm))
                .font(IhsanFont.inscription)
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
            Text("FACING QIBLA")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.leafGold)
        } else if let signedDelta {
            Text(QiblaInscriptions.relativeDirection(signedDelta: signedDelta))
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .monospacedDigit()
                .foregroundStyle(tokens.inkSecondary)
        } else {
            // Reserve the line so the block doesn't jump when the
            // first sample lands.
            Text(" ")
                .font(IhsanFont.inscription)
        }
    }
}
