import Foundation
import Testing
@testable import IhsanDesignSystem

/// The living sky's painted treatments, held to the manuscript's
/// terms: value shifts and engraved marks only, no new hues, the
/// instrument legible above every one of them, and the idealized sky
/// untouched whenever weather is `.clear`.
@Suite("Living sky treatments")
struct LivingSkyTreatmentTests {

    private func tokens(_ state: PaletteState) -> SkyPaletteTokens {
        PaletteState.resolved(for: .fixed(state))
    }

    private func lightnesses(
        _ state: PaletteState, weather: SkyWeatherTreatment
    ) -> [Double] {
        CelestialSkyView.skySamples(tokens: tokens(state), weather: weather)
            .map(\.value.oklab.l)
    }

    @Test("Clear weather is byte-identical to the idealized ramp")
    func clearIsIdentity() {
        for state in PaletteState.allCases {
            let idealized = CelestialSkyView.skySamples(tokens: tokens(state))
            let cleared = CelestialSkyView.skySamples(
                tokens: tokens(state), weather: .clear
            )
            #expect(idealized.map(\.value) == cleared.map(\.value), "\(state)")
        }
    }

    @Test("Overcast compresses the ramp's value toward its middle; storm goes one step deeper")
    func compressionOrdering() {
        for state in [PaletteState.morning, .afternoon, .night] {
            func span(_ weather: SkyWeatherTreatment) -> Double {
                let values = lightnesses(state, weather: weather)
                return (values.max() ?? 0) - (values.min() ?? 0)
            }
            let clear = span(.clear)
            let overcast = span(.overcast)
            let storm = span(.storm)
            #expect(overcast < clear * 0.9, "\(state) overcast \(overcast) vs \(clear)")
            #expect(storm < overcast, "\(state) storm \(storm) vs overcast \(overcast)")
        }
    }

    @Test("A gray day is still the same page: no new hues, no added chroma")
    func compressionAddsNoHue() {
        for state in [PaletteState.morning, .afternoon, .night] {
            let clear = CelestialSkyView.skySamples(tokens: tokens(state))
            let overcast = CelestialSkyView.skySamples(
                tokens: tokens(state), weather: .overcast
            )
            for (a, b) in zip(clear, overcast) {
                let ca = (a.value.oklab.a * a.value.oklab.a
                    + a.value.oklab.b * a.value.oklab.b).squareRoot()
                let cb = (b.value.oklab.a * b.value.oklab.a
                    + b.value.oklab.b * b.value.oklab.b).squareRoot()
                #expect(cb <= ca + 0.002, "\(state) sample at \(a.location) gained chroma")
            }
        }
    }

    @Test("The ink stays AA-legible above every treatment in every state")
    func inkHoldsAAOverEveryTreatment() {
        for state in PaletteState.allCases {
            let tokens = tokens(state)
            for weather in SkyWeatherTreatment.allCases {
                let samples = CelestialSkyView.skySamples(
                    tokens: tokens, weather: weather
                )
                for sample in samples {
                    let contrast = tokens.inkValue.contrastRatio(against: sample.value)
                    #expect(
                        contrast >= 4.5,
                        "\(state)/\(weather) ink is \(contrast):1 at \(sample.location)"
                    )
                }
            }
        }
    }

    @Test("The treatment dials stay in the painted register")
    func treatmentDialsArePinned() {
        // Value compression: identity for the treatments that do not
        // gray the page, deepening monotonically for the two that do.
        #expect(SkyWeatherTreatment.clear.valueCompression == 1.0)
        #expect(SkyWeatherTreatment.partlyVeiled.valueCompression == 1.0)
        #expect(SkyWeatherTreatment.rain.valueCompression == 1.0)
        #expect(SkyWeatherTreatment.snow.valueCompression == 1.0)
        #expect(SkyWeatherTreatment.overcast.valueCompression == 0.62)
        #expect(SkyWeatherTreatment.storm.valueCompression == 0.52)

        // The gray pivot sits at or just below the middle, and chroma
        // only ever calms — a treatment can never saturate the page.
        for treatment in SkyWeatherTreatment.allCases {
            #expect(treatment.grayPivotShift <= 0)
            #expect(treatment.grayPivotShift >= -0.04)
            #expect(treatment.chromaCalm <= 1.0)
        }

        // Metal quiets on the gray pages, and only there.
        #expect(SkyWeatherTreatment.clear.metalQuiet == 1.0)
        #expect(SkyWeatherTreatment.overcast.metalQuiet == 0.85)
        #expect(SkyWeatherTreatment.storm.metalQuiet == 0.78)

        // Rain deepens the ground band; storm deepens it further.
        #expect(SkyWeatherTreatment.rain.groundDeepening < 1.0)
        #expect(SkyWeatherTreatment.storm.groundDeepening < SkyWeatherTreatment.rain.groundDeepening)
        #expect(SkyWeatherTreatment.overcast.groundDeepening == 1.0)

        // Hatching and snow render for exactly the treatments that
        // carry them.
        #expect(SkyWeatherTreatment.rain.showsRainHatching)
        #expect(SkyWeatherTreatment.storm.showsRainHatching)
        #expect(!SkyWeatherTreatment.overcast.showsRainHatching)
        #expect(SkyWeatherTreatment.snow.showsSnowDust)
        #expect(!SkyWeatherTreatment.storm.showsSnowDust)
        #expect(SkyWeatherTreatment.partlyVeiled.showsCloudWashes)
        #expect(!SkyWeatherTreatment.overcast.showsCloudWashes)

        // The illuminator's rain stays in the filament register, on
        // both palette polarities. The day peak runs higher for the
        // same reason the worked-ground filaments do: metal buys far
        // less on a near-white field.
        #expect(CelestialSkyView.rainHatchNightPeak <= 0.20)
        #expect(CelestialSkyView.rainHatchDayPeak <= 0.35)
        // Snow keeps the gold-dust field's discipline in cool white:
        // no brighter, no denser than the dust it mirrors.
        #expect(CelestialSkyView.snowDustPeakOpacity <= CelestialSkyView.goldDustPeakOpacity)
        #expect(CelestialSkyView.snowDustMarkArea >= CelestialSkyView.goldDustMarkArea)
    }

    @Test("Compressed ramps still descend without banding-scale steps")
    func compressedRampStaysSmooth() {
        for state in [PaletteState.morning, .afternoon] {
            for weather in [SkyWeatherTreatment.overcast, .storm] {
                let values = lightnesses(state, weather: weather)
                for (a, b) in zip(values, values.dropFirst()) {
                    #expect(
                        abs(a - b) <= 0.035,
                        "\(state)/\(weather) steps \(abs(a - b))"
                    )
                }
            }
        }
    }
}
