import IhsanCore
import IhsanDesignSystem
import SwiftUI

// The instrument's explicit fallback surfaces — each availability
// state gets a designed page, never a blank or broken dial.

// MARK: - No compass hardware

/// iPad / simulator: the dial can't turn, so the instrument becomes a
/// fixed reference card — the same ring at rest, north up, the lancet
/// engraved at the bearing, and one line saying where to face.
struct QiblaStaticBearingView: View {
    let tokens: SkyPaletteTokens
    let qiblaBearing: Double
    let distanceKm: Double
    let ringSide: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                QiblaDialRing(tokens: tokens)
                QiblaLancetMark(tokens: tokens, ringRadius: ringSide / 2)
                    .rotationEffect(.degrees(qiblaBearing))
                QiblaHubMark(tokens: tokens, ringRadius: ringSide / 2)
            }
            .frame(width: ringSide, height: ringSide)

            VStack(spacing: 7) {
                Text(QiblaInscriptions.staticBearing(qiblaBearing: qiblaBearing))
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .monospacedDigit()
                    .foregroundStyle(tokens.inkSecondary)
                Text(QiblaInscriptions.distance(km: distanceKm))
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .monospacedDigit()
                    .foregroundStyle(tokens.inkSecondary)
            }
            .padding(.top, IhsanSpacing.lg)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "This device has no compass. "
                + QiblaInscriptions.staticBearing(qiblaBearing: qiblaBearing).capitalized
                + ". " + QiblaInscriptions.spokenDistance(km: distanceKm) + "."
        )
    }
}

// MARK: - Location denied

/// Without a location there is no bearing at all. Explain in one
/// breath, with the one-line path to Settings.
struct QiblaLocationDeniedView: View {
    let tokens: SkyPaletteTokens

    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            EightPointedStar()
                .stroke(tokens.metal.opacity(0.55), lineWidth: 1)
                .frame(width: 44, height: 44)

            Text("The qibla needs your location")
                .font(IhsanFont.subtitle)
                .foregroundStyle(tokens.ink)
                .multilineTextAlignment(.center)

            Text("The bearing to Makkah is computed from where you stand. Your location never leaves this device.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .multilineTextAlignment(.center)

            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: url) {
                    Text("ALLOW IN SETTINGS")
                        .font(IhsanFont.inscription)
                        .tracking(1.8)
                        .foregroundStyle(tokens.leafGold)
                }
            }
        }
        .padding(.horizontal, IhsanSpacing.xl)
    }
}
