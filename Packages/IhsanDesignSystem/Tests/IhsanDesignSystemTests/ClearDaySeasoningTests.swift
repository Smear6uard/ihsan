import Foundation
import Testing
@testable import IhsanDesignSystem

/// The clear day, seasoned: the device-review verdict said "right
/// direction, too timid," and these pins hold the three named repairs
/// in place — a middle band that never goes flavorless, a drawn sun
/// confident enough to be the plate's second ornament sun, and the
/// gated corner pieces held at margin-ornament presence.
@Suite("Clear day seasoning")
struct ClearDaySeasoningTests {

    /// Item 1. Between the zenith lapis and the warm horizon the ramp
    /// used to collapse into a dead cream zone — by the breakpoint the
    /// sky had no measurable chroma left, and the whole lower band was
    /// near-white on near-white. The re-graded ramp holds residual
    /// color through the entire span: lapis surrendering to warmth
    /// gradually, one continuous breath.
    ///
    /// The floor was 0.0055 while the ground anchors were near-whites
    /// and the ramp's colour was on loan from the zenith — it caught a
    /// ramp that went flavorless, which was all it could do. Now that
    /// the day grounds carry their own cool chroma the whole field is
    /// tinted air, the flattest point measures 0.023, and the floor
    /// rises to 0.018 so that a future edit cannot quietly hand the
    /// day back its colourless bottom half. It is a floor on the
    /// modernization, not a target: passing it is not evidence of a
    /// well-graded sky, only of a sky that still has colour in it.
    @Test("The day ramp never goes flavorless on its way down")
    func middleBandKeepsChroma() {
        for state in [PaletteState.morning, PaletteState.afternoon] {
            let tokens = PaletteState.resolved(for: .fixed(state))
            var minimum = Double.infinity
            var flattest = 0.0
            for step in 2...18 {
                let fraction = Double(step) / 20.0
                let lab = CelestialSkyView.skyValue(
                    atFraction: fraction, tokens: tokens
                ).oklab
                let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
                if chroma < minimum {
                    minimum = chroma
                    flattest = fraction
                }
            }
            #expect(
                minimum >= 0.018,
                "\(state) sky drops to chroma \(minimum) at \(flattest) of the span"
            )
        }
    }

    /// Item 2. The engraved ray halo read sparse at arm's length:
    /// twelve rays is the Shamsa's count at medallion scale, not the
    /// plate's second sun. Densified to sixteen long and sixteen short,
    /// still alternating, still starting straight up.
    @Test("The ray collar carries sixteen long and sixteen short rays")
    func rayCollarIsDense() {
        let polylines = EngravedSunRays.rayPolylines(
            around: .zero, bodyDiameter: 100
        )
        #expect(polylines.count == 32)

        func reach(_ line: [CGPoint]) -> CGFloat {
            guard let last = line.last else { return 0 }
            return (last.x * last.x + last.y * last.y).squareRoot()
        }
        let reaches = polylines.map(reach)
        let longs = stride(from: 0, to: reaches.count, by: 2).map { reaches[$0] }
        let shorts = stride(from: 1, to: reaches.count, by: 2).map { reaches[$0] }

        #expect(Set(longs.map { ($0 * 10).rounded() }).count == 1)
        #expect(Set(shorts.map { ($0 * 10).rounded() }).count == 1)
        #expect(longs[0] > shorts[0], "rays alternate long and short")

        // Still a collar, never a starburst: everything stays inside
        // one body diameter.
        #expect(reaches.allSatisfy { $0 < 100 })
    }

    /// Item 5, gated. The corner pieces are margin-ornament linework at
    /// very low presence: metal in the 15–20% band, filament weights,
    /// compact. The maintainer keeps or cuts them in one word — the
    /// kill switch is `PlateCornerFiligree.isEnabled`.
    @Test("The corner pieces hold margin-ornament presence")
    func cornerPiecesStayQuiet() {
        #expect(PlateCornerFiligree.metalOpacity >= 0.15)
        #expect(PlateCornerFiligree.metalOpacity <= 0.20)
        #expect(PlateCornerFiligree.extent <= 56)
        #expect(PlateCornerFiligree.maximumLineWidth <= 1.2)
    }
}
