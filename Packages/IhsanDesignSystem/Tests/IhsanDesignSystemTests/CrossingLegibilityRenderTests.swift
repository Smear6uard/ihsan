import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// Sunrise and sunset keep a continuous atmosphere but use a coherent
/// high-contrast figure pole plus a panel-coloured caption backing.
/// No glyph copies or outline are part of the result.
struct CrossingLegibilityRenderTests {
    private func composited(
        _ foreground: SRGBValue,
        over background: SRGBValue,
        opacity: Double
    ) -> SRGBValue {
        SRGBValue(
            red: foreground.red * opacity + background.red * (1 - opacity),
            green: foreground.green * opacity + background.green * (1 - opacity),
            blue: foreground.blue * opacity + background.blue * (1 - opacity)
        )
    }

    @Test
    func captionBackingAppearsOnlyWhereAdaptiveInkNeedsIt() {
        for step in 0..<4_000 {
            let tokens = PaletteState.resolved(
                for: SkyPhase(unit: Double(step) / 4_000.0)
            )
            let surfaces = [
                tokens.skyZenithValue,
                tokens.groundTopValue,
                tokens.groundBottomValue,
                tokens.groundPlaneValue,
                tokens.panelFillValue,
            ]
            let worst = [tokens.inkValue, tokens.inkSecondaryValue]
                .flatMap { ink in surfaces.map { ink.contrastRatio(against: $0) } }
                .min() ?? 0
            if worst < 4.5 {
                #expect(tokens.inkHaloStrength > 0.05)
                #expect(
                    tokens.inkValue.contrastRatio(against: tokens.panelFillValue) >= 4.5
                )
                #expect(
                    tokens.inkSecondaryValue.contrastRatio(
                        against: tokens.panelFillValue
                    ) >= 4.5
                )
            }
            #expect(tokens.inkOutlineStrength == 0)
        }
    }

    /// The backing is the crossing's own light: on a plateau it is
    /// exactly the panel, and through a crossing it leans toward the
    /// glow — warmer, never a neutral card.
    @Test
    func captionBackingWarmsTowardTheCrossingGlow() {
        let plateau = PaletteState.resolved(for: SkyPhase(unit: 0.400))
        #expect(plateau.inkHaloStrength == 0)
        #expect(InkKeyline.backingValue(for: plateau) == plateau.panelFillValue)

        let crossing = PaletteState.resolved(for: SkyPhase(unit: 0.160))
        #expect(crossing.inkHaloStrength > 0.9)
        let backing = InkKeyline.backingValue(for: crossing)
        #expect(backing != crossing.panelFillValue)
        #expect(
            backing.red - backing.blue
                > crossing.panelFillValue.red - crossing.panelFillValue.blue
        )
    }

    @MainActor
    @Test
    func compatibilityModifierDoesNotChangeLayout() {
        let tokens = PaletteState.sunset.tokens
        let plain = ImageRenderer(content: Text("MAGHRIB").font(.body))
        let adapted = ImageRenderer(
            content: Text("MAGHRIB").font(.body).inkKeyline(tokens)
        )
        #expect(plain.cgImage?.width == adapted.cgImage?.width)
        #expect(plain.cgImage?.height == adapted.cgImage?.height)
    }

    @MainActor
    @Test
    func translucentBackingStillCarriesReadableInk() {
        for step in 0..<4_000 {
            let tokens = PaletteState.resolved(
                for: SkyPhase(unit: Double(step) / 4_000.0)
            )
            let opacity = InkKeyline.backingOpacity(for: tokens)
            guard opacity > 0 else { continue }

            for height in stride(from: 0.0, through: 1.0, by: 0.02) {
                let sky = CelestialSkyView.skyValue(
                    atFraction: height,
                    tokens: tokens
                )
                let backing = composited(
                    InkKeyline.backingValue(for: tokens),
                    over: sky,
                    opacity: opacity
                )
                for ink in [tokens.inkValue, tokens.inkSecondaryValue] {
                    #expect(
                        ink.contrastRatio(against: backing) >= 4.5,
                        "caption backing falls below AA at phase \(step), height \(height)"
                    )
                }
            }
        }
    }
}
