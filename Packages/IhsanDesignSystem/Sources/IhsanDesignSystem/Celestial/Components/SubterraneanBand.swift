import SwiftUI

/// The region beneath the horizon line — a tonal darkening of the
/// sky for the area where below-horizon prayer markers appear.
///
/// The band renders as a vertical gradient from clear at the top (just
/// below the brass rule) to the mode's `subterranean` colour at the
/// bottom. The colour is chromatically aligned with the sky — a deeper,
/// quieter sibling of `skyDeep` rather than a contrasting surface — so
/// the below-horizon region reads as *beneath* the visible sky rather
/// than as a competing panel.
///
/// At night the band is a deeper indigo (`#0A0E20`) layered on top of
/// the night sky's already-deep blues; the effect is subtle in cool
/// light and unmistakable as "this is below the horizon" once the eye
/// has adjusted. During the day the band is rarely seen (the horizon
/// sits near the bottom of the scene) and the muted warm dark
/// (`#B8956A`) blends with the parchment sky without becoming a
/// visible artefact.
///
/// The band's vertical extent is sized by the caller — the scene
/// passes the distance from the horizon line down to the bottom of
/// the marker zone — so the band always fills exactly the available
/// subterranean region.
public struct SubterraneanBand: View {

    /// Palette whose `subterranean` colour anchors the band.
    public let palette: IhsanCelestialPalette

    /// Peak opacity at the deepest part of the band. Lower values
    /// leave more of the underlying sky visible; higher values darken
    /// more aggressively. Default `0.45` reads as "slightly darker
    /// than the sky" on the night palette without becoming a flat
    /// surface.
    public let intensity: Double

    public init(palette: IhsanCelestialPalette, intensity: Double = 0.45) {
        self.palette = palette
        self.intensity = intensity
    }

    public var body: some View {
        LinearGradient(
            colors: [
                palette.subterranean.opacity(0.0),
                palette.subterranean.opacity(intensity * 0.45),
                palette.subterranean.opacity(intensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Subterranean band — night and day") {
    ZStack {
        VStack(spacing: 0) {
            // Top half: sky.
            LinearGradient(
                colors: [
                    IhsanCelestialPalette.night.skyDeep,
                    IhsanCelestialPalette.night.sky
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Bottom half: sky beneath horizon, with subterranean overlay.
            ZStack {
                IhsanCelestialPalette.night.sky
                SubterraneanBand(palette: .night)
            }
        }
        .ignoresSafeArea()
        VStack {
            Spacer()
            Rectangle()
                .fill(IhsanCelestialPalette.day.accent.opacity(0.5))
                .frame(height: 1)
            Spacer()
        }
    }
}
