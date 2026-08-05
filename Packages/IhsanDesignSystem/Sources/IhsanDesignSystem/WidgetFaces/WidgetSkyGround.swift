import SwiftUI

/// The sky a widget sits on — the plate's exact painted ramp, not an
/// approximation of it.
///
/// The old widget ground linear-interpolated two darkened sRGB stops:
/// banding on precisely the surface class where it shows worst (small,
/// dark, OLED), and a channel-multiply "darken" that hue-shifted the
/// tuned sky. This samples the same 17-point OKLCH stop table the
/// celestial plate paints, then deepens each stop toward ink in OKLab
/// so lightness drops without the hue walking. WidgetKit offers no
/// grain shader; seventeen OKLCH stops across two inches is below the
/// visible banding threshold the app's row-mean audits established.
public struct WidgetSkyGround: View {
    public let tokens: SkyPaletteTokens
    public let mode: WidgetFaceMode
    /// How far each stop sinks toward ink. Home widgets sit against
    /// arbitrary wallpaper and read at arm's length, so the default is
    /// a touch deeper than the app's own page.
    public var deepen: Double

    public init(
        tokens: SkyPaletteTokens,
        mode: WidgetFaceMode = .fullColor,
        deepen: Double = 0.12
    ) {
        self.tokens = tokens
        self.mode = mode
        self.deepen = deepen
    }

    public var body: some View {
        switch mode {
        case .fullColor:
            LinearGradient(
                stops: Self.stops(tokens: tokens, deepen: deepen),
                startPoint: .top,
                endPoint: .bottom
            )
        case .accented:
            // Tinted and clear modes own the ground; anything painted
            // here would fight the user's choice.
            Color.clear
        }
    }

    /// The deepened stop table — internal so render audits can walk
    /// the exact field the widget paints.
    static func stops(tokens: SkyPaletteTokens, deepen: Double) -> [Gradient.Stop] {
        let sink = SRGBValue(red: 0.02, green: 0.02, blue: 0.045)
        return CelestialSkyView.skySamples(tokens: tokens).map { sample in
            Gradient.Stop(
                color: SRGBValue.mix(sample.value, sink, amount: deepen).color,
                location: sample.location
            )
        }
    }
}
