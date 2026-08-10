import Foundation
import Testing
import IhsanCore
@testable import IhsanDesignSystem

@Suite("Sky weather treatment mapping")
struct SkyWeatherTreatmentTests {
    private func conditions(_ kind: SkyConditions.Kind) -> SkyConditions {
        SkyConditions(
            kind: kind,
            isPrecipitating: false,
            windBand: .calm,
            cloudBand: .clear,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// The whole mapping table, pinned case by case. The vocabulary is
    /// deliberately small: six treatments, and every condition the
    /// provider can report lands in exactly one of them.
    @Test("Every condition kind maps to its treatment")
    func mappingTable() {
        let expected: [SkyConditions.Kind: SkyWeatherTreatment] = [
            // The idealized page.
            .clear: .clear,
            .breezy: .clear,
            .windy: .clear,
            .blowingDust: .clear,
            .frigid: .clear,
            .hot: .clear,
            .unknown: .clear,
            // One or two soft washes.
            .mostlyClear: .partlyVeiled,
            .partlyCloudy: .partlyVeiled,
            // The page on a gray day.
            .mostlyCloudy: .overcast,
            .cloudy: .overcast,
            .foggy: .overcast,
            .haze: .overcast,
            .smoky: .overcast,
            // The illuminator's rain.
            .drizzle: .rain,
            .rain: .rain,
            .heavyRain: .rain,
            .sunShowers: .rain,
            .freezingDrizzle: .rain,
            .freezingRain: .rain,
            .sleet: .rain,
            .wintryMix: .rain,
            .hail: .rain,
            // Cool white dust.
            .flurries: .snow,
            .snow: .snow,
            .heavySnow: .snow,
            .blowingSnow: .snow,
            .sunFlurries: .snow,
            .blizzard: .snow,
            // Overcast + rain, one step deeper. Nothing flashes.
            .isolatedThunderstorms: .storm,
            .scatteredThunderstorms: .storm,
            .thunderstorms: .storm,
            .strongStorms: .storm,
            .hurricane: .storm,
            .tropicalStorm: .storm,
        ]

        for kind in SkyConditions.Kind.allCases {
            let mapped = SkyWeatherTreatment.resolved(for: conditions(kind))
            #expect(
                mapped == expected[kind],
                "\(kind) mapped to \(mapped), expected \(String(describing: expected[kind]))"
            )
        }
    }

    @Test("The mapping table covers every condition kind exactly once")
    func tableIsTotal() {
        // Guards the test above against a silently missing entry: if a
        // new kind is added to the model, this fails until the table
        // names it.
        let named: Set<SkyConditions.Kind> = [
            .clear, .breezy, .windy, .blowingDust, .frigid, .hot, .unknown,
            .mostlyClear, .partlyCloudy,
            .mostlyCloudy, .cloudy, .foggy, .haze, .smoky,
            .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle,
            .freezingRain, .sleet, .wintryMix, .hail,
            .flurries, .snow, .heavySnow, .blowingSnow, .sunFlurries, .blizzard,
            .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
            .strongStorms, .hurricane, .tropicalStorm,
        ]
        #expect(named == Set(SkyConditions.Kind.allCases))
    }

    // MARK: - Gate fallback chain

    @Test("A treatment outside the approved set falls back along its chain")
    func fallbackChain() {
        // Nothing approved: everything is the idealized page.
        #expect(SkyWeatherTreatment.storm.resolvedAgainst(approved: []) == .clear)
        #expect(SkyWeatherTreatment.snow.resolvedAgainst(approved: []) == .clear)
        #expect(SkyWeatherTreatment.partlyVeiled.resolvedAgainst(approved: []) == .clear)

        // Storm walks storm → rain → overcast → partlyVeiled → clear.
        #expect(SkyWeatherTreatment.storm.resolvedAgainst(approved: [.rain]) == .rain)
        #expect(SkyWeatherTreatment.storm.resolvedAgainst(approved: [.overcast]) == .overcast)
        #expect(SkyWeatherTreatment.storm.resolvedAgainst(approved: [.partlyVeiled]) == .partlyVeiled)

        // Rain never falls back to snow, and snow only to clear.
        #expect(SkyWeatherTreatment.rain.resolvedAgainst(approved: [.snow]) == .clear)
        #expect(SkyWeatherTreatment.snow.resolvedAgainst(approved: [.rain, .overcast]) == .clear)

        // An approved treatment resolves to itself.
        for treatment in SkyWeatherTreatment.allCases {
            #expect(treatment.resolvedAgainst(approved: Set(SkyWeatherTreatment.allCases)) == treatment)
        }

        // Clear is always available, approved or not.
        #expect(SkyWeatherTreatment.clear.resolvedAgainst(approved: []) == .clear)
    }
}
